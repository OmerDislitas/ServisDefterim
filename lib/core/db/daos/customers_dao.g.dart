// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customers_dao.dart';

// ignore_for_file: type=lint
mixin _$CustomersDaoMixin on DatabaseAccessor<AppDatabase> {
  $CustomersTable get customers => attachedDatabase.customers;
  $AddressesTable get addresses => attachedDatabase.addresses;
  $DevicesTable get devices => attachedDatabase.devices;
  $AppointmentsTable get appointments => attachedDatabase.appointments;
  $ServiceRecordsTable get serviceRecords => attachedDatabase.serviceRecords;
  CustomersDaoManager get managers => CustomersDaoManager(this);
}

class CustomersDaoManager {
  final _$CustomersDaoMixin _db;
  CustomersDaoManager(this._db);
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
}
