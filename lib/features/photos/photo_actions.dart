import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/daos/settings_dao.dart';
import '../../core/db/database.dart';
import '../../core/db/db_providers.dart';
import '../../core/strings.dart';

/// Bir kaydin canli fotograf listesi.
final photosProvider = StreamProvider.autoDispose.family<List<Photo>, (PhotoOwnerType, String)>(
  (ref, owner) => ref.watch(databaseProvider).photosDao.watchPhotos(owner.$1, owner.$2),
);

/// Kucuk resim / tam boyut dosyalarinin bulundugu klasor.
final photosDirProvider = FutureProvider<String>((ref) async => (await ref.watch(appPathsProvider.future)).photosDir);

String _ownerKey(PhotoOwnerType type, String id) => '${type.name}:$id';

/// Kamera ya da galeriden fotograf ekler; kucultup kaydeder.
Future<void> addPhotos(
  BuildContext context,
  WidgetRef ref, {
  required PhotoOwnerType ownerType,
  required String ownerId,
  required bool camera,
}) async {
  final db = ref.read(databaseProvider);
  final service = ref.read(photoServiceProvider);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final dir = await ref.read(photosDirProvider.future);

  List<String> picked;
  try {
    // Kamera acikken Android uygulamayi kapatirsa fotograf acilista bu kayda eklenir
    await db.settingsDao.setValue(SettingKeys.pendingPhotoOwner, _ownerKey(ownerType, ownerId));
    picked = await service.pick(camera: camera);
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text(S.photoFailed)));
    return;
  } finally {
    await db.settingsDao.setValue(SettingKeys.pendingPhotoOwner, null);
  }
  if (picked.isEmpty) return;

  var dialogOpen = false;
  if (context.mounted) {
    dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(children: [CircularProgressIndicator(), SizedBox(width: 20), Text(S.photoSaving)]),
        ),
      ),
    );
  }
  var failed = 0;
  for (final path in picked) {
    try {
      final files = await service.store(path, dir);
      await db.photosDao.insertPhoto(
        ownerType: ownerType,
        ownerId: ownerId,
        fileName: files.fileName,
        thumbFileName: files.thumbFileName,
      );
    } catch (_) {
      failed++;
    }
  }
  if (dialogOpen) navigator.pop();
  if (failed > 0) messenger.showSnackBar(const SnackBar(content: Text(S.photoFailed)));
}

/// Acilista: kamera acikken uygulama kapanmissa donen fotografi bekleyen kayda ekler.
Future<int> recoverLostPhotos(WidgetRef ref) async {
  final db = ref.read(databaseProvider);
  final service = ref.read(photoServiceProvider);
  try {
    final pending = await db.settingsDao.getStoredValue(SettingKeys.pendingPhotoOwner);
    if (pending == null) return 0;
    await db.settingsDao.setValue(SettingKeys.pendingPhotoOwner, null);
    final [typeName, id] = pending.split(':');
    final type = PhotoOwnerType.values.byName(typeName);
    final lost = await service.retrieveLost();
    if (lost.isEmpty) return 0;
    final dir = await ref.read(photosDirProvider.future);
    var added = 0;
    for (final path in lost) {
      final files = await service.store(path, dir);
      await db.photosDao.insertPhoto(
        ownerType: type,
        ownerId: id,
        fileName: files.fileName,
        thumbFileName: files.thumbFileName,
      );
      added++;
    }
    return added;
  } catch (_) {
    return 0;
  }
}

/// Onay ister; fotografi ve dosyalarini kalici siler. Silindiyse true.
Future<bool> confirmDeletePhoto(BuildContext context, WidgetRef ref, Photo photo) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(S.photoDeleteTitle),
      content: const Text(S.photoDeleteBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(S.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text(S.delete)),
      ],
    ),
  );
  if (ok != true) return false;
  final db = ref.read(databaseProvider);
  final service = ref.read(photoServiceProvider);
  final dir = await ref.read(photosDirProvider.future);
  final row = await db.photosDao.deletePhoto(photo.id);
  if (row != null) {
    try {
      await service.deleteFiles(row, dir);
    } catch (_) {
      // Dosya silinemese de kayit silindi; artik dosya yedege girer ama gorunmez
    }
  }
  return true;
}
