import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servis_defterim/core/db/daos/services_dao.dart';
import 'package:servis_defterim/core/db/daos/settings_dao.dart';
import 'package:servis_defterim/core/db/database.dart';
import 'package:servis_defterim/core/router/app_router.dart';
import 'package:servis_defterim/core/strings.dart';
import 'package:servis_defterim/core/utils/dates.dart';

import '../db/test_db.dart';
import '../helpers.dart';

void main() {
  testAppWidgets('Bugün: gecikmiş ve bu hafta bakımları, Tümünü gör ve filtreler', (tester) async {
    final t = today();
    await pumpApp(tester, seed: (db) async {
      await createCustomerWithDevice(db, name: 'Gecikmiş Ali', phone: '01', nextMaintenanceDate: addDays(t, -10));
      await createCustomerWithDevice(db, name: 'Haftalık Ayşe', phone: '02', nextMaintenanceDate: addDays(t, 3));
      await createCustomerWithDevice(db, name: 'Tarihsiz Veli', phone: '03');
    });

    expect(find.text(S.backupNone), findsOneWidget);
    expect(find.text(S.overdueMaintenance), findsOneWidget);
    expect(find.text('Gecikmiş Ali'), findsOneWidget);
    expect(find.text('Haftalık Ayşe'), findsOneWidget);
    expect(find.text('Tarihsiz Veli'), findsNothing);

    await tester.tap(find.text(S.seeAll).first);
    await tester.pumpAndSettle();
    expect(find.text(S.dueMaintenance), findsOneWidget);
    expect(find.text('Gecikmiş Ali'), findsOneWidget);
    expect(find.text('Haftalık Ayşe'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, S.filterUnknown));
    await tester.pumpAndSettle();
    expect(find.text('Tarihsiz Veli'), findsOneWidget);
    expect(find.text('Gecikmiş Ali'), findsNothing);
  });

  testAppWidgets('Bugün: yakın tarihli yedek küçük satır olarak gösterilir', (tester) async {
    final now = DateTime.now();
    await pumpApp(
      tester,
      seed: (db) => db.settingsDao.setValue(SettingKeys.lastBackupAt, now.toIso8601String()),
    );
    expect(find.text(S.backupNone), findsNothing);
    expect(find.text(S.backupLast('${S.today} ${formatTime(now)}')), findsOneWidget);
  });

  testAppWidgets('Bugün: Drive hatası kartta gösterilir', (tester) async {
    await pumpApp(tester, seed: (db) => db.settingsDao.setValue(SettingKeys.driveLastError, S.driveReconnect));
    expect(find.text(S.driveReconnect), findsOneWidget);
    expect(find.text(S.goToSettings), findsOneWidget);
  });

  testAppWidgets('Ayarlar: Drive bağlı değilse bağlan seçeneği gösterilir', (tester) async {
    await pumpApp(tester);
    await pushRoute(tester, Routes.settings);
    expect(find.text(S.driveNotConfigured), findsNothing);
    expect(find.text(S.driveConnect), findsOneWidget);
    expect(find.text(S.exportBackup), findsOneWidget);
  });

  testAppWidgets('Ayarlar: Drive bağlıysa hesap ve yedek seçenekleri gösterilir', (tester) async {
    await pumpApp(tester, seed: (db) => db.settingsDao.setValue(SettingKeys.driveAccountEmail, 'usta@gmail.com'));
    await pushRoute(tester, Routes.settings);
    expect(find.text(S.driveConnectedAs('usta@gmail.com')), findsOneWidget);
    expect(find.text(S.driveBackupNow), findsOneWidget);
    expect(find.text(S.driveConnect), findsNothing);
  });

  testAppWidgets('Randevu oluşturulur, randevudan servis başlatılır ve randevu kapanır', (tester) async {
    late ({String customerId, String addressId, String deviceId}) ids;
    final db = await pumpApp(tester, seed: (db) async => ids = await createCustomerWithDevice(db));

    await pushRoute(tester, Routes.appointmentNew(customerId: ids.customerId));
    expect(find.text('Ahmet Yılmaz'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Demirdöküm Nitromix'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, S.save));
    await tester.pumpAndSettle();

    final appts = await firstOf(tester, db.appointmentsDao.watchAppointments());
    expect(appts.single.deviceId, ids.deviceId);
    expect(appts.single.status, AppointmentStatus.planned);

    // Bugun ekraninda randevu gorunur
    expect(find.text(S.noAppointmentsToday), findsNothing);
    await tester.tap(find.text('Ahmet Yılmaz').first);
    await tester.pumpAndSettle();
    expect(find.text(S.appointment), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, S.startServiceFromAppointment));
    await tester.pumpAndSettle();
    expect(find.text(S.appointmentLinked), findsOneWidget);
    expect(find.text('Demirdöküm Nitromix'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, S.save));
    await tester.pumpAndSettle();
    expect(find.text(S.saved), findsOneWidget);

    final after = await firstOf(tester, db.appointmentsDao.watchAppointments());
    expect(after.single.status, AppointmentStatus.done);
    final services = await firstOf(tester, db.servicesDao.watchServiceList());
    expect(services.single.type, ServiceType.maintenance);
  });

  testAppWidgets('WhatsApp şablonu ayarlardan değiştirilir', (tester) async {
    final db = await pumpApp(tester);
    await pushRoute(tester, Routes.whatsappTemplateSettings);
    await tester.enterText(find.byType(TextFormField), 'Selam {ad}, {marka} bakımı?');
    await tester.pump();
    expect(find.text('Selam Ahmet Bey, Demirdöküm bakımı?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, S.save));
    await tester.pumpAndSettle();
    expect(await db.settingsDao.getValue(SettingKeys.whatsappTemplate), 'Selam {ad}, {marka} bakımı?');
  });

  testAppWidgets('Takvim: seçilen günün bakım ve servisleri listelenir', (tester) async {
    final t = today();
    await pumpApp(tester, seed: (db) async {
      final ids = await createCustomerWithDevice(db, name: 'Takvim Müşteri', nextMaintenanceDate: t);
      await db.servicesDao.insertService(ServiceInput(
        deviceId: ids.deviceId,
        date: DateTime(t.year, t.month, t.day, 9),
        type: ServiceType.repair,
        totalAmount: 1000,
      ));
    });
    await tester.tap(find.text(S.tabCalendar));
    await tester.pumpAndSettle();

    expect(find.text(formatDateLong(t)), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text(S.maintenanceDue), findsOneWidget);
    expect(find.text(S.servicesDone), findsOneWidget);
    expect(find.text('Takvim Müşteri'), findsWidgets);
  });
}
