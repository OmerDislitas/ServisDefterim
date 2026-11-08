// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appointments_dao.dart';

// ignore_for_file: type=lint
mixin _$AppointmentsDaoMixin on DatabaseAccessor<AppDatabase> {
  $CustomersTable get customers => attachedDatabase.customers;
  $AddressesTable get addresses => attachedDatabase.addresses;
  $DevicesTable get devices => attachedDatabase.devices;
  $AppointmentsTable get appointments => attachedDatabase.appointments;
  AppointmentsDaoManager get managers => AppointmentsDaoManager(this);
}

class AppointmentsDaoManager {
  final _$AppointmentsDaoMixin _db;
  AppointmentsDaoManager(this._db);
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db.attachedDatabase, _db.customers);
  $$AddressesTableTableManager get addresses =>
      $$AddressesTableTableManager(_db.attachedDatabase, _db.addresses);
  $$DevicesTableTableManager get devices =>
      $$DevicesTableTableManager(_db.attachedDatabase, _db.devices);
  $$AppointmentsTableTableManager get appointments =>
      $$AppointmentsTableTableManager(_db.attachedDatabase, _db.appointments);
}
