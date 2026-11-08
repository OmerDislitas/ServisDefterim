import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../db/daos/settings_dao.dart';
import '../db/database.dart';
import '../strings.dart';
import 'app_paths.dart';

/// Kullaniciya gosterilecek (teknik olmayan) mesajla yedekleme hatasi.
class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => 'BackupException: $message';
}

/// Yedek zip'indeki manifest.json (PLAN 8.1).
class BackupManifest {
  const BackupManifest({
    required this.app,
    required this.appVersion,
    required this.schemaVersion,
    required this.createdAt,
    required this.counts,
  });

  final String app;
  final String appVersion;
  final int schemaVersion;
  final DateTime createdAt;
  final Map<String, int> counts;

  int count(String key) => counts[key] ?? 0;

  Map<String, dynamic> toJson() => {
        'app': app,
        'appVersion': appVersion,
        'schemaVersion': schemaVersion,
        'createdAt': isoWithOffset(createdAt),
        'counts': counts,
      };

  factory BackupManifest.fromJson(Map<String, dynamic> j) => BackupManifest(
        app: j['app'] as String,
        appVersion: j['appVersion'] as String? ?? '',
        schemaVersion: j['schemaVersion'] as int,
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
        counts: (j['counts'] as Map? ?? const {}).map((k, v) => MapEntry(k as String, v as int)),
      );

  /// Manifest kontrolu (PLAN 8.3): uygulama eslesmeli, sema surumu mevcut surumden buyuk olmamali.
  void validate({required int currentSchemaVersion}) {
    if (app != BackupService.appId) throw const BackupException(S.backupWrongApp);
    if (schemaVersion > currentSchemaVersion) throw const BackupException(S.backupNewerVersion);
  }
}

/// "2026-11-08T18:40:00+03:00"
String isoWithOffset(DateTime t) {
  final local = t.toLocal();
  final off = local.timeZoneOffset;
  final sign = off.isNegative ? '-' : '+';
  final h = off.inHours.abs().toString().padLeft(2, '0');
  final m = (off.inMinutes.abs() % 60).toString().padLeft(2, '0');
  final base = local.toIso8601String().split('.').first;
  return '$base$sign$h:$m';
}

/// Disari aktarilip incelenmis, geri yuklemeye hazir yedek.
class BackupPreview {
  const BackupPreview({required this.manifest, required this.dir});

  final BackupManifest manifest;

  /// Zip'in acildigi gecici klasor.
  final Directory dir;

  File get dbFile => File(p.join(dir.path, BackupService.dbEntry));
  Directory get photosDir => Directory(p.join(dir.path, BackupService.photosEntry));
}

/// Yedek olusturma, inceleme ve verileri degistirme (PLAN 8).
///
/// Zip duzeni:
///   manifest.json
///   servis_defterim.db
///   photos/...
class BackupService {
  BackupService({required this.paths, required this.appVersion});

  final AppPaths paths;
  final String appVersion;

  static const appId = 'servis_defterim';
  static const manifestEntry = 'manifest.json';
  static const dbEntry = 'servis_defterim.db';
  static const photosEntry = 'photos';
  static const safetyBackupsToKeep = 3;

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// servis_defterim_yedek_2026-11-08_1840.zip
  static String fileNameFor(DateTime t) =>
      'servis_defterim_yedek_${t.year}-${_two(t.month)}-${_two(t.day)}_${_two(t.hour)}${_two(t.minute)}.zip';

  Future<Directory> _newTempDir(String prefix) =>
      Directory(p.join(paths.tempDir, '${prefix}_${DateTime.now().microsecondsSinceEpoch}')).create(recursive: true);

