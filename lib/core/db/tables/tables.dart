// Drift tablo tanimlari (PLAN 5).
//
// Genel kurallar:
// - id: UUID v4 metin
// - createdAt / updatedAt / deletedAt (soft delete)
// - Para: tam sayi kurus
// - Sadece tarih alanlari: 'yyyy-MM-dd' metin (DateOnlyConverter)

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../converters.dart';
import '../enums.dart';

export '../converters.dart';
export '../enums.dart';

const _uuid = Uuid();

String newId() => _uuid.v4();

mixin BaseColumns on Table {
  TextColumn get id => text().clientDefault(newId)();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

@DataClassName('Customer')
@TableIndex(name: 'idx_customers_search', columns: {#searchText})
@TableIndex(name: 'idx_customers_phone', columns: {#phone})
class Customers extends Table with BaseColumns {
  TextColumn get name => text()();

  /// Sadece rakam, ulke kodu ve bastaki 0 olmadan (bkz. normalizePhone).
  TextColumn get phone => text()();
  TextColumn get phone2 => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get searchText => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Address')
@TableIndex(name: 'idx_addresses_customer', columns: {#customerId})
class Addresses extends Table with BaseColumns {
  TextColumn get customerId => text().references(Customers, #id)();
  TextColumn get label => text().nullable()();
  TextColumn get district => text().nullable()();
  TextColumn get neighborhood => text().nullable()();
  TextColumn get addressLine => text()();
  TextColumn get floor => text().nullable()();
  TextColumn get apartmentNo => text().nullable()();
  TextColumn get directions => text().nullable()();
  TextColumn get searchText => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Kombi. Musteriye degil adrese baglidir.
@DataClassName('Device')
@TableIndex(name: 'idx_devices_address', columns: {#addressId})
@TableIndex(name: 'idx_devices_serial', columns: {#serialNo})
@TableIndex(name: 'idx_devices_next_maintenance', columns: {#nextMaintenanceDate})
class Devices extends Table with BaseColumns {
  TextColumn get addressId => text().references(Addresses, #id)();
  TextColumn get brand => text()();
  TextColumn get model => text().nullable()();
  TextColumn get serialNo => text().nullable()();
  TextColumn get type => textEnum<DeviceType>()();
  IntColumn get installYear => integer().nullable()();
  TextColumn get warrantyEnd => text().map(const DateOnlyConverter()).nullable()();
  IntColumn get maintenanceIntervalMonths => integer().withDefault(const Constant(12))();
  TextColumn get nextMaintenanceDate => text().map(const DateOnlyConverter()).nullable()();
  DateTimeColumn get lastReminderSentAt => dateTime().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get searchText => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ServiceRecord')
@TableIndex(name: 'idx_services_device_date', columns: {#deviceId, #date})
@TableIndex(name: 'idx_services_appointment', columns: {#appointmentId})
@TableIndex(name: 'idx_services_date', columns: {#date})
class ServiceRecords extends Table with BaseColumns {
  TextColumn get deviceId => text().references(Devices, #id)();
  DateTimeColumn get date => dateTime()();
  TextColumn get type => textEnum<ServiceType>()();
  BoolColumn get isPeriodicMaintenance => boolean().withDefault(const Constant(false))();
  TextColumn get complaint => text().nullable()();
  TextColumn get errorCode => text().nullable()();
  TextColumn get workNotes => text().nullable()();

  /// Isaretlenen checklist maddelerinin metin kopyasi (JSON dizi).
  TextColumn get checklistItems =>
      text().withDefault(const Constant('[]')).map(const StringListConverter())();
  RealColumn get waterPressureBar => real().nullable()();
  RealColumn get expansionTankBar => real().nullable()();
  IntColumn get flueCoPpm => integer().nullable()();

  /// Kurus
  IntColumn get laborFee => integer().withDefault(const Constant(0))();

  /// Kurus
  IntColumn get totalAmount => integer().withDefault(const Constant(0))();
  TextColumn get appointmentId => text().nullable().references(Appointments, #id)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ServicePart')
@TableIndex(name: 'idx_parts_service', columns: {#serviceId})
class ServiceParts extends Table with BaseColumns {
  TextColumn get serviceId => text().references(ServiceRecords, #id)();
  TextColumn get name => text()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();

  /// Kurus
  IntColumn get unitPrice => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Payment')
@TableIndex(name: 'idx_payments_service', columns: {#serviceId})
class Payments extends Table with BaseColumns {
  TextColumn get serviceId => text().references(ServiceRecords, #id)();

  /// Kurus
  IntColumn get amount => integer()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Appointment')
@TableIndex(name: 'idx_appointments_scheduled', columns: {#scheduledAt})
@TableIndex(name: 'idx_appointments_customer', columns: {#customerId})
@TableIndex(name: 'idx_appointments_device', columns: {#deviceId})
class Appointments extends Table with BaseColumns {
  TextColumn get customerId => text().references(Customers, #id)();
  TextColumn get deviceId => text().nullable().references(Devices, #id)();
  DateTimeColumn get scheduledAt => dateTime()();
  TextColumn get type => textEnum<ServiceType>()();
  TextColumn get status => textEnum<AppointmentStatus>()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Photo')
@TableIndex(name: 'idx_photos_owner', columns: {#ownerType, #ownerId})
class Photos extends Table with BaseColumns {
  TextColumn get ownerType => textEnum<PhotoOwnerType>()();
  TextColumn get ownerId => text()();

  /// Uygulamanin photos/ klasorune gore goreli dosya adi.
  TextColumn get fileName => text()();
  TextColumn get thumbFileName => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ChecklistTemplate')
class ChecklistTemplates extends Table with BaseColumns {
  TextColumn get label => text()();
  IntColumn get sortOrder => integer()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Anahtar-deger ayarlar (bkz. SettingKeys).
@DataClassName('AppSetting')
class AppSettings extends Table {
  @override
  String get tableName => 'settings';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
