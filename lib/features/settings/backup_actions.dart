import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/db/daos/settings_dao.dart';
import '../../core/db/db_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/drive_service.dart';
import '../../core/strings.dart';
import '../../core/utils/dates.dart';

void _showProgress(BuildContext context, String message) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showError(BuildContext context, String message) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text(S.ok))],
      ),
    );

// -----------------------------------------------------------------------------
// Disa aktar / paylas
// -----------------------------------------------------------------------------

/// "Yedegi disa aktar ve paylas" (PLAN 8.2): zip olustur, paylasim menusunu ac,
/// basarili paylasimda `lastBackupAt` guncelle.
Future<void> exportAndShareBackup(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  final db = ref.read(databaseProvider);
  _showProgress(context, S.backupPreparing);

  final File file;
  try {
    final service = await ref.read(backupServiceProvider.future);
    await service.clearExports();
    file = await service.createBackup(db, outDir: service.paths.exportsDir);
  } catch (_) {
    rootNavigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text(S.backupFailed)));
    return;
  }
  rootNavigator.pop();

  final result = await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: 'application/zip')],
    subject: S.backupShareSubject,
  ));
  // Android bazen sonucu bildiremez (unavailable); sadece acikca vazgecilirse sayilmaz
  if (result.status != ShareResultStatus.dismissed) {
    await db.settingsDao.setValue(SettingKeys.lastBackupAt, DateTime.now().toIso8601String());
    messenger.showSnackBar(const SnackBar(content: Text(S.backupShared)));
  }
}

// -----------------------------------------------------------------------------
// Geri yukleme
// -----------------------------------------------------------------------------

/// "Dosyadan geri yukle" (PLAN 8.3).
Future<void> restoreFromFile(BuildContext context, WidgetRef ref) async {
  final picked = await FilePicker.pickFile(type: FileType.any);
  if (picked == null || !context.mounted) return;

  final service = await ref.read(backupServiceProvider.future);
  // Secilen dosya bir content:// adresi olabilir; once gecici dosyaya kopyala
  final tmp = File(p.join(service.paths.tempDir, 'picked_${DateTime.now().microsecondsSinceEpoch}.zip'));
  try {
    final sink = tmp.openWrite();
    await sink.addStream(picked.readAsByteStream());
    await sink.close();
  } catch (_) {
    if (context.mounted) await _showError(context, S.backupInvalidFile);
    return;
  }
  if (context.mounted) await _restoreFromZip(context, ref, tmp);
}

/// Indirilmis/secilmis zip'i dogrula, onizle, onayla ve geri yukle. Zip sonunda silinir.
Future<void> _restoreFromZip(BuildContext context, WidgetRef ref, File zip) async {
  final service = await ref.read(backupServiceProvider.future);
  final db = ref.read(databaseProvider);
  try {
    final BackupPreview preview;
    try {
      preview = await service.inspect(zip, currentSchemaVersion: db.schemaVersion);
    } on BackupException catch (e) {
      if (context.mounted) await _showError(context, e.message);
      return;
    }
    if (!context.mounted) return;

    final m = preview.manifest;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(S.restoreConfirmTitle),
        content: Text(S.restoreConfirmBody(m.count('customers'), m.count('services'), formatDateTime(m.createdAt))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(S.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text(S.restore)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final router = GoRouter.of(context);
    _showProgress(context, S.restoring);
    try {
      await service.restore(
        preview: preview,
        current: db,
        reopen: () {
          ref.invalidate(databaseProvider);
          return ref.read(databaseProvider);
        },
      );
      rootNavigator.pop();
      router.go(Routes.today);
      messenger.showSnackBar(const SnackBar(content: Text(S.restoreDone)));
    } on BackupException catch (e) {
      rootNavigator.pop();
      if (context.mounted) await _showError(context, e.message);
    }
  } finally {
    if (zip.existsSync()) await zip.delete();
  }
}

// -----------------------------------------------------------------------------
// Google Drive (PLAN 8.4)
// -----------------------------------------------------------------------------

/// Hesap secimi + izin; bagli e-postayi kaydeder.
Future<void> connectDrive(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final settings = ref.read(databaseProvider).settingsDao;
  try {
    final email = await ref.read(driveServiceProvider).connect();
    await settings.setValue(SettingKeys.driveAccountEmail, email);
    await settings.setValue(SettingKeys.driveLastError, null);
    messenger.showSnackBar(const SnackBar(content: Text(S.driveConnected)));
  } on DriveCancelled {
    return;
  } on DriveException catch (e) {
    if (context.mounted) await _showError(context, e.message);
  }
}

Future<void> disconnectDrive(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(S.driveDisconnectTitle),
      content: const Text(S.driveDisconnectBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(S.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text(S.driveDisconnect)),
      ],
    ),
  );
  if (ok != true) return;
  final settings = ref.read(databaseProvider).settingsDao;
  await ref.read(driveServiceProvider).disconnect();
  await settings.setValue(SettingKeys.driveAccountEmail, null);
  await settings.setBool(SettingKeys.driveAutoBackup, false);
  await settings.setValue(SettingKeys.driveLastError, null);
}

