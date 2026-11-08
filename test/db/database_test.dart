import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:servis_defterim/core/db/daos/customers_dao.dart';
import 'package:servis_defterim/core/db/daos/services_dao.dart';
import 'package:servis_defterim/core/db/daos/settings_dao.dart';
import 'package:servis_defterim/core/db/database.dart';
import 'package:servis_defterim/core/db/sample_data.dart';
import 'package:servis_defterim/core/strings.dart';
import 'package:servis_defterim/core/utils/maintenance.dart';

import 'test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDb());
  tearDown(() => db.close());

  group('Seed', () {
    test('varsayılan checklist ve ayarlar yazılır', () async {
      final items = await db.checklistDao.watchItems().first;
      expect(items.map((e) => e.label), S.defaultChecklist);
      expect(await db.settingsDao.getInt(SettingKeys.defaultIntervalMonths), 12);
      expect(await db.settingsDao.getInt(SettingKeys.notificationHour), 9);
      expect(await db.settingsDao.getInt(SettingKeys.remindDaysBefore), 3);
      expect(await db.settingsDao.getValue(SettingKeys.whatsappTemplate), S.defaultWhatsappTemplate);
      expect(await db.settingsDao.getBool(SettingKeys.driveAutoBackup), isFalse);
    });

    test('ayar yazma ve silme', () async {
      await db.settingsDao.setInt(SettingKeys.defaultIntervalMonths, 6);
      expect(await db.settingsDao.getInt(SettingKeys.defaultIntervalMonths), 6);
      await db.settingsDao.setValue(SettingKeys.driveAccountEmail, 'a@b.com');
      expect(await db.settingsDao.getValue(SettingKeys.driveAccountEmail), 'a@b.com');
      await db.settingsDao.setValue(SettingKeys.driveAccountEmail, null);
      expect(await db.settingsDao.getValue(SettingKeys.driveAccountEmail), isNull);
    });

    test('checklist ekle, pasifleştir, sırala, sil', () async {
      final id = await db.checklistDao.addItem('Kart kontrolü');
      var items = await db.checklistDao.watchItems().first;
      expect(items.last.label, 'Kart kontrolü');
      expect(items.last.sortOrder, S.defaultChecklist.length);

      await db.checklistDao.updateItem(items.first.id, isActive: false);
      final active = await db.checklistDao.activeLabels();
      expect(active, isNot(contains(S.defaultChecklist.first)));
      expect(active.length, S.defaultChecklist.length);

      await db.checklistDao.reorder([id, ...items.where((e) => e.id != id).map((e) => e.id)]);
      items = await db.checklistDao.watchItems().first;
      expect(items.first.id, id);

      await db.checklistDao.deleteItem(id);
      items = await db.checklistDao.watchItems().first;
      expect(items.any((e) => e.id == id), isFalse);
    });
  });

  group('Müşteri / adres / cihaz', () {
    test('ekleme ve güncelleme, telefon normalize edilir', () async {
      final ids = await createCustomerWithDevice(db, phone: '+90 532 111 22 33');
      final c = await db.customersDao.getCustomer(ids.customerId);
      expect(c!.phone, '5321112233');
      expect(c.searchText, 'ahmet yilmaz 5321112233');

      await db.customersDao.updateCustomer(ids.customerId, name: 'Şükrü Öztürk', phone: '0533 000 00 00');
      final u = await db.customersDao.getCustomer(ids.customerId);
      expect(u!.name, 'Şükrü Öztürk');
      expect(u.searchText, 'sukru ozturk 5330000000');
      expect(u.updatedAt.isBefore(u.createdAt), isFalse);

      expect((await db.customersDao.findByPhone('05330000000')).single.id, ids.customerId);
      expect(await db.customersDao.findByPhone('0599 999 99 99'), isEmpty);
    });

    test('müşteri listesi: adres, cihaz sayısı, son servis', () async {
      final a = await createCustomerWithDevice(db, name: 'Ahmet Yılmaz');
      await db.devicesDao.insertDevice(
        addressId: a.addressId,
        brand: 'Bosch',
        type: DeviceType.hermetic,
        maintenanceIntervalMonths: 12,
      );
      await createCustomerWithDevice(db, name: 'Zeynep Kaya', phone: '05320000000');
      await db.servicesDao.insertService(ServiceInput(
        deviceId: a.deviceId,
        date: DateTime(2026, 10, 1, 14),
        type: ServiceType.repair,
        totalAmount: 100000,
      ));

      final list = await db.customersDao.watchCustomerList().first;
      expect(list.map((e) => e.name), ['Ahmet Yılmaz', 'Zeynep Kaya']);
      expect(list.first.deviceCount, 2);
      expect(list.first.district, 'Başakşehir');
      expect(list.first.neighborhood, 'Kayabaşı');
      expect(list.first.lastServiceAt, DateTime(2026, 10, 1, 14));
      expect(list.last.lastServiceAt, isNull);

      final byName = await db.customersDao.watchCustomerList(sort: CustomerSort.name).first;
      expect(byName.map((e) => e.name), ['Ahmet Yılmaz', 'Zeynep Kaya']);
    });

    test('arama: ad, telefon, adres, cihaz', () async {
      await createCustomerWithDevice(db, name: 'Şükrü Öztürk', phone: '0532 111 22 33', serialNo: 'SN998877');
      await createCustomerWithDevice(
        db,
        name: 'Mehmet Demir',
        phone: '0544 555 66 77',
        brand: 'Vaillant',
        model: 'ecoTEC',
        district: 'Esenyurt',
      );

      Future<List<String>> search(String q) async =>
          (await db.customersDao.watchCustomerList(query: q).first).map((e) => e.name).toList();

      expect(await search('sukru'), ['Şükrü Öztürk']);
      expect(await search('ŞÜKRÜ'), ['Şükrü Öztürk']);
      expect(await search('ozt'), ['Şükrü Öztürk']);
      expect(await search('0532 111'), ['Şükrü Öztürk']);
      expect(await search('5445'), ['Mehmet Demir']);
      expect(await search('esenyurt'), ['Mehmet Demir']);
      expect(await search('ecotec'), ['Mehmet Demir']);
      expect(await search('998877'), ['Şükrü Öztürk']);
      expect(await search('demirdokum'), ['Şükrü Öztürk']);
      expect(await search('kayabasi'), hasLength(2));
      expect(await search('yok böyle'), isEmpty);
      expect(await search('%'), isEmpty);
      expect(await search(''), hasLength(2));
    });

    test('marka önerileri seed listesini ve girilen markaları içerir', () async {
      await createCustomerWithDevice(db, brand: 'Termoteknik');
      final brands = await db.devicesDao.brandSuggestions();
      expect(brands, containsAll(['Demirdöküm', 'Vaillant', 'Termoteknik']));
      expect(brands.where((b) => b == 'Demirdöküm'), hasLength(1));
    });
  });

  group('Soft delete', () {
    test('müşteri silinince bağlı kayıtlar silinir, geri al hepsini getirir', () async {
      final a = await createCustomerWithDevice(db);
      final b = await createCustomerWithDevice(db, name: 'Diğer Müşteri', phone: '05001112233');
      final serviceId = await db.servicesDao.insertService(ServiceInput(
        deviceId: a.deviceId,
        date: DateTime(2026, 10, 1),
        type: ServiceType.repair,
        totalAmount: 50000,
        initialPayment: 20000,
        parts: const [PartInput(name: 'Pompa', unitPrice: 30000)],
      ));
      await db.appointmentsDao.insertAppointment(
        customerId: a.customerId,
        scheduledAt: DateTime(2026, 12, 1, 10),
        type: ServiceType.maintenance,
      );

      final ts = await db.softDelete(EntityKind.customer, a.customerId);

      expect(await db.customersDao.getCustomer(a.customerId), isNull);
      expect(await db.customersDao.watchAddresses(a.customerId).first, isEmpty);
      expect(await db.devicesDao.getDevice(a.deviceId), isNull);
      expect(await db.servicesDao.watchService(serviceId).first, isNull);
      expect(await db.servicesDao.watchParts(serviceId).first, isEmpty);
      expect(await db.servicesDao.watchPayments(serviceId).first, isEmpty);
      expect(await db.appointmentsDao.watchAppointments().first, isEmpty);
      expect(await db.servicesDao.watchReceivables().first, isEmpty);
      // Diger musteri etkilenmez
      expect(await db.customersDao.getCustomer(b.customerId), isNotNull);
      expect(await db.devicesDao.getDevice(b.deviceId), isNotNull);

      await db.restore(EntityKind.customer, a.customerId, ts);

      expect(await db.customersDao.getCustomer(a.customerId), isNotNull);
      expect(await db.devicesDao.getDevice(a.deviceId), isNotNull);
      expect(await db.servicesDao.watchParts(serviceId).first, hasLength(1));
      expect(await db.servicesDao.watchPayments(serviceId).first, hasLength(1));
      expect(await db.appointmentsDao.watchAppointments().first, hasLength(1));
    });

    test('geri al daha önce ayrıca silinmiş kayıtları geri getirmez', () async {
      final a = await createCustomerWithDevice(db);
      final s1 = await db.servicesDao.insertService(ServiceInput(
        deviceId: a.deviceId,
        date: DateTime(2026, 9, 1),
        type: ServiceType.repair,
        totalAmount: 1000,
      ));
      final s2 = await db.servicesDao.insertService(ServiceInput(
        deviceId: a.deviceId,
        date: DateTime(2026, 10, 1),
        type: ServiceType.repair,
        totalAmount: 1000,
      ));
      await db.softDelete(EntityKind.service, s1);
      // Ayni saniyeye dusmemesi icin (zaman damgasi saniye hassasiyetinde)
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final ts = await db.softDelete(EntityKind.device, a.deviceId);
      await db.restore(EntityKind.device, a.deviceId, ts);

      expect(await db.servicesDao.watchService(s1).first, isNull);
      expect(await db.servicesDao.watchService(s2).first, isNotNull);
    });
  });

  group('Servis ve bakım', () {
    test('periyodik bakım cihazın sonraki bakım tarihini günceller, randevuyu kapatır', () async {
      final a = await createCustomerWithDevice(db);
      final apptId = await db.appointmentsDao.insertAppointment(
        customerId: a.customerId,
        deviceId: a.deviceId,
        scheduledAt: DateTime(2026, 11, 8, 10),
        type: ServiceType.maintenance,
      );
      final date = DateTime(2026, 11, 8, 10, 30);
      final id = await db.servicesDao.insertService(ServiceInput(
        deviceId: a.deviceId,
        date: date,
        type: ServiceType.maintenance,
        isPeriodicMaintenance: true,
        checklistItems: const ['Gaz kaçak kontrolü', 'Brülör temizliği'],
        laborFee: 100000,
        totalAmount: 100000,
        initialPayment: 100000,
        appointmentId: apptId,
        nextMaintenanceDate: Value(computeNextMaintenance(date, 12)),
      ));

      final device = await db.devicesDao.getDevice(a.deviceId);
      expect(device!.nextMaintenanceDate, DateTime(2027, 11, 8));
      final service = await db.servicesDao.watchService(id).first;
      expect(service!.checklistItems, ['Gaz kaçak kontrolü', 'Brülör temizliği']);
      final appt = await db.appointmentsDao.watchAppointment(apptId).first;
      expect(appt!.status, AppointmentStatus.done);
    });

    test('servis listesi filtreleri ve ödenen tutar', () async {
      final a = await createCustomerWithDevice(db);
      final b = await createCustomerWithDevice(db, name: 'Zeynep', phone: '05001112233');
      for (final (dev, day, paid) in [(a.deviceId, 1, 0), (a.deviceId, 5, 30000), (b.deviceId, 3, 50000)]) {
        await db.servicesDao.insertService(ServiceInput(
          deviceId: dev,
          date: DateTime(2026, 11, day, 12),
          type: ServiceType.repair,
          totalAmount: 50000,
          initialPayment: paid,
        ));
      }

      final all = await db.servicesDao.watchServiceList().first;
      expect(all.map((e) => e.date.day), [5, 3, 1]);
      expect(all.first.paidAmount, 30000);
      expect(all.first.remaining, 20000);
      expect(all.first.customerName, 'Ahmet Yılmaz');
      expect(all.first.deviceBrand, 'Demirdöküm');

      expect(await db.servicesDao.watchServiceList(customerId: a.customerId).first, hasLength(2));
      expect(await db.servicesDao.watchServiceList(deviceId: b.deviceId).first, hasLength(1));
      expect(await db.servicesDao.watchServiceList(limit: 1).first, hasLength(1));
      final day3 = await db.servicesDao
          .watchServiceList(from: DateTime(2026, 11, 3), to: DateTime(2026, 11, 4))
          .first;
      expect(day3.single.customerName, 'Zeynep');
    });

    test('bakımı gelenler filtreleri', () async {
      final t = DateTime(2026, 11, 8);
      await createCustomerWithDevice(db, name: 'Gecikmiş', phone: '01', nextMaintenanceDate: DateTime(2026, 11, 1));
      await createCustomerWithDevice(db, name: 'Bugün', phone: '02', nextMaintenanceDate: t);
      await createCustomerWithDevice(db, name: 'Hafta', phone: '03', nextMaintenanceDate: DateTime(2026, 11, 15));
      await createCustomerWithDevice(db, name: 'Ay', phone: '04', nextMaintenanceDate: DateTime(2026, 11, 30));
      await createCustomerWithDevice(db, name: 'Gelecek ay', phone: '05', nextMaintenanceDate: DateTime(2026, 12, 10));
      await createCustomerWithDevice(db, name: 'Bilinmiyor', phone: '06');

      Future<List<String>> due(DueFilter f) async =>
          (await db.devicesDao.watchDueDevices(f, now: t).first).map((e) => e.customer.name).toList();

      expect(await due(DueFilter.overdue), ['Gecikmiş']);
      expect(await due(DueFilter.thisWeek), ['Bugün', 'Hafta']);
      expect(await due(DueFilter.thisMonth), ['Bugün', 'Hafta', 'Ay']);
      expect(await due(DueFilter.upcoming), ['Bugün', 'Hafta', 'Ay']);
      expect(await due(DueFilter.nextMonth), ['Gelecek ay']);
      expect(await due(DueFilter.unknown), ['Bilinmiyor']);
    });

    test('WhatsApp hatırlatma zamanı kaydedilir', () async {
      final a = await createCustomerWithDevice(db);
      final at = DateTime(2026, 11, 8, 9, 15);
      await db.devicesDao.markReminderSent(a.deviceId, at: at);
      expect((await db.devicesDao.getDevice(a.deviceId))!.lastReminderSentAt, at);
    });
  });

  group('Alacaklar', () {
    test('müşteri bazında borç, kısmi ödeme ve ödeme al', () async {
      final a = await createCustomerWithDevice(db, name: 'Ahmet');
      final b = await createCustomerWithDevice(db, name: 'Zeynep', phone: '05001112233');

      Future<String> svc(String deviceId, int day, int total, int paid) => db.servicesDao.insertService(
            ServiceInput(
              deviceId: deviceId,
              date: DateTime(2026, 10, day),
              type: ServiceType.repair,
              totalAmount: total,
              initialPayment: paid,
            ),
          );

      await svc(a.deviceId, 1, 100000, 0); // veresiye
      final partial = await svc(a.deviceId, 5, 80000, 30000); // kismi, 50.000 kalan
      await svc(a.deviceId, 7, 40000, 40000); // odendi
      await svc(b.deviceId, 3, 20000, 0);

      var list = await db.servicesDao.watchReceivables().first;
      expect(list.map((e) => e.name), ['Ahmet', 'Zeynep']);
      expect(list.first.debt, 150000);
      expect(list.first.serviceCount, 2);
      expect(list.first.oldestDebtAt, DateTime(2026, 10, 1));
      expect(await db.servicesDao.watchTotalReceivable().first, 170000);

      final debts = await db.servicesDao.watchDebtServices(a.customerId).first;
      expect(debts.map((e) => e.remaining), [100000, 50000]);

      await db.servicesDao.addPayment(serviceId: partial, amount: 50000, date: DateTime(2026, 11, 1));
      list = await db.servicesDao.watchReceivables().first;
      expect(list.first.debt, 100000);
      expect(await db.servicesDao.watchTotalReceivable().first, 120000);
    });

    test('silinen ödeme alacağı geri getirir', () async {
      final a = await createCustomerWithDevice(db);
      final s = await db.servicesDao.insertService(ServiceInput(
        deviceId: a.deviceId,
        date: DateTime(2026, 10, 1),
        type: ServiceType.repair,
        totalAmount: 10000,
        initialPayment: 10000,
      ));
      expect(await db.servicesDao.watchTotalReceivable().first, 0);
      final payment = (await db.servicesDao.watchPayments(s).first).single;
      await db.softDelete(EntityKind.payment, payment.id);
      expect(await db.servicesDao.watchTotalReceivable().first, 10000);
    });
  });

  group('Randevular', () {
    test('tarih aralığı, adres ve durum', () async {
      final a = await createCustomerWithDevice(db, district: 'Esenyurt');
      await db.appointmentsDao.insertAppointment(
        customerId: a.customerId,
        deviceId: a.deviceId,
        scheduledAt: DateTime(2026, 11, 8, 14),
        type: ServiceType.repair,
        note: 'Akşam',
      );
      final id2 = await db.appointmentsDao.insertAppointment(
        customerId: a.customerId,
        scheduledAt: DateTime(2026, 11, 8, 9),
        type: ServiceType.maintenance,
      );
      await db.appointmentsDao.insertAppointment(
        customerId: a.customerId,
        scheduledAt: DateTime(2026, 11, 9, 9),
        type: ServiceType.maintenance,
      );

      final today = await db.appointmentsDao
          .watchAppointments(from: DateTime(2026, 11, 8), to: DateTime(2026, 11, 9))
          .first;
      expect(today.map((e) => e.scheduledAt.hour), [9, 14]);
      expect(today.first.deviceBrand, isNull);
      expect(today.first.district, 'Esenyurt'); // musterinin ilk adresi
      expect(today.last.deviceBrand, 'Demirdöküm');
      expect(today.last.note, 'Akşam');

      await db.appointmentsDao.setStatus(id2, AppointmentStatus.cancelled);
      final planned = await db.appointmentsDao.watchAppointments(status: AppointmentStatus.planned).first;
      expect(planned, hasLength(2));
    });
  });

  group('Debug araçları', () {
    test('örnek veri oluşturulur ve tüm veri silinir', () async {
      await SampleDataGenerator(db).generate();
      var counts = await db.watchRecordCounts().first;
      expect(counts.customers, 300);
      expect(counts.devices, 500);
      expect(counts.services, 1500);
      expect(counts.appointments, 200);

      final list = await db.customersDao.watchCustomerList().first;
      expect(list, hasLength(300));
      expect(await db.servicesDao.watchReceivables().first, isNotEmpty);

      await db.wipeAllData();
      counts = await db.watchRecordCounts().first;
      expect(counts.customers + counts.devices + counts.services + counts.appointments, 0);
      // Ayarlar ve checklist korunur
      expect(await db.checklistDao.activeLabels(), hasLength(S.defaultChecklist.length));
      expect(await db.settingsDao.getInt(SettingKeys.defaultIntervalMonths), 12);
    });
  });
}
