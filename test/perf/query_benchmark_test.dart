import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:servis_defterim/core/db/daos/customers_dao.dart';
import 'package:servis_defterim/core/db/database.dart';
import 'package:servis_defterim/core/db/sample_data.dart';
import 'package:servis_defterim/core/services/notification_service.dart';
import 'package:servis_defterim/core/utils/dates.dart';
import 'package:servis_defterim/core/utils/maintenance.dart';

/// Ekranlarin sorgularini buyuk veriyle olcer (PLAN 11) ve sureleri yazdirir:
///   flutter test test/perf
/// Veri: ornek veri olusturucunun ~3 kati (PLAN'daki hedef ~300 musteri / 1.500 servis).
/// Sinirlar bilgisayara gore cok genis tutuldu; amac bir sorgunun yanlislikla
/// tam tablo taramasina / N+1'e donmesini yakalamak.
void main() {
  late Directory dir;
  late AppDatabase db;

  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('tr_TR');
    dir = await Directory.systemTemp.createTemp('servis_perf');
    db = AppDatabase(NativeDatabase(File(p.join(dir.path, 'perf.sqlite'))));
    final sw = Stopwatch()..start();
    await SampleDataGenerator(db).generate(
      customerCount: 1000,
      extraAddresses: 300,
      extraDevices: 400,
      serviceCount: 5000,
      appointmentCount: 600,
    );
    final c = await db.recordCounts();
    // ignore: avoid_print
    print('Veri: ${c.customers} musteri, ${c.devices} cihaz, ${c.services} servis, '
        '${c.appointments} randevu (${sw.elapsedMilliseconds} ms)');
  });

  tearDownAll(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  /// Ilk calisma (soguk) ve 5 tekrarin ortancasi.
  Future<void> measure(String name, Future<Object?> Function() run, {int budgetMs = 100}) async {
    final cold = Stopwatch()..start();
    await run();
    cold.stop();
    final times = <int>[];
    for (var i = 0; i < 5; i++) {
      final sw = Stopwatch()..start();
      await run();
      times.add(sw.elapsedMicroseconds);
    }
    times.sort();
    final median = times[2] / 1000;
    // ignore: avoid_print
    print('${name.padRight(38)} soguk ${cold.elapsedMilliseconds.toString().padLeft(4)} ms   '
        'ortanca ${median.toStringAsFixed(1).padLeft(6)} ms');
    expect(median, lessThan(budgetMs), reason: name);
  }

  test('ekran sorgulari', () async {
    final t = today();
    final customers = await db.customersDao.watchCustomerList(sort: CustomerSort.name).first;
    final someCustomer = customers[customers.length ~/ 2];
    final someDevice = (await db.select(db.devices).get())[123];

    await measure('Bugun: randevular', () => db.appointmentsDao.watchAppointments(from: t, to: addDays(t, 1)).first);
    await measure('Bugun: gecikmis bakimlar', () => db.devicesDao.watchDueDevices(DueFilter.overdue).first);
    await measure('Bugun: gecikmis (ilk 5)', () => db.devicesDao.watchDueDevices(DueFilter.overdue, limit: 5).first);
    await measure('Bugun: gecikmis (sayi)', () => db.devicesDao.watchDueCount(DueFilter.overdue).first);
    await measure('Bugun: bu hafta bakimlar', () => db.devicesDao.watchDueDevices(DueFilter.thisWeek).first);
    await measure('Bugun: son 5 servis', () => db.servicesDao.watchServiceList(limit: 5).first);
    await measure('Musteriler: tum liste (son servis)', () => db.customersDao.watchCustomerList().first);
    await measure('Musteriler: tum liste (ada gore)',
        () => db.customersDao.watchCustomerList(sort: CustomerSort.name).first);
    await measure('Arama: "ah"', () => db.customersDao.watchCustomerList(query: 'ah').first);
    await measure('Arama: "yılmaz"', () => db.customersDao.watchCustomerList(query: 'yılmaz').first);
    await measure('Arama: "0532"', () => db.customersDao.watchCustomerList(query: '0532').first);
    await measure('Arama: "demirdokum"', () => db.customersDao.watchCustomerList(query: 'demirdokum').first);
    await measure('Musteri detayi: servisler',
        () => db.servicesDao.watchServiceList(customerId: someCustomer.id).first);
    await measure('Cihaz detayi: servisler', () => db.servicesDao.watchServiceList(deviceId: someDevice.id).first);
    await measure('Bakimi gelenler: 30 gun', () => db.devicesDao.watchDueDevices(DueFilter.upcoming).first);
    await measure('Bakimi gelenler: tarihsiz', () => db.devicesDao.watchDueDevices(DueFilter.unknown).first);
    final monthStart = DateTime(t.year, t.month);
    final monthEnd = DateTime(t.year, t.month + 1);
    await measure('Takvim: ay servisleri',
        () => db.servicesDao.watchServiceList(from: monthStart, to: monthEnd).first);
    await measure('Takvim: ay randevulari',
        () => db.appointmentsDao.watchAppointments(from: monthStart, to: monthEnd).first);
    await measure('Takvim: ay bakimlari',
        () => db.devicesDao
            .watchDueDevicesInRange(from: toDateKey(monthStart), to: toDateKey(addDays(monthEnd, -1)))
            .first);
    await measure('Alacaklar: musteri listesi', () => db.servicesDao.watchReceivables().first);
    await measure('Alacaklar: toplam', () => db.servicesDao.watchTotalReceivable().first);
    await measure('Kayit sayilari', () => db.recordCounts());
    await measure('Bildirim planlama', () => NotificationSync.buildPlan(db, now: DateTime.now()), budgetMs: 200);
  });

  test('sorgu planlari (tam tablo taramasi kontrolu)', () async {
    Future<void> explain(String name, String sql, [List<Object> args = const []]) async {
      final rows = await db.customSelect('EXPLAIN QUERY PLAN $sql', variables: [for (final a in args) Variable(a)]).get();
      final detail = rows.map((r) => r.read<String>('detail')).toList();
      // ignore: avoid_print
      print('--- $name\n${detail.map((d) => '   $d').join('\n')}');
    }

    await explain(
      'servis listesi (musteri)',
      '''
SELECT s.id FROM service_records s
JOIN devices d ON d.id = s.device_id
JOIN addresses a ON a.id = d.address_id
JOIN customers c ON c.id = a.customer_id
WHERE s.deleted_at IS NULL AND c.id = ? ORDER BY s.date DESC''',
      ['x'],
    );
    await explain('son 5 servis', '''
SELECT s.id FROM service_records s
JOIN devices d ON d.id = s.device_id
JOIN addresses a ON a.id = d.address_id
JOIN customers c ON c.id = a.customer_id
WHERE s.deleted_at IS NULL ORDER BY s.date DESC LIMIT 5''');
    await explain('musteri son servis alt sorgusu', '''
SELECT (SELECT MAX(s.date) FROM service_records s
     JOIN devices d ON d.id = s.device_id
     JOIN addresses a ON a.id = d.address_id
     WHERE a.customer_id = c.id AND s.deleted_at IS NULL) FROM customers c''');
    await explain('alacak odeme toplami', '''
SELECT service_id, SUM(amount) FROM payments WHERE deleted_at IS NULL GROUP BY service_id''');
  });
}
