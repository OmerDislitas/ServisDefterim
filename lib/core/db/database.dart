import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../services/app_paths.dart';
import '../strings.dart';
import 'daos/appointments_dao.dart';
import 'daos/checklist_dao.dart';
import 'daos/customers_dao.dart';
import 'daos/devices_dao.dart';
import 'daos/photos_dao.dart';
import 'daos/services_dao.dart';
import 'daos/settings_dao.dart';
import 'tables/tables.dart';

export 'tables/tables.dart' show newId;
export 'enums.dart';

part 'database.g.dart';

/// Soft delete edilebilen kayit turleri.
enum EntityKind { customer, address, device, service, appointment, payment }

class RecordCounts {
  const RecordCounts({
    required this.customers,
    required this.devices,
    required this.services,
    required this.appointments,
  });

  final int customers;
  final int devices;
  final int services;
  final int appointments;
}

@DriftDatabase(
  tables: [
    Customers,
    Addresses,
    Devices,
    ServiceRecords,
    ServiceParts,
    Payments,
    Appointments,
    Photos,
    ChecklistTemplates,
    AppSettings,
  ],
  daos: [CustomersDao, DevicesDao, ServicesDao, AppointmentsDao, ChecklistDao, SettingsDao, PhotosDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  static const fileName = 'servis_defterim';

  /// Dosya yolu acikca verilir; yedekleme/geri yukleme ayni dosyayla calisir.
  static QueryExecutor _openConnection() => driftDatabase(
        name: fileName,
        native: DriftNativeOptions(databasePath: () async => (await AppPaths.resolve()).dbFile),
      );

  bool _closed = false;
  StreamSubscription<Set<TableUpdate>>? _changeSub;

  /// Geri yuklemede baglanti elle kapatilir; provider'in ikinci kapatmasi zararsiz olmali.
  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _changeSub?.cancel();
    await super.close();
  }

  /// Is verisi her degistiginde `lastLocalChangeAt` yazilir (otomatik Drive yedegi icin, PLAN 8.4).
  /// Ayarlar tablosundaki degisiklikler (taslak vb.) sayilmaz.
  void startChangeTracking() {
    _changeSub ??= tableUpdates().listen((updates) {
      if (_closed || updates.every((u) => u.table == appSettings.actualTableName)) return;
      settingsDao.setValue(SettingKeys.lastLocalChangeAt, DateTime.now().toIso8601String());
    });
  }

  /// Ilk APK (M6) sonrasinda her sema degisikliginde artirilir ve migration yazilir.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seed();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _seed() async {
    await batch((b) {
      b.insertAll(checklistTemplates, [
        for (var i = 0; i < S.defaultChecklist.length; i++)
          ChecklistTemplatesCompanion.insert(label: S.defaultChecklist[i], sortOrder: i),
      ]);
      b.insertAll(appSettings, [
        for (final e in SettingKeys.defaults.entries)
          AppSettingsCompanion.insert(key: e.key, value: e.value),
      ]);
    });
  }

  // ---------------------------------------------------------------------------
  // Soft delete (PLAN 6.6)
  //
  // Bir kayit silinince bagli kayitlar ayni `deletedAt` zaman damgasiyla silinir.
  // Geri alma, sadece bu zaman damgasini tasiyan kayitlari geri getirir; daha
  // once ayrica silinmis kayitlar silinmis kalir.
  // ---------------------------------------------------------------------------

  /// Kaydi ve bagli kayitlari soft delete eder. Geri almak icin donen zamani sakla.
  Future<DateTime> softDelete(EntityKind kind, String id) async {
    final ts = DateTime.now();
    await _applyDeleted(kind, id, ts, restore: false);
    return ts;
  }

  /// [softDelete] islemini geri alir.
  Future<void> restore(EntityKind kind, String id, DateTime deletedAt) =>
      _applyDeleted(kind, id, deletedAt, restore: true);

  Future<void> _applyDeleted(EntityKind kind, String id, DateTime ts, {required bool restore}) {
    final byName = {for (final t in allTables) t.actualTableName: t};
    return transaction(() async {
      for (final (table, where) in _cascade(kind)) {
        final idVars = List.generate('?'.allMatches(where).length, (_) => Variable<String>(id));
        final sql = restore
            ? 'UPDATE $table SET deleted_at = NULL, updated_at = ? WHERE deleted_at = ? AND ($where)'
            : 'UPDATE $table SET deleted_at = ?, updated_at = ? WHERE deleted_at IS NULL AND ($where)';
        final vars = restore
            ? [Variable<DateTime>(DateTime.now()), Variable<DateTime>(ts)]
            : [Variable<DateTime>(ts), Variable<DateTime>(ts)];
        await customUpdate(
          sql,
          variables: [...vars, ...idVars],
          updates: {byName[table]!},
          updateKind: UpdateKind.update,
        );
      }
    });
  }

  /// (tablo, kosul) listesi. Kosuldaki her `?` silinen kaydin id'sidir.
  static List<(String, String)> _cascade(EntityKind kind) {
    String photos(String devices, String services) =>
        "(owner_type = 'device' AND owner_id IN ($devices)) OR "
        "(owner_type = 'service' AND owner_id IN ($services))";

    switch (kind) {
      case EntityKind.customer:
        const addr = 'SELECT id FROM addresses WHERE customer_id = ?';
        const dev = 'SELECT id FROM devices WHERE address_id IN ($addr)';
        const svc = 'SELECT id FROM service_records WHERE device_id IN ($dev)';
        return [
          ('customers', 'id = ?'),
          ('addresses', 'customer_id = ?'),
          ('devices', 'address_id IN ($addr)'),
          ('service_records', 'device_id IN ($dev)'),
          ('service_parts', 'service_id IN ($svc)'),
          ('payments', 'service_id IN ($svc)'),
          ('appointments', 'customer_id = ?'),
          ('photos', photos(dev, svc)),
        ];
      case EntityKind.address:
        const dev = 'SELECT id FROM devices WHERE address_id = ?';
        const svc = 'SELECT id FROM service_records WHERE device_id IN ($dev)';
        return [
          ('addresses', 'id = ?'),
          ('devices', 'address_id = ?'),
          ('service_records', 'device_id IN ($dev)'),
          ('service_parts', 'service_id IN ($svc)'),
          ('payments', 'service_id IN ($svc)'),
          ('photos', photos(dev, svc)),
        ];
      case EntityKind.device:
        const svc = 'SELECT id FROM service_records WHERE device_id = ?';
        return [
          ('devices', 'id = ?'),
          ('service_records', 'device_id = ?'),
          ('service_parts', 'service_id IN ($svc)'),
          ('payments', 'service_id IN ($svc)'),
          ('photos', photos('SELECT ?', svc)),
        ];
      case EntityKind.service:
        return [
          ('service_records', 'id = ?'),
          ('service_parts', 'service_id = ?'),
          ('payments', 'service_id = ?'),
          ('photos', "owner_type = 'service' AND owner_id = ?"),
        ];
      case EntityKind.appointment:
        return [('appointments', 'id = ?')];
      case EntityKind.payment:
        return [('payments', 'id = ?')];
    }
  }

  // ---------------------------------------------------------------------------
  // Debug araclari ve istatistik
  // ---------------------------------------------------------------------------

  /// Tum is verisini kalici olarak siler. Ayarlar ve checklist korunur. Sadece debug.
  Future<void> wipeAllData() => transaction(() async {
        for (final table in <TableInfo>[
          payments,
          serviceParts,
          photos,
          serviceRecords,
          appointments,
          devices,
          addresses,
          customers,
        ]) {
          await delete(table).go();
        }
      });

  Selectable<RecordCounts> _recordCounts() => customSelect(
        'SELECT '
        '(SELECT COUNT(*) FROM customers WHERE deleted_at IS NULL) AS customers, '
        '(SELECT COUNT(*) FROM devices WHERE deleted_at IS NULL) AS devices, '
        '(SELECT COUNT(*) FROM service_records WHERE deleted_at IS NULL) AS services, '
        '(SELECT COUNT(*) FROM appointments WHERE deleted_at IS NULL) AS appointments',
        readsFrom: {customers, devices, serviceRecords, appointments},
      ).map(
        (r) => RecordCounts(
          customers: r.read<int>('customers'),
          devices: r.read<int>('devices'),
          services: r.read<int>('services'),
          appointments: r.read<int>('appointments'),
        ),
      );

  Stream<RecordCounts> watchRecordCounts() => _recordCounts().watchSingle();

  Future<RecordCounts> recordCounts() => _recordCounts().getSingle();
}
