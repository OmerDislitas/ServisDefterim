import 'dart:async';
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;

import '../strings.dart';
import 'drive_config.dart';

/// Sadece uygulamanin olusturdugu dosyalara erisim ("hassas olmayan" kapsam).
const driveScopes = [drive.DriveApi.driveFileScope];

/// Kullaniciya gosterilecek mesajla Drive hatasi.
class DriveException implements Exception {
  const DriveException(this.message, {this.needsReconnect = false});

  final String message;

  /// Yetki suresi doldu / geri alindi: kullanici tekrar baglanmali.
  final bool needsReconnect;

  @override
  String toString() => 'DriveException: $message';
}

/// Kullanici hesap secimini iptal etti (mesaj gosterilmez).
class DriveCancelled implements Exception {
  const DriveCancelled();
}

class DriveBackupFile {
  const DriveBackupFile({required this.id, required this.name, required this.createdAt, this.sizeBytes});

  final String id;
  final String name;
  final DateTime createdAt;
  final int? sizeBytes;
}

/// Yedekleri en yeniden eskiye siralayip [keep] sayisini asanlari dondurur.
List<DriveBackupFile> filesToPrune(List<DriveBackupFile> files, int keep) {
  final sorted = [...files]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return sorted.skip(keep).toList();
}

/// Firsatci on plan yedegi kosullari (PLAN 8.4). Internet kontrolu ayrica yapilir.
bool shouldAutoBackup({
  required bool enabled,
  required bool connected,
  required DateTime now,
  DateTime? lastDriveBackup,
  DateTime? lastLocalChange,
  DateTime? lastBackup,
}) {
  if (!enabled || !connected) return false;
  if (lastDriveBackup != null && now.difference(lastDriveBackup) < DriveConfig.autoBackupInterval) return false;
  if (lastLocalChange == null) return false;
  return lastBackup == null || lastLocalChange.isAfter(lastBackup);
}

/// Google hesabi baglama ve Drive'daki yedek klasoru islemleri.
class DriveService {
  bool _initialized = false;

  bool get isConfigured => DriveConfig.isConfigured;

  Future<void> _init() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(serverClientId: DriveConfig.serverClientId);
    _initialized = true;
  }

  /// Hesap secimi + Drive izni. Bagli hesabin e-postasini dondurur.
  Future<String> connect() async {
    try {
      await _init();
      final account = await GoogleSignIn.instance.authenticate(scopeHint: driveScopes);
      await account.authorizationClient.authorizeScopes(driveScopes);
      return account.email;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw const DriveCancelled();
      throw const DriveException(S.driveConnectFailed);
    } catch (e) {
      if (e is DriveCancelled) rethrow;
      throw const DriveException(S.driveConnectFailed);
    }
  }

  /// Izinleri geri alir. Drive'daki dosyalar silinmez.
  Future<void> disconnect() async {
    try {
      await _init();
      await GoogleSignIn.instance.disconnect();
    } catch (_) {
      // Baglanti kesmede hata kullaniciyi engellemesin
    }
  }

  /// Yetkili Drive istemcisi. [interactive] false ise hicbir arayuz gosterilmez
  /// (otomatik yedek); yetki yoksa tekrar baglanma hatasi atilir.
  Future<drive.DriveApi> _api({required bool interactive}) async {
    await _init();
    GoogleSignInAccount? account;
    try {
      account = await GoogleSignIn.instance.attemptLightweightAuthentication();
    } catch (_) {
      account = null;
    }
    final client = account?.authorizationClient ?? GoogleSignIn.instance.authorizationClient;
    var authorization = await client.authorizationForScopes(driveScopes);
    if (authorization == null && interactive) authorization = await client.authorizeScopes(driveScopes);
    if (authorization == null) throw const DriveException(S.driveReconnect, needsReconnect: true);
    return drive.DriveApi(authorization.authClient(scopes: driveScopes));
  }

  /// Hatalari kullaniciya uygun mesajlara cevirir.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DriveException {
      rethrow;
    } on DriveCancelled {
      rethrow;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw const DriveCancelled();
      throw const DriveException(S.driveReconnect, needsReconnect: true);
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 401 || e.status == 403) throw const DriveException(S.driveReconnect, needsReconnect: true);
      throw const DriveException(S.driveFailed);
    } on SocketException {
      throw const DriveException(S.driveNetworkError);
    } on TimeoutException {
      throw const DriveException(S.driveNetworkError);
    } catch (e) {
      // http ClientException vb. ag hatalari
      if (e.toString().contains('ClientException') || e.toString().contains('Socket')) {
        throw const DriveException(S.driveNetworkError);
      }
      throw const DriveException(S.driveFailed);
    }
  }

  Future<String> _folderId(drive.DriveApi api) async {
    final name = DriveConfig.folderName.replaceAll("'", r"\'");
    final res = await api.files.list(
      q: "mimeType='application/vnd.google-apps.folder' and name='$name' and trashed=false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    final existing = res.files;
    if (existing != null && existing.isNotEmpty) return existing.first.id!;
    final folder = await api.files.create(
      drive.File()
        ..name = DriveConfig.folderName
        ..mimeType = 'application/vnd.google-apps.folder',
      $fields: 'id',
    );
    return folder.id!;
  }

  Future<List<DriveBackupFile>> _list(drive.DriveApi api, String folderId) async {
    final res = await api.files.list(
      q: "'$folderId' in parents and trashed=false and mimeType!='application/vnd.google-apps.folder'",
      orderBy: 'createdTime desc',
      pageSize: 100,
      $fields: 'files(id,name,size,createdTime)',
    );
    return [
      for (final f in res.files ?? const <drive.File>[])
        DriveBackupFile(
          id: f.id!,
          name: f.name ?? '',
          createdAt: (f.createdTime ?? DateTime.now()).toLocal(),
          sizeBytes: int.tryParse(f.size ?? ''),
        ),
    ];
  }

  /// Yedegi yukler ve klasorde en fazla [DriveConfig.keepBackups] yedek birakir.
  Future<void> uploadBackup(File zip, {required bool interactive}) => _guard(() async {
        final api = await _api(interactive: interactive);
        final folderId = await _folderId(api);
        await api.files.create(
          drive.File()
            ..name = p.basename(zip.path)
            ..mimeType = 'application/zip'
            ..parents = [folderId],
          uploadMedia: drive.Media(zip.openRead(), await zip.length(), contentType: 'application/zip'),
          $fields: 'id',
        );
        for (final old in filesToPrune(await _list(api, folderId), DriveConfig.keepBackups)) {
          await api.files.delete(old.id);
        }
      });

  /// Drive'daki yedekler, en yeni once.
  Future<List<DriveBackupFile>> listBackups() => _guard(() async {
        final api = await _api(interactive: true);
        return _list(api, await _folderId(api));
      });

  /// Yedegi [targetPath] dosyasina indirir.
  Future<File> download(DriveBackupFile file, String targetPath) => _guard(() async {
        final api = await _api(interactive: true);
        final media = await api.files.get(file.id, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
        final out = File(targetPath);
        await out.parent.create(recursive: true);
        final sink = out.openWrite();
        await sink.addStream(media.stream);
        await sink.close();
        return out;
      });
}
