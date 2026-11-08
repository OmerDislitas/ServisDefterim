import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/tables.dart';

part 'checklist_dao.g.dart';

@DriftAccessor(tables: [ChecklistTemplates])
class ChecklistDao extends DatabaseAccessor<AppDatabase> with _$ChecklistDaoMixin {
  ChecklistDao(super.attachedDatabase);

  Stream<List<ChecklistTemplate>> watchItems({bool includeInactive = true}) {
    final q = select(checklistTemplates)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
    if (!includeInactive) q.where((t) => t.isActive.equals(true));
    return q.watch();
  }

  /// Servis formunda gosterilecek aktif maddeler.
  Future<List<String>> activeLabels() async =>
      (await watchItems(includeInactive: false).first).map((e) => e.label).toList();

  Future<String> addItem(String label) async {
    final max = checklistTemplates.sortOrder.max();
    final row = await (selectOnly(checklistTemplates)
          ..addColumns([max])
          ..where(checklistTemplates.deletedAt.isNull()))
        .getSingle();
    final created = await into(checklistTemplates).insertReturning(
      ChecklistTemplatesCompanion.insert(label: label.trim(), sortOrder: (row.read(max) ?? -1) + 1),
    );
    return created.id;
  }

  Future<void> updateItem(String id, {String? label, bool? isActive}) =>
      (update(checklistTemplates)..where((t) => t.id.equals(id))).write(
        ChecklistTemplatesCompanion(
          label: label == null ? const Value.absent() : Value(label.trim()),
          isActive: isActive == null ? const Value.absent() : Value(isActive),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Verilen siraya gore sortOrder yazar.
  Future<void> reorder(List<String> orderedIds) => transaction(() async {
        for (var i = 0; i < orderedIds.length; i++) {
          await (update(checklistTemplates)..where((t) => t.id.equals(orderedIds[i])))
              .write(ChecklistTemplatesCompanion(sortOrder: Value(i), updatedAt: Value(DateTime.now())));
        }
      });

  Future<void> deleteItem(String id) =>
      (update(checklistTemplates)..where((t) => t.id.equals(id))).write(
        ChecklistTemplatesCompanion(deletedAt: Value(DateTime.now()), updatedAt: Value(DateTime.now())),
      );
}
