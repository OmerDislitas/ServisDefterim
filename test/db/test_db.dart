import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:servis_defterim/core/db/database.dart';

/// Testler icin bellek ici veritabani.
AppDatabase createTestDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

/// Musteri + adres + cihaz olusturur.
Future<({String customerId, String addressId, String deviceId})> createCustomerWithDevice(
  AppDatabase db, {
  String name = 'Ahmet Yılmaz',
  String phone = '0532 111 22 33',
  String brand = 'Demirdöküm',
  String? model = 'Nitromix',
  String? serialNo,
  String district = 'Başakşehir',
  DateTime? nextMaintenanceDate,
}) async {
  final customerId = await db.customersDao.insertCustomer(name: name, phone: phone);
  final addressId = await db.customersDao.insertAddress(
    customerId: customerId,
    district: district,
    neighborhood: 'Kayabaşı',
    addressLine: 'Gül Sk. No:5',
  );
  final deviceId = await db.devicesDao.insertDevice(
    addressId: addressId,
    brand: brand,
    model: model,
    serialNo: serialNo,
    type: DeviceType.condensing,
    maintenanceIntervalMonths: 12,
    nextMaintenanceDate: nextMaintenanceDate,
  );
  return (customerId: customerId, addressId: addressId, deviceId: deviceId);
}
