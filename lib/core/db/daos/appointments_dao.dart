import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/tables.dart';

part 'appointments_dao.g.dart';

class AppointmentListItem {
  const AppointmentListItem({
    required this.id,
    required this.scheduledAt,
    required this.type,
    required this.status,
    this.note,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.deviceId,
    this.deviceBrand,
    this.deviceModel,
    this.district,
    this.neighborhood,
  });

  final String id;
  final DateTime scheduledAt;
  final ServiceType type;
  final AppointmentStatus status;
  final String? note;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String? deviceId;
  final String? deviceBrand;
  final String? deviceModel;
  final String? district;
  final String? neighborhood;
}

@DriftAccessor(tables: [Appointments, Customers, Devices, Addresses])
class AppointmentsDao extends DatabaseAccessor<AppDatabase> with _$AppointmentsDaoMixin {
  AppointmentsDao(super.attachedDatabase);

  static String? _clean(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  Future<String> insertAppointment({
    required String customerId,
    String? deviceId,
    required DateTime scheduledAt,
    required ServiceType type,
    String? note,
  }) async {
    final row = await into(appointments).insertReturning(AppointmentsCompanion.insert(
      customerId: customerId,
      deviceId: Value(deviceId),
      scheduledAt: scheduledAt,
      type: type,
      status: AppointmentStatus.planned,
      note: Value(_clean(note)),
    ));
    return row.id;
  }

  Future<void> updateAppointment(
    String id, {
    required String customerId,
    String? deviceId,
    required DateTime scheduledAt,
    required ServiceType type,
    String? note,
  }) =>
      (update(appointments)..where((t) => t.id.equals(id))).write(AppointmentsCompanion(
        customerId: Value(customerId),
        deviceId: Value(deviceId),
        scheduledAt: Value(scheduledAt),
        type: Value(type),
        note: Value(_clean(note)),
        updatedAt: Value(DateTime.now()),
      ));

  Future<void> setStatus(String id, AppointmentStatus status) =>
      (update(appointments)..where((t) => t.id.equals(id))).write(
        AppointmentsCompanion(status: Value(status), updatedAt: Value(DateTime.now())),
      );

  Future<Appointment?> getAppointment(String id) =>
      (select(appointments)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();

  Stream<Appointment?> watchAppointment(String id) =>
      (select(appointments)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).watchSingleOrNull();

  /// Randevu listesi. Tarih araligi [from, to). Adres: cihazin adresi, yoksa musterinin ilk adresi.
  Stream<List<AppointmentListItem>> watchAppointments({
    DateTime? from,
    DateTime? to,
    String? customerId,
    AppointmentStatus? status,
  }) {
    final where = <String>['ap.deleted_at IS NULL', 'c.deleted_at IS NULL'];
    final vars = <Variable>[];
    if (from != null) {
      where.add('ap.scheduled_at >= ?');
      vars.add(Variable<DateTime>(from));
    }
    if (to != null) {
      where.add('ap.scheduled_at < ?');
      vars.add(Variable<DateTime>(to));
    }
    if (customerId != null) {
      where.add('ap.customer_id = ?');
      vars.add(Variable(customerId));
    }
    if (status != null) {
      where.add('ap.status = ?');
      vars.add(Variable(status.name));
    }

    return customSelect(
      '''
SELECT ap.id, ap.scheduled_at, ap.type, ap.status, ap.note, ap.customer_id, ap.device_id,
  c.name AS customer_name, c.phone AS customer_phone,
  d.brand AS device_brand, d.model AS device_model,
  CASE WHEN da.id IS NOT NULL THEN da.district ELSE fa.district END AS district,
  CASE WHEN da.id IS NOT NULL THEN da.neighborhood ELSE fa.neighborhood END AS neighborhood
FROM appointments ap
JOIN customers c ON c.id = ap.customer_id
LEFT JOIN devices d ON d.id = ap.device_id AND d.deleted_at IS NULL
LEFT JOIN addresses da ON da.id = d.address_id
LEFT JOIN addresses fa ON fa.id = (
  SELECT a.id FROM addresses a WHERE a.customer_id = c.id AND a.deleted_at IS NULL
  ORDER BY a.created_at, a.id LIMIT 1)
WHERE ${where.join(' AND ')}
ORDER BY ap.scheduled_at
''',
      variables: vars,
      readsFrom: {appointments, customers, devices, addresses},
    ).watch().map((rows) => [
          for (final r in rows)
            AppointmentListItem(
              id: r.read<String>('id'),
              scheduledAt: r.read<DateTime>('scheduled_at'),
              type: ServiceType.values.byName(r.read<String>('type')),
              status: AppointmentStatus.values.byName(r.read<String>('status')),
              note: r.readNullable<String>('note'),
              customerId: r.read<String>('customer_id'),
              customerName: r.read<String>('customer_name'),
              customerPhone: r.read<String>('customer_phone'),
              deviceId: r.readNullable<String>('device_id'),
              deviceBrand: r.readNullable<String>('device_brand'),
              deviceModel: r.readNullable<String>('device_model'),
              district: r.readNullable<String>('district'),
              neighborhood: r.readNullable<String>('neighborhood'),
            ),
        ]);
  }
}
