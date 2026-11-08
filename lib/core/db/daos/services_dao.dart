import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/tables.dart';

part 'services_dao.g.dart';

class PartInput {
  const PartInput({required this.name, this.quantity = 1, this.unitPrice = 0});

  final String name;
  final int quantity;

  /// Kurus
  final int unitPrice;

  int get lineTotal => quantity * unitPrice;
}

/// Yeni servis kaydi icin girdi (PLAN 7.6).
class ServiceInput {
  const ServiceInput({
    required this.deviceId,
    required this.date,
    required this.type,
    this.isPeriodicMaintenance = false,
    this.complaint,
    this.errorCode,
    this.workNotes,
    this.checklistItems = const [],
    this.waterPressureBar,
    this.expansionTankBar,
    this.flueCoPpm,
    this.laborFee = 0,
    required this.totalAmount,
    this.appointmentId,
    this.parts = const [],
    this.initialPayment = 0,
    this.nextMaintenanceDate = const Value.absent(),
  });

  final String deviceId;
  final DateTime date;
  final ServiceType type;
  final bool isPeriodicMaintenance;
  final String? complaint;
  final String? errorCode;
  final String? workNotes;
  final List<String> checklistItems;
  final double? waterPressureBar;
  final double? expansionTankBar;
  final int? flueCoPpm;
  final int laborFee;
  final int totalAmount;
  final String? appointmentId;
  final List<PartInput> parts;

  /// Kayit aninda alinan odeme (kurus). 0 ise veresiye.
  final int initialPayment;

  /// Mevcutsa cihazin sonraki bakim tarihi bu degerle guncellenir.
  final Value<DateTime?> nextMaintenanceDate;
}

/// Servis listesi satiri (gecmis, son servisler, takvim).
class ServiceListItem {
  const ServiceListItem({
    required this.id,
    required this.date,
    required this.type,
    required this.totalAmount,
    required this.paidAmount,
    required this.deviceId,
    required this.deviceBrand,
    this.deviceModel,
    required this.customerId,
    required this.customerName,
    this.district,
    this.neighborhood,
  });

  final String id;
  final DateTime date;
  final ServiceType type;
  final int totalAmount;
  final int paidAmount;
  final String deviceId;
  final String deviceBrand;
  final String? deviceModel;
  final String customerId;
  final String customerName;
  final String? district;
  final String? neighborhood;

  int get remaining => totalAmount - paidAmount;
}

/// Alacaklar: musteri bazinda toplam borc.
class ReceivableCustomer {
  const ReceivableCustomer({
    required this.customerId,
    required this.name,
    required this.phone,
    required this.debt,
    required this.oldestDebtAt,
    required this.serviceCount,
  });

  final String customerId;
  final String name;
  final String phone;
  final int debt;
  final DateTime oldestDebtAt;
  final int serviceCount;
}

@DriftAccessor(tables: [ServiceRecords, ServiceParts, Payments, Devices, Addresses, Customers, Appointments])
class ServicesDao extends DatabaseAccessor<AppDatabase> with _$ServicesDaoMixin {
  ServicesDao(super.attachedDatabase);

