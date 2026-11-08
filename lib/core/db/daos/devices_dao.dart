import 'package:drift/drift.dart';

import '../../strings.dart';
import '../../utils/maintenance.dart';
import '../database.dart';
import '../search_text.dart';
import '../tables/tables.dart';

part 'devices_dao.g.dart';

/// Bakimi Gelenler satiri: cihaz + adres + musteri.
class DueDeviceItem {
  const DueDeviceItem({required this.device, required this.address, required this.customer});

  final Device device;
  final Address address;
  final Customer customer;
}

String? _clean(String? s) {
  final t = s?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

@DriftAccessor(tables: [Devices, Addresses, Customers])
class DevicesDao extends DatabaseAccessor<AppDatabase> with _$DevicesDaoMixin {
  DevicesDao(super.attachedDatabase);

  Future<String> insertDevice({
    required String addressId,
    required String brand,
    String? model,
    String? serialNo,
    required DeviceType type,
    int? installYear,
    DateTime? warrantyEnd,
    required int maintenanceIntervalMonths,
    DateTime? nextMaintenanceDate,
    String? note,
  }) async {
    final row = await into(devices).insertReturning(DevicesCompanion.insert(
      addressId: addressId,
      brand: brand.trim(),
      model: Value(_clean(model)),
      serialNo: Value(_clean(serialNo)),
      type: type,
      installYear: Value(installYear),
      warrantyEnd: Value(warrantyEnd),
      maintenanceIntervalMonths: Value(maintenanceIntervalMonths),
      nextMaintenanceDate: Value(nextMaintenanceDate),
      note: Value(_clean(note)),
      searchText: deviceSearchText(brand, model, serialNo),
    ));
    return row.id;
  }

  Future<void> updateDevice(
    String id, {
    required String brand,
    String? model,
    String? serialNo,
    required DeviceType type,
    int? installYear,
    DateTime? warrantyEnd,
    required int maintenanceIntervalMonths,
    DateTime? nextMaintenanceDate,
    String? note,
  }) =>
      (update(devices)..where((t) => t.id.equals(id))).write(DevicesCompanion(
        brand: Value(brand.trim()),
        model: Value(_clean(model)),
        serialNo: Value(_clean(serialNo)),
        type: Value(type),
        installYear: Value(installYear),
        warrantyEnd: Value(warrantyEnd),
        maintenanceIntervalMonths: Value(maintenanceIntervalMonths),
        nextMaintenanceDate: Value(nextMaintenanceDate),
        note: Value(_clean(note)),
        searchText: Value(deviceSearchText(brand, model, serialNo)),
        updatedAt: Value(DateTime.now()),
      ));

  Future<void> setNextMaintenanceDate(String id, DateTime? date) =>
      (update(devices)..where((t) => t.id.equals(id))).write(
        DevicesCompanion(nextMaintenanceDate: Value(date), updatedAt: Value(DateTime.now())),
      );

  /// WhatsApp hatirlatmasi gonderildi (PLAN 6.5).
  Future<void> markReminderSent(String id, {DateTime? at}) =>
      (update(devices)..where((t) => t.id.equals(id))).write(
        DevicesCompanion(lastReminderSentAt: Value(at ?? DateTime.now()), updatedAt: Value(DateTime.now())),
      );

  Stream<Device?> watchDevice(String id) =>
      (select(devices)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).watchSingleOrNull();

  Future<Device?> getDevice(String id) =>
      (select(devices)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();

  SimpleSelectStatement<$DevicesTable, Device> _devicesAt(String addressId) => select(devices)
    ..where((t) => t.addressId.equals(addressId) & t.deletedAt.isNull())
    ..orderBy([(t) => OrderingTerm.asc(t.createdAt), (t) => OrderingTerm.asc(t.id)]);

  Stream<List<Device>> watchDevicesForAddress(String addressId) => _devicesAt(addressId).watch();

  Future<List<Device>> getDevicesForAddress(String addressId) => _devicesAt(addressId).get();

  /// Bir musterinin tum adreslerindeki cihazlar.
  Stream<List<Device>> watchDevicesForCustomer(String customerId) {
    final q = select(devices).join([innerJoin(addresses, addresses.id.equalsExp(devices.addressId))])
      ..where(addresses.customerId.equals(customerId) &
          addresses.deletedAt.isNull() &
          devices.deletedAt.isNull())
      ..orderBy([OrderingTerm.asc(devices.createdAt)]);
    return q.watch().map((rows) => rows.map((r) => r.readTable(devices)).toList());
  }

  /// Bakimi Gelenler (PLAN 7.1). Tarih araligi iki uc dahil.
  Stream<List<DueDeviceItem>> watchDueDevices(DueFilter filter, {DateTime? now}) {
    final range = dueRange(filter, now ?? DateTime.now());
    return watchDueDevicesInRange(from: range.from, to: range.to, unknownOnly: filter == DueFilter.unknown);
  }

  /// Sonraki bakim tarihi [from, to] araligindaki kombiler ('yyyy-MM-dd', iki uc dahil).
  Stream<List<DueDeviceItem>> watchDueDevicesInRange({String? from, String? to, bool unknownOnly = false}) =>
      _dueQuery(from: from, to: to, unknownOnly: unknownOnly).watch();

  /// [watchDueDevicesInRange]'in tek seferlik okumasi (bildirim planlama).
  Future<List<DueDeviceItem>> getDueDevicesInRange({String? from, String? to}) =>
      _dueQuery(from: from, to: to).get();

  Selectable<DueDeviceItem> _dueQuery({String? from, String? to, bool unknownOnly = false}) {
    final range = (from: from, to: to);
    final q = select(devices).join([
      innerJoin(addresses, addresses.id.equalsExp(devices.addressId)),
      innerJoin(customers, customers.id.equalsExp(addresses.customerId)),
    ])
      ..where(devices.deletedAt.isNull() & addresses.deletedAt.isNull() & customers.deletedAt.isNull());

    if (unknownOnly) {
      q.where(devices.nextMaintenanceDate.isNull());
      q.orderBy([OrderingTerm.asc(customers.searchText)]);
    } else {
      q.where(devices.nextMaintenanceDate.isNotNull());
      if (range.from != null) q.where(devices.nextMaintenanceDate.isBiggerOrEqualValue(range.from!));
      if (range.to != null) q.where(devices.nextMaintenanceDate.isSmallerOrEqualValue(range.to!));
      q.orderBy([OrderingTerm.asc(devices.nextMaintenanceDate), OrderingTerm.asc(customers.searchText)]);
    }

    return q.map((r) => DueDeviceItem(
          device: r.readTable(devices),
          address: r.readTable(addresses),
          customer: r.readTable(customers),
        ));
  }

  /// Marka onerileri: seed listesi + daha once girilen markalar.
  Future<List<String>> brandSuggestions() async {
    final rows = await (selectOnly(devices, distinct: true)
          ..addColumns([devices.brand])
          ..where(devices.deletedAt.isNull()))
        .map((r) => r.read(devices.brand)!)
        .get();
    final all = <String>{...S.brandSuggestions};
    for (final b in rows) {
      if (!all.any((e) => e.toLowerCase() == b.toLowerCase())) all.add(b);
    }
    return all.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }
}
