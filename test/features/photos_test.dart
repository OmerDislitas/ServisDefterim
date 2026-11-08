import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:servis_defterim/core/db/database.dart';
import 'package:servis_defterim/core/router/app_router.dart';
import 'package:servis_defterim/core/services/photo_service.dart';
import 'package:servis_defterim/core/strings.dart';
import 'package:servis_defterim/features/photos/photo_viewer_screen.dart';

import '../db/test_db.dart';
import '../helpers.dart';

/// Kamera / sikistirma eklentisi olmadan: secilen her "fotograf" icin iki kucuk dosya yazar.
/// Widget testinin sahte zamaninda async dosya islemi bitmedigi icin senkron calisir.
class _FakePhotoService extends PhotoService {
  int picks = 0;

  @override
  Future<List<String>> pick({required bool camera}) async {
    picks++;
    return camera ? ['kamera.jpg'] : ['galeri1.jpg', 'galeri2.jpg'];
  }

  @override
  Future<({String fileName, String thumbFileName})> store(String sourcePath, String photosDir) async {
    Directory(photosDir).createSync(recursive: true);
    final id = newId();
    File(p.join(photosDir, '$id.jpg')).writeAsBytesSync([1, 2, 3]);
    File(p.join(photosDir, '${id}_k.jpg')).writeAsBytesSync([4]);
    return (fileName: '$id.jpg', thumbFileName: '${id}_k.jpg');
  }

  @override
  Future<void> deleteFiles(Photo photo, String photosDir) async {
    for (final name in [photo.fileName, photo.thumbFileName]) {
      final f = File(p.join(photosDir, name));
      if (f.existsSync()) f.deleteSync();
    }
  }
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('servis_photos_test'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('kombi silinince fotoğrafları da gizlenir, geri alınca döner', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = createTestDb();
    final ids = await createCustomerWithDevice(db);
    await db.photosDao.insertPhoto(
      ownerType: PhotoOwnerType.device,
      ownerId: ids.deviceId,
      fileName: 'a.jpg',
      thumbFileName: 'a_k.jpg',
    );
    expect(await db.photosDao.getPhotos(PhotoOwnerType.device, ids.deviceId), hasLength(1));

    final ts = await db.softDelete(EntityKind.customer, ids.customerId);
    expect(await db.photosDao.getPhotos(PhotoOwnerType.device, ids.deviceId), isEmpty);
    // Dosya adlari silinmis kayitlar icin de bilinir (dosyalar korunur)
    expect(await db.photosDao.allFileNames(), {'a.jpg', 'a_k.jpg'});

    await db.restore(EntityKind.customer, ids.customerId, ts);
    expect(await db.photosDao.getPhotos(PhotoOwnerType.device, ids.deviceId), hasLength(1));
    await db.close();
  });

  testAppWidgets('Kombiye fotoğraf eklenir, görüntüleyicide açılır ve silinir', (tester) async {
    late ({String customerId, String addressId, String deviceId}) ids;
    final photos = _FakePhotoService();
    final dir = p.join(tmp.path, 'photos');
    final db = await pumpApp(
      tester,
      photoService: photos,
      photosDir: dir,
      seed: (db) async => ids = await createCustomerWithDevice(db),
    );
    await pushRoute(tester, Routes.device(ids.deviceId));
    expect(find.text(S.noPhotos), findsOneWidget);

    // Galeriden iki fotograf
    await tester.tap(find.text(S.addPhoto));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.pickFromGallery));
    await tester.pumpAndSettle();
    final saved = await firstOf(tester, db.photosDao.watchPhotos(PhotoOwnerType.device, ids.deviceId));
    expect(saved, hasLength(2));
    expect(find.text(S.noPhotos), findsNothing);
    expect(find.byKey(ValueKey(saved.first.id)), findsOneWidget);
    expect(Directory(dir).listSync(), hasLength(4));

    // Goruntuleyici
    await tester.ensureVisible(find.byKey(ValueKey(saved.first.id)));
    await tester.drag(find.byType(ListView).first, const Offset(0, -150));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(saved.first.id)));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewerScreen), findsOneWidget);
    expect(find.text(S.photoCount(1, 2)), findsOneWidget);

    // Sil: kayit ve dosyalar gider
    await tester.tap(find.byTooltip(S.delete));
    await tester.pumpAndSettle();
    expect(find.text(S.photoDeleteTitle), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, S.delete));
    await tester.pumpAndSettle();
    expect(find.text(S.photoCount(1, 1)), findsOneWidget);
    final left = await firstOf(tester, db.photosDao.watchPhotos(PhotoOwnerType.device, ids.deviceId));
    expect(left.single.id, saved.last.id);
    expect(Directory(dir).listSync(), hasLength(2));

    // Son fotograf silinince goruntuleyici kapanir
    await tester.tap(find.byTooltip(S.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, S.delete));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewerScreen), findsNothing);
    expect(find.text(S.noPhotos), findsOneWidget);
    expect(Directory(dir).listSync(), isEmpty);
  });
}