  static String? _clean(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  /// Servis, parcalar, ilk odeme, sonraki bakim ve randevu durumu tek transaction'da.
  Future<String> insertService(ServiceInput input) => transaction(() async {
        final id = newId();
        await into(serviceRecords).insert(ServiceRecordsCompanion.insert(
          id: Value(id),
          deviceId: input.deviceId,
          date: input.date,
          type: input.type,
          isPeriodicMaintenance: Value(input.isPeriodicMaintenance),
          complaint: Value(_clean(input.complaint)),
          errorCode: Value(_clean(input.errorCode)),
          workNotes: Value(_clean(input.workNotes)),
          checklistItems: Value(input.checklistItems),
          waterPressureBar: Value(input.waterPressureBar),
          expansionTankBar: Value(input.expansionTankBar),
          flueCoPpm: Value(input.flueCoPpm),
          laborFee: Value(input.laborFee),
          totalAmount: Value(input.totalAmount),
          appointmentId: Value(input.appointmentId),
        ));

        if (input.parts.isNotEmpty) {
          await batch((b) => b.insertAll(serviceParts, [
                for (final p in input.parts)
                  ServicePartsCompanion.insert(
                    serviceId: id,
                    name: p.name.trim(),
                    quantity: Value(p.quantity),
                    unitPrice: Value(p.unitPrice),
                  ),
              ]));
        }

        if (input.initialPayment > 0) {
          await into(payments).insert(
            PaymentsCompanion.insert(serviceId: id, amount: input.initialPayment, date: input.date),
          );
        }

        if (input.nextMaintenanceDate.present) {
          await (update(devices)..where((t) => t.id.equals(input.deviceId))).write(DevicesCompanion(
            nextMaintenanceDate: input.nextMaintenanceDate,
            updatedAt: Value(DateTime.now()),
          ));
        }

        if (input.appointmentId != null) {
          await (update(appointments)..where((t) => t.id.equals(input.appointmentId!))).write(
            AppointmentsCompanion(status: const Value(AppointmentStatus.done), updatedAt: Value(DateTime.now())),
          );
        }
        return id;
      });

  /// Servisi gunceller; parcalar yenileriyle degistirilir (eskiler soft delete).
  /// Odemeler burada degismez (detay ekraninda yonetilir).
  Future<void> updateService(String id, ServiceInput input) => transaction(() async {
        final now = DateTime.now();
        await (update(serviceRecords)..where((t) => t.id.equals(id))).write(ServiceRecordsCompanion(
          deviceId: Value(input.deviceId),
          date: Value(input.date),
          type: Value(input.type),
          isPeriodicMaintenance: Value(input.isPeriodicMaintenance),
          complaint: Value(_clean(input.complaint)),
          errorCode: Value(_clean(input.errorCode)),
          workNotes: Value(_clean(input.workNotes)),
          checklistItems: Value(input.checklistItems),
          waterPressureBar: Value(input.waterPressureBar),
          expansionTankBar: Value(input.expansionTankBar),
          flueCoPpm: Value(input.flueCoPpm),
          laborFee: Value(input.laborFee),
          totalAmount: Value(input.totalAmount),
          updatedAt: Value(now),
        ));
        await (update(serviceParts)..where((t) => t.serviceId.equals(id) & t.deletedAt.isNull()))
            .write(ServicePartsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
        if (input.parts.isNotEmpty) {
          await batch((b) => b.insertAll(serviceParts, [
                for (final p in input.parts)
                  ServicePartsCompanion.insert(
                    serviceId: id,
                    name: p.name.trim(),
                    quantity: Value(p.quantity),
                    unitPrice: Value(p.unitPrice),
                  ),
              ]));
        }
        if (input.nextMaintenanceDate.present) {
          await (update(devices)..where((t) => t.id.equals(input.deviceId))).write(
            DevicesCompanion(nextMaintenanceDate: input.nextMaintenanceDate, updatedAt: Value(now)),
          );
        }
      });

  Future<ServiceRecord?> getService(String id) =>
      (select(serviceRecords)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();

  Future<List<ServicePart>> getParts(String serviceId) => (select(serviceParts)
        ..where((t) => t.serviceId.equals(serviceId) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
      .get();

  /// Kombinin en son periyodik bakim tarihi ([excludeId] haric). Silme/duzenleme sonrasi
  /// sonraki bakim tarihini onermek icin (PLAN 6.1).
  Future<DateTime?> latestPeriodicServiceDate(String deviceId, {String? excludeId}) async {
    final q = select(serviceRecords)
      ..where((t) => t.deviceId.equals(deviceId) & t.deletedAt.isNull() & t.isPeriodicMaintenance.equals(true))
      ..orderBy([(t) => OrderingTerm.desc(t.date)])
      ..limit(1);
    if (excludeId != null) q.where((t) => t.id.equals(excludeId).not());
    return (await q.getSingleOrNull())?.date;
  }

  /// Randevudan baslatilan servis (varsa).
  Stream<ServiceRecord?> watchServiceForAppointment(String appointmentId) => (select(serviceRecords)
        ..where((t) => t.appointmentId.equals(appointmentId) & t.deletedAt.isNull())
        ..limit(1))
      .watchSingleOrNull();

  Stream<ServiceRecord?> watchService(String id) =>
      (select(serviceRecords)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).watchSingleOrNull();

  Stream<List<ServicePart>> watchParts(String serviceId) => (select(serviceParts)
        ..where((t) => t.serviceId.equals(serviceId) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
      .watch();

  // --- Odemeler ------------------------------------------------------------

  Future<String> addPayment({
    required String serviceId,
    required int amount,
    required DateTime date,
    String? note,
  }) async {
    final row = await into(payments).insertReturning(
      PaymentsCompanion.insert(serviceId: serviceId, amount: amount, date: date, note: Value(_clean(note))),
    );
    return row.id;
  }

  Stream<List<Payment>> watchPayments(String serviceId) => (select(payments)
        ..where((t) => t.serviceId.equals(serviceId) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.date)]))
      .watch();

  // --- Listeler ------------------------------------------------------------

  /// Servis listesi. Filtreler istege bagli; tarih araligi [from, to).
  Stream<List<ServiceListItem>> watchServiceList({
    String? customerId,
    String? deviceId,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) {
    final where = <String>['s.deleted_at IS NULL'];
    final vars = <Variable>[];
    if (customerId != null) {
      where.add('c.id = ?');
      vars.add(Variable(customerId));
    }
    if (deviceId != null) {
      where.add('s.device_id = ?');
      vars.add(Variable(deviceId));
    }
    if (from != null) {
      where.add('s.date >= ?');
      vars.add(Variable<DateTime>(from));
    }
    if (to != null) {
      where.add('s.date < ?');
      vars.add(Variable<DateTime>(to));
    }
    var limitSql = '';
    if (limit != null) {
      limitSql = 'LIMIT ?';
      vars.add(Variable(limit));
    }

    return customSelect(
      '''
SELECT s.id, s.date, s.type, s.total_amount, s.device_id,
  d.brand, d.model, c.id AS customer_id, c.name AS customer_name, a.district, a.neighborhood,
  COALESCE((SELECT SUM(p.amount) FROM payments p WHERE p.service_id = s.id AND p.deleted_at IS NULL), 0) AS paid
FROM service_records s
JOIN devices d ON d.id = s.device_id
JOIN addresses a ON a.id = d.address_id
JOIN customers c ON c.id = a.customer_id
WHERE ${where.join(' AND ')}
ORDER BY s.date DESC
$limitSql
''',
      variables: vars,
      readsFrom: {serviceRecords, devices, addresses, customers, payments},
    ).watch().map((rows) => [
          for (final r in rows)
            ServiceListItem(
              id: r.read<String>('id'),
              date: r.read<DateTime>('date'),
              type: ServiceType.values.byName(r.read<String>('type')),
              totalAmount: r.read<int>('total_amount'),
              paidAmount: r.read<int>('paid'),
              deviceId: r.read<String>('device_id'),
              deviceBrand: r.read<String>('brand'),
              deviceModel: r.readNullable<String>('model'),
              customerId: r.read<String>('customer_id'),
              customerName: r.read<String>('customer_name'),
              district: r.readNullable<String>('district'),
              neighborhood: r.readNullable<String>('neighborhood'),
            ),
        ]);
  }

  // --- Alacaklar (PLAN 7.9) ------------------------------------------------

  static const _paidJoin =
      'LEFT JOIN (SELECT service_id, SUM(amount) AS paid FROM payments '
      'WHERE deleted_at IS NULL GROUP BY service_id) p ON p.service_id = s.id';

  static const _serviceJoins = '''
FROM service_records s
JOIN devices d ON d.id = s.device_id
JOIN addresses a ON a.id = d.address_id
JOIN customers c ON c.id = a.customer_id
''';

  /// Borcu olan musteriler, en yuksek borc once.
  Stream<List<ReceivableCustomer>> watchReceivables() => customSelect(
        '''
SELECT c.id, c.name, c.phone,
  SUM(s.total_amount - COALESCE(p.paid, 0)) AS debt,
  MIN(s.date) AS oldest_at,
  COUNT(*) AS service_count
$_serviceJoins
$_paidJoin
WHERE s.deleted_at IS NULL AND c.deleted_at IS NULL AND s.total_amount > COALESCE(p.paid, 0)
GROUP BY c.id
ORDER BY debt DESC
''',
        readsFrom: {serviceRecords, devices, addresses, customers, payments},
      ).watch().map((rows) => [
            for (final r in rows)
              ReceivableCustomer(
                customerId: r.read<String>('id'),
                name: r.read<String>('name'),
                phone: r.read<String>('phone'),
                debt: r.read<int>('debt'),
                oldestDebtAt: r.read<DateTime>('oldest_at'),
                serviceCount: r.read<int>('service_count'),
              ),
          ]);

  /// Bir musterinin borclu servisleri, en eski once.
  Stream<List<ServiceListItem>> watchDebtServices(String customerId) => customSelect(
        '''
SELECT s.id, s.date, s.type, s.total_amount, s.device_id, d.brand, d.model,
  c.id AS customer_id, c.name AS customer_name, a.district, a.neighborhood,
  COALESCE(p.paid, 0) AS paid
$_serviceJoins
$_paidJoin
WHERE s.deleted_at IS NULL AND c.id = ? AND s.total_amount > COALESCE(p.paid, 0)
ORDER BY s.date
''',
        variables: [Variable(customerId)],
        readsFrom: {serviceRecords, devices, addresses, customers, payments},
      ).watch().map((rows) => [
            for (final r in rows)
              ServiceListItem(
                id: r.read<String>('id'),
                date: r.read<DateTime>('date'),
                type: ServiceType.values.byName(r.read<String>('type')),
                totalAmount: r.read<int>('total_amount'),
                paidAmount: r.read<int>('paid'),
                deviceId: r.read<String>('device_id'),
                deviceBrand: r.read<String>('brand'),
                deviceModel: r.readNullable<String>('model'),
                customerId: r.read<String>('customer_id'),
                customerName: r.read<String>('customer_name'),
                district: r.readNullable<String>('district'),
                neighborhood: r.readNullable<String>('neighborhood'),
              ),
          ]);

  /// Toplam alacak (kurus).
  Stream<int> watchTotalReceivable() => customSelect(
        '''
SELECT COALESCE(SUM(s.total_amount - COALESCE(p.paid, 0)), 0) AS total
$_serviceJoins
$_paidJoin
WHERE s.deleted_at IS NULL AND c.deleted_at IS NULL AND s.total_amount > COALESCE(p.paid, 0)
''',
        readsFrom: {serviceRecords, devices, addresses, customers, payments},
      ).watchSingle().map((r) => r.read<int>('total'));

  /// Daha once girilen parca adlari (otomatik tamamlama).
  Future<List<String>> partNameSuggestions() => (selectOnly(serviceParts, distinct: true)
        ..addColumns([serviceParts.name])
        ..where(serviceParts.deletedAt.isNull())
        ..orderBy([OrderingTerm.asc(serviceParts.name)]))
      .map((r) => r.read(serviceParts.name)!)
      .get();
}
