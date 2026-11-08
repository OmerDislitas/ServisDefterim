import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/tables.dart';

part 'photos_dao.g.dart';

/// Cihaz ve servis fotograflari (PLAN 10). Dosyalar `photos/` klasorunde,
/// veritabaninda sadece goreli dosya adlari.
@DriftAccessor(tables: [Photos])
class PhotosDao extends DatabaseAccessor<AppDatabase> with _$PhotosDaoMixin {
  PhotosDao(super.attachedDatabase);

  Future<String> insertPhoto({
    required PhotoOwnerType ownerType,
    required String ownerId,
    required String fileName,
    required String thumbFileName,
  }) async {
    final row = await into(photos).insertReturning(PhotosCompanion.insert(
      ownerType: ownerType,
      ownerId: ownerId,
      fileName: fileName,
      thumbFileName: thumbFileName,
    ));
    return row.id;
  }

  SimpleSelectStatement<$PhotosTable, Photo> _forOwner(PhotoOwnerType ownerType, String ownerId) =>
      select(photos)
        ..where((t) => t.ownerType.equalsValue(ownerType) & t.ownerId.equals(ownerId) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt), (t) => OrderingTerm.asc(t.id)]);

  Stream<List<Photo>> watchPhotos(PhotoOwnerType ownerType, String ownerId) => _forOwner(ownerType, ownerId).watch();

  Future<List<Photo>> getPhotos(PhotoOwnerType ownerType, String ownerId) => _forOwner(ownerType, ownerId).get();

  /// Fotografi kalici siler (dosyalari cagiran siler). Silinen satir doner.
  Future<Photo?> deletePhoto(String id) async {
    final row = await (select(photos)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row != null) await (delete(photos)..where((t) => t.id.equals(id))).go();
    return row;
  }

  /// Satiri olmayan (artik) dosyalari bulmak icin kullanilan tum dosya adlari (silinmisler dahil).
  Future<Set<String>> allFileNames() async {
    final rows = await select(photos).get();
    return {for (final r in rows) ...[r.fileName, r.thumbFileName]};
  }
}
