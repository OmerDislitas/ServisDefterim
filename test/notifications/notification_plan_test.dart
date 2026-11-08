import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:servis_defterim/core/db/daos/settings_dao.dart';
import 'package:servis_defterim/core/db/database.dart';
import 'package:servis_defterim/core/router/app_router.dart';
import 'package:servis_defterim/core/services/notification_service.dart';
import 'package:servis_defterim/core/utils/maintenance.dart';
import 'package:servis_defterim/core/utils/notification_plan.dart';

import '../db/test_db.dart';

void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('tr_TR');
  });

  // Pazar 8 Kasim 2026, 10:00
  final now = DateTime(2026, 11, 8, 10);

  MaintenanceReminderInput dev(String id, String name, DateTime due, [String brand = 'Bosch']) =>
      MaintenanceReminderInput(deviceId: id, customerName: name, brand: brand, dueDate: due);

  group('Bakım bildirimi', () {
    test('bakım tarihinden N gün önce, ayarlanan saatte', () {
      final list = planNotifications(
        now: now,
        prefs: const NotificationPrefs(hour: 9, daysBefore: 3),
        devices: [dev('d1', 'Ahmet Yılmaz', DateTime(2026, 11, 20), 'Demirdöküm')],
      );
      final n = list.single;
      expect(n.kind, NotificationKind.maintenance);
      expect(n.at, DateTime(2026, 11, 17, 9));
      expect(n.body, 'Ahmet Yılmaz – Demirdöküm: bakım 3 gün sonra (20 Kasım).');
      expect(n.payload, Routes.device('d1'));
    });

    test('aynı güne düşen kombiler tek bildirimde gruplanır', () {
      final due = DateTime(2026, 11, 20);
      final list = planNotifications(
        now: now,
        prefs: const NotificationPrefs(daysBefore: 1),
        devices: [
          dev('d1', 'Ahmet Yılmaz', due),
          dev('d2', 'Mehmet Demir', due),
          dev('d3', 'Ayşe Kaya', due),
          dev('d4', 'Veli Can', due),
          dev('d5', 'Başka Gün', DateTime(2026, 11, 25)),
        ],
      );
      expect(list, hasLength(2));
      final group = list.first;
      expect(group.at, DateTime(2026, 11, 19, 9));
      expect(group.title, '4 kombinin bakımı yaklaşıyor');
      expect(group.body, 'Yarın (20 Kasım) 4 kombinin bakımı var: Ahmet Yılmaz, Mehmet Demir, Ayşe Kaya…');
      expect(group.payload, Routes.dueMaintenance(DueFilter.upcoming));
      expect(list.last.payload, Routes.device('d5'));
    });

    test('zamanı geçmiş ya da 60 günden sonraki bildirim planlanmaz', () {
      final list = planNotifications(
        now: now,
        prefs: const NotificationPrefs(hour: 9, daysBefore: 0),
        devices: [
          dev('bugun', 'Saat geçti', DateTime(2026, 11, 8)), // bugun 09:00 < 10:00
          dev('gecikmis', 'Gecikmiş', DateTime(2026, 10, 1)),
          dev('uzak', 'Uzak', DateTime(2027, 2, 1)),
          dev('yarin', 'Yarın', DateTime(2026, 11, 9)),
        ],
      );
      expect(list.map((n) => n.payload), [Routes.device('yarin')]);
      expect(list.single.body, contains('bakım bugün.'));
    });
  });

  test('randevu bildirimi 1 saat önce; ids sıralı ve en fazla 100', () {
    final list = planNotifications(
      now: now,
      prefs: const NotificationPrefs(),
      appointments: [
        AppointmentReminderInput(
          id: 'a1',
          scheduledAt: DateTime(2026, 11, 8, 14, 30),
          customerName: 'Ahmet Yılmaz',
          typeLabel: 'Bakım',
          place: 'Başakşehir, Kayabaşı',
        ),
        AppointmentReminderInput(
          id: 'gecti',
          scheduledAt: DateTime(2026, 11, 8, 10, 30), // 09:30'da bildirim olmaliydi
          customerName: 'X',
          typeLabel: 'Arıza',
        ),
      ],
    );
    final n = list.single;
    expect(n.kind, NotificationKind.appointment);
    expect(n.at, DateTime(2026, 11, 8, 13, 30));
    expect(n.title, 'Randevu: 14:30');
    expect(n.body, 'Ahmet Yılmaz · Başakşehir, Kayabaşı · Bakım');
    expect(n.payload, Routes.appointment('a1'));

    final many = planNotifications(
      now: now,
      prefs: const NotificationPrefs(),
      devices: [for (var i = 1; i <= 150; i++) dev('d$i', 'M$i', DateTime(2026, 11, 12).add(Duration(days: i % 55)))],
      appointments: [
        for (var i = 0; i < 120; i++)
          AppointmentReminderInput(
            id: 'a$i',
            scheduledAt: DateTime(2026, 11, 9, 8).add(Duration(hours: i * 7)),
            customerName: 'R$i',
            typeLabel: 'Bakım',
          ),
      ],
    );
    expect(many, hasLength(100));
    expect(many.map((n) => n.id), List.generate(100, (i) => i + 1));
    for (var i = 1; i < many.length; i++) {
      expect(many[i].at.isBefore(many[i - 1].at), isFalse);
    }
  });

  test('kapalı ayarlar bildirim üretmez', () {
    final devices = [dev('d1', 'A', DateTime(2026, 11, 20))];
    final appts = [
      AppointmentReminderInput(id: 'a1', scheduledAt: DateTime(2026, 11, 10, 12), customerName: 'B', typeLabel: 'Bakım'),
    ];
    expect(planNotifications(now: now, prefs: const NotificationPrefs(enabled: false), devices: devices, appointments: appts),
        isEmpty);
    expect(
      planNotifications(now: now, prefs: const NotificationPrefs(maintenance: false), devices: devices, appointments: appts)
          .map((n) => n.kind),
      [NotificationKind.appointment],
    );
    expect(
      planNotifications(now: now, prefs: const NotificationPrefs(appointment: false), devices: devices, appointments: appts)
          .map((n) => n.kind),
      [NotificationKind.maintenance],
    );
  });

  test('veritabanından plan: silinen kombi ve tamamlanan randevu dahil edilmez, ayarlar uygulanır', () async {
    final db = createTestDb();
    final real = DateTime.now();
    final t = DateTime(real.year, real.month, real.day);
    final a = await createCustomerWithDevice(db, name: 'Ahmet Yılmaz', nextMaintenanceDate: t.add(const Duration(days: 10)));
    final b = await createCustomerWithDevice(db, name: 'Silinen', phone: '02', nextMaintenanceDate: t.add(const Duration(days: 12)));
    await db.softDelete(EntityKind.device, b.deviceId);
    final apptId = await db.appointmentsDao.insertAppointment(
      customerId: a.customerId,
      deviceId: a.deviceId,
      scheduledAt: t.add(const Duration(days: 2, hours: 14)),
      type: ServiceType.maintenance,
    );
    final doneId = await db.appointmentsDao.insertAppointment(
      customerId: a.customerId,
      scheduledAt: t.add(const Duration(days: 3, hours: 14)),
      type: ServiceType.repair,
    );
    await db.appointmentsDao.setStatus(doneId, AppointmentStatus.done);

    var plan = await NotificationSync.buildPlan(db, now: real);
    expect(plan.map((n) => n.payload), [Routes.appointment(apptId), Routes.device(a.deviceId)]);
    expect(plan.last.at, DateTime(t.year, t.month, t.day + 7, 9));
    expect(plan.first.body, contains('Başakşehir, Kayabaşı'));

    await db.settingsDao.setInt(SettingKeys.notificationHour, 18);
    await db.settingsDao.setInt(SettingKeys.remindDaysBefore, 1);
    plan = await NotificationSync.buildPlan(db, now: real);
    expect(plan.last.at, DateTime(t.year, t.month, t.day + 9, 18));

    await db.settingsDao.setBool(SettingKeys.notificationsEnabled, false);
    expect(await NotificationSync.buildPlan(db, now: real), isEmpty);
    await db.close();
  });

  test('senkronizasyon veri değişince yeniden planlar', () async {
    final db = createTestDb();
    final scheduler = _RecordingScheduler();
    final sync = NotificationSync(db, scheduler, debounce: const Duration(milliseconds: 10));
    await sync.resync();
    expect(scheduler.last, isEmpty);

    final t = DateTime.now();
    await createCustomerWithDevice(db, nextMaintenanceDate: DateTime(t.year, t.month, t.day + 20));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(scheduler.last, hasLength(1));

    sync.dispose();
    await db.close();
  });
}

class _RecordingScheduler implements NotificationScheduler {
  List<PlannedNotification>? last;

  @override
  Stream<String> get taps => const Stream.empty();
  @override
  Future<String?> launchPayload() async => null;
  @override
  Future<bool> permissionGranted() async => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> replaceAll(List<PlannedNotification> list) async => last = list;
  @override
  Future<void> showTest() async {}
}
