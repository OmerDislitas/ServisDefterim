// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'services_dao.dart';

// ignore_for_file: type=lint
mixin _$ServicesDaoMixin on DatabaseAccessor<AppDatabase> {
  $CustomersTable get customers => attachedDatabase.customers;
  $AddressesTable get addresses => attachedDatabase.addresses;
  $DevicesTable get devices => attachedDatabase.devices;
  $AppointmentsTable get appointments => attachedDatabase.appointments;
  $ServiceRecordsTable get serviceRecords => attachedDatabase.serviceRecords;
  $ServicePartsTable get serviceParts => attachedDatabase.serviceParts;
  $PaymentsTable get payments => attachedDatabase.payments;
  ServicesDaoManager get managers => ServicesDaoManager(this);
}

class ServicesDaoManager {
  final _$ServicesDaoMixin _db;
  ServicesDaoManager(this._db);
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db.attachedDatabase, _db.customers);
  $$AddressesTableTableManager get addresses =>
      $$AddressesTableTableManager(_db.attachedDatabase, _db.addresses);
  $$DevicesTableTableManager get devices =>
      $$DevicesTableTableManager(_db.attachedDatabase, _db.devices);
  $$AppointmentsTableTableManager get appointments =>
      $$AppointmentsTableTableManager(_db.attachedDatabase, _db.appointments);
  $$ServiceRecordsTableTableManager get serviceRecords =>
      $$ServiceRecordsTableTableManager(
        _db.attachedDatabase,
        _db.serviceRecords,
      );
  $$ServicePartsTableTableManager get serviceParts =>
      $$ServicePartsTableTableManager(_db.attachedDatabase, _db.serviceParts);
  $$PaymentsTableTableManager get payments =>
      $$PaymentsTableTableManager(_db.attachedDatabase, _db.payments);
}