  /// Veritabaninin tutarli kopyasini (`VACUUM INTO`) ve fotograflari zip'ler.
  /// Zip olusturma arka plan isolate'inde yapilir.
  Future<File> createBackup(AppDatabase db, {required String outDir, DateTime? now}) async {
    final createdAt = now ?? DateTime.now();
    final work = await _newTempDir('backup');
    try {
      final dbCopy = p.join(work.path, dbEntry);
      // Acik veritabani dosyasi (WAL nedeniyle) dogrudan kopyalanmaz
      await db.customStatement("VACUUM INTO '${dbCopy.replaceAll("'", "''")}'");

      final counts = await db.recordCounts();
      final manifest = BackupManifest(
        app: appId,
        appVersion: appVersion,
        schemaVersion: db.schemaVersion,
        createdAt: createdAt,
        counts: {
          'customers': counts.customers,
          'devices': counts.devices,
          'services': counts.services,
          'appointments': counts.appointments,
        },
      );
      await File(p.join(work.path, manifestEntry)).writeAsString(jsonEncode(manifest.toJson()));

      await Directory(outDir).create(recursive: true);
      final out = p.join(outDir, fileNameFor(createdAt));
      final workPath = work.path;
      final photos = paths.photosDir;
      await Isolate.run(() => _zip(out, workPath, photos));
      return File(out);
    } finally {
      await work.delete(recursive: true);
    }
  }

  static Future<void> _zip(String out, String workDir, String photosDir) async {
    final encoder = ZipFileEncoder()..create(out);
    await encoder.addFile(File(p.join(workDir, manifestEntry)), manifestEntry);
    await encoder.addFile(File(p.join(workDir, dbEntry)), dbEntry);
    final photos = Directory(photosDir);
    if (photos.existsSync()) await encoder.addDirectory(photos, includeDirName: true);
    await encoder.close();
  }

  /// Zip'i gecici klasore acar ve dogrular. Gecersizse [BackupException].
  Future<BackupPreview> inspect(File zip, {required int currentSchemaVersion}) async {
    final dir = await _newTempDir('restore');
    final zipPath = zip.path;
    final dirPath = dir.path;
    try {
      await Isolate.run(() => _extract(zipPath, dirPath));
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupException(S.backupInvalidFile);
    }

    final manifestFile = File(p.join(dir.path, manifestEntry));
    if (!manifestFile.existsSync()) throw const BackupException(S.backupInvalidFile);
    final BackupManifest manifest;
    try {
      manifest = BackupManifest.fromJson(jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      throw const BackupException(S.backupInvalidFile);
    }
    manifest.validate(currentSchemaVersion: currentSchemaVersion);

    final preview = BackupPreview(manifest: manifest, dir: dir);
    if (!await _looksLikeSqlite(preview.dbFile)) throw const BackupException(S.backupInvalidFile);
    return preview;
  }

  /// Sadece beklenen girdileri acar (zip icinden klasor disina yazmayi engeller).
  static void _extract(String zipPath, String outDir) {
    final input = InputFileStream(zipPath);
    try {
      final archive = ZipDecoder().decodeStream(input);
      for (final entry in archive.files) {
        if (!entry.isFile) continue;
        final name = entry.name.replaceAll('\\', '/');
        final parts = name.split('/');
        final allowed = name == manifestEntry ||
            name == dbEntry ||
            (parts.length == 2 && parts[0] == photosEntry && parts[1].isNotEmpty && !parts[1].startsWith('.'));
        if (!allowed) continue;
        final target = File(p.joinAll([outDir, ...parts]));
        target.parent.createSync(recursive: true);
        target.writeAsBytesSync(entry.content);
      }
    } finally {
      input.closeSync();
    }
  }

  static Future<bool> _looksLikeSqlite(File f) async {
    if (!f.existsSync()) return false;
    final raf = await f.open();
    try {
      final header = await raf.read(16);
      return ascii.decode(header.sublist(0, 15), allowInvalid: true) == 'SQLite format 3';
    } finally {
      await raf.close();
    }
  }

  /// Veritabani dosyasini ve fotograflari yedektekilerle degistirir.
  /// Cagirmadan once veritabani baglantisi KAPATILMIS olmali.
  Future<void> replaceData(BackupPreview preview) async {
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final f = File('${paths.dbFile}$suffix');
      if (f.existsSync()) await f.delete();
    }
    await File(paths.dbFile).parent.create(recursive: true);
    await preview.dbFile.copy(paths.dbFile);

    final photos = Directory(paths.photosDir);
    if (photos.existsSync()) await photos.delete(recursive: true);
    if (preview.photosDir.existsSync()) {
      await photos.create(recursive: true);
      await for (final f in preview.photosDir.list()) {
        if (f is File) await f.copy(p.join(photos.path, p.basename(f.path)));
      }
    }
  }

  /// Geri yukleme oncesi mevcut veriden yerel guvenlik yedegi; son 3'u tutulur.
  Future<File> createSafetyBackup(AppDatabase db) async {
    final file = await createBackup(db, outDir: paths.safetyBackupsDir);
    final all = Directory(paths.safetyBackupsDir).listSync().whereType<File>().toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    for (final old in all.skip(safetyBackupsToKeep)) {
      await old.delete();
    }
    return file;
  }

  /// Geri yukleme (PLAN 8.3, adim 4-5): guvenlik yedegi al, baglantiyi kapat, dosyalari
  /// degistir, veritabanini [reopen] ile yeniden ac (migration'lar burada calisir).
  /// Bir adim basarisiz olursa guvenlik yedeginden geri donulur ve [BackupException] atilir.
  /// Donen deger yeni acilan veritabanidir.
  Future<AppDatabase> restore({
    required BackupPreview preview,
    required AppDatabase current,
    required AppDatabase Function() reopen,
  }) async {
    final schemaVersion = current.schemaVersion;
    // Bu telefona ozel ayarlar (Drive hesabi vb.) yedektekilerle ezilmesin
    final deviceLocal = {
      for (final k in SettingKeys.deviceLocal) k: await current.settingsDao.getStoredValue(k),
    };
    final safety = await createSafetyBackup(current);
    await current.close();

    AppDatabase? fresh;
    try {
      await replaceData(preview);
      fresh = reopen();
      await fresh.recordCounts(); // baglantiyi acar, gerekirse migration'lari calistirir
      for (final e in deviceLocal.entries) {
        await fresh.settingsDao.setValue(e.key, e.value);
      }
      await fresh.settingsDao.setValue(SettingKeys.lastBackupAt, preview.manifest.createdAt.toIso8601String());
      return fresh;
    } catch (_) {
      await fresh?.close();
      final back = await inspect(safety, currentSchemaVersion: schemaVersion);
      await replaceData(back);
      reopen();
      throw const BackupException(S.restoreFailed);
    }
  }

  /// Paylasim icin eski gecici yedekleri temizler.
  Future<void> clearExports() async {
    final dir = Directory(paths.exportsDir);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
