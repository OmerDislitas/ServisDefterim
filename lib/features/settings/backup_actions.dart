import 'dart:io';

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

/// "Dosyadan geri yukle" (PLAN 8.3): dosya sec, dogrula, onizle ve onayla,
/// guvenlik yedegi al, verileri degistir, veritabanini yeniden ac.
Future<void> restoreFromFile(BuildContext context, WidgetRef ref) async {
  final picked = await FilePicker.pickFile(type: FileType.any);
  if (picked == null || !context.mounted) return;

  final service = await ref.read(backupServiceProvider.future);
  final db = ref.read(databaseProvider);

  // Secilen dosya bir content:// adresi olabilir; once gecici dosyaya kopyala
  final tmp = File(p.join(service.paths.tempDir, 'picked_${DateTime.now().microsecondsSinceEpoch}.zip'));
  final BackupPreview preview;
  try {
    final sink = tmp.openWrite();
    await sink.addStream(picked.readAsByteStream());
    await sink.close();
    preview = await service.inspect(tmp, currentSchemaVersion: db.schemaVersion);
  } on BackupException catch (e) {
    if (context.mounted) await _showError(context, e.message);
    return;
  } catch (_) {
    if (context.mounted) await _showError(context, S.backupInvalidFile);
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
  } finally {
    if (tmp.existsSync()) await tmp.delete();
  }
}