/// Yedek olusturup Drive'a yukler; basarida zamanlari yazar, hatayi temizler.
/// Hata [DriveException] / [BackupException] olarak firlatilir.
Future<void> _performDriveBackup(WidgetRef ref, {required bool interactive}) async {
  final db = ref.read(databaseProvider);
  final service = await ref.read(backupServiceProvider.future);
  final file = await service.createBackup(db, outDir: p.join(service.paths.exportsDir, 'drive'));
  try {
    await ref.read(driveServiceProvider).uploadBackup(file, interactive: interactive);
  } finally {
    if (file.existsSync()) await file.delete();
  }
  final now = DateTime.now().toIso8601String();
  await db.settingsDao.setValue(SettingKeys.lastBackupAt, now);
  await db.settingsDao.setValue(SettingKeys.lastDriveBackupAt, now);
  await db.settingsDao.setValue(SettingKeys.driveLastError, null);
}

/// "Drive'a simdi yedekle".
Future<void> backupToDriveNow(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  _showProgress(context, S.driveUploading);
  try {
    await _performDriveBackup(ref, interactive: true);
    rootNavigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text(S.driveBackupDone)));
  } on DriveCancelled {
    rootNavigator.pop();
  } on DriveException catch (e) {
    rootNavigator.pop();
    await ref.read(databaseProvider).settingsDao.setValue(SettingKeys.driveLastError, e.message);
    if (context.mounted) await _showError(context, e.message);
  } catch (_) {
    rootNavigator.pop();
    if (context.mounted) await _showError(context, S.backupFailed);
  }
}

/// "Drive'dan geri yukle": yedekleri tarih ve boyutla listele, secileni indir, geri yukle.
Future<void> restoreFromDrive(BuildContext context, WidgetRef ref) async {
  final drive = ref.read(driveServiceProvider);
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  _showProgress(context, S.driveLoadingList);
  final List<DriveBackupFile> files;
  try {
    files = await drive.listBackups();
  } on DriveCancelled {
    rootNavigator.pop();
    return;
  } on DriveException catch (e) {
    rootNavigator.pop();
    if (context.mounted) await _showError(context, e.message);
    return;
  }
  rootNavigator.pop();
  if (!context.mounted) return;

  final selected = await showModalBottomSheet<DriveBackupFile>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: files.isEmpty
            ? const Padding(padding: EdgeInsets.all(24), child: Text(S.driveNoBackups))
            : ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(S.driveRestore, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  for (final f in files)
                    ListTile(
                      leading: const Icon(Icons.cloud_outlined),
                      title: Text(formatDateTime(f.createdAt)),
                      subtitle: Text([f.name, if (f.sizeBytes != null) formatFileSize(f.sizeBytes!)].join(' · ')),
                      onTap: () => Navigator.pop(context, f),
                    ),
                ],
              ),
      ),
    ),
  );
  if (selected == null || !context.mounted) return;

  final service = await ref.read(backupServiceProvider.future);
  if (!context.mounted) return;
  _showProgress(context, S.driveDownloading);
  final File zip;
  try {
    zip = await drive.download(
      selected,
      p.join(service.paths.tempDir, 'drive_${DateTime.now().microsecondsSinceEpoch}.zip'),
    );
  } on DriveException catch (e) {
    rootNavigator.pop();
    if (context.mounted) await _showError(context, e.message);
    return;
  } on DriveCancelled {
    rootNavigator.pop();
    return;
  }
  rootNavigator.pop();
  if (context.mounted) await _restoreFromZip(context, ref, zip);
}

/// "2,3 MB"
String formatFileSize(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} KB';
  final mb = bytes / (1024 * 1024);
  return '${mb.toStringAsFixed(1).replaceAll('.', ',')} MB';
}

// -----------------------------------------------------------------------------
// Firsatci otomatik Drive yedegi
// -----------------------------------------------------------------------------

bool _autoBackupRunning = false;

/// Uygulama acildiginda / on plana geldiginde cagrilir. Kosullar saglaniyorsa
/// sessizce Drive'a yedek atar; hatalar kullaniciyi engellemez, Bugun ekraninda gosterilir.
Future<void> runAutoBackupIfNeeded(WidgetRef ref) async {
  if (_autoBackupRunning || !ref.read(driveServiceProvider).isConfigured) return;
  _autoBackupRunning = true;
  try {
    final settings = ref.read(databaseProvider).settingsDao;
    final should = shouldAutoBackup(
      enabled: await settings.getBool(SettingKeys.driveAutoBackup),
      connected: await settings.getStoredValue(SettingKeys.driveAccountEmail) != null,
      now: DateTime.now(),
      lastDriveBackup: await settings.getDateTime(SettingKeys.lastDriveBackupAt),
      lastLocalChange: await settings.getDateTime(SettingKeys.lastLocalChangeAt),
      lastBackup: await settings.getDateTime(SettingKeys.lastBackupAt),
    );
    if (!should) return;

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.every((c) => c == ConnectivityResult.none)) return;

    try {
      await _performDriveBackup(ref, interactive: false);
    } on DriveException catch (e) {
      await settings.setValue(SettingKeys.driveLastError, e.message);
    } on DriveCancelled {
      await settings.setValue(SettingKeys.driveLastError, S.driveReconnect);
    } catch (_) {
      await settings.setValue(SettingKeys.driveLastError, S.driveFailed);
    }
  } catch (_) {
    // Otomatik yedek hicbir zaman uygulamayi bozmamali
  } finally {
    _autoBackupRunning = false;
  }
}
