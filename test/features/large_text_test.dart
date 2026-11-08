import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servis_defterim/core/db/daos/services_dao.dart';
import 'package:servis_defterim/core/db/database.dart';
import 'package:servis_defterim/core/router/app_router.dart';
import 'package:servis_defterim/core/strings.dart';
import 'package:servis_defterim/core/utils/dates.dart';

import '../db/test_db.dart';
import '../helpers.dart';

/// Erisilebilirlik (PLAN 12): sistem yazi boyutu buyutuldugunde ana ekranlarda
/// tasma (RenderFlex overflow) olmamali. Tasma test hatasi olarak yakalanir.
void main() {
  for (final scale in [1.3, 2.0]) {
    testAppWidgets('Büyük yazı ($scale x): ana ekranlar taşmadan açılır', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      // Orta segment telefon: 1080x2340, 411x891 dp
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final t = today();
      late String serviceId;
      late String apptId;
      late ({String customerId, String addressId, String deviceId}) ids;
      await pumpApp(tester, seed: (db) async {
        ids = await createCustomerWithDevice(
          db,
          name: 'Mehmet Ali Uzunisimlioğlu',
          brand: 'Demirdöküm',
          model: 'Nitromix Ioni Premix 24 kW',
          nextMaintenanceDate: addDays(t, -40),
        );
        await createCustomerWithDevice(db, name: 'Ayşe Kaya', phone: '05001112233', nextMaintenanceDate: addDays(t, 2));
        serviceId = await db.servicesDao.insertService(ServiceInput(
          deviceId: ids.deviceId,
          date: DateTime(t.year, t.month, t.day, 10),
          type: ServiceType.repair,
          totalAmount: 1234567,
          parts: const [PartInput(name: 'Sirkülasyon pompası ve bağlantı contaları', quantity: 2, unitPrice: 250000)],
        ));
        apptId = await db.appointmentsDao.insertAppointment(
          customerId: ids.customerId,
          deviceId: ids.deviceId,
          scheduledAt: DateTime(t.year, t.month, t.day, 23, 30),
          type: ServiceType.maintenance,
        );
      });

      // Sekmeler
      for (final tab in [S.tabCalendar, S.tabCustomers, S.tabReceivables, S.tabToday]) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
      }
      // Detaylar ve formlar
      for (final route in [
        Routes.settings,
        Routes.customer(ids.customerId),
        Routes.device(ids.deviceId),
        Routes.service(serviceId),
        Routes.dueMaintenance(),
        Routes.serviceEdit(serviceId),
        Routes.newServiceFor(deviceId: ids.deviceId),
        Routes.newService,
        Routes.appointment(apptId),
        Routes.appointmentNew(customerId: ids.customerId),
        Routes.customerNew,
        Routes.customerEdit(ids.customerId),
        Routes.addressEdit(ids.addressId),
        Routes.deviceEdit(ids.deviceId),
        Routes.checklistSettings,
        Routes.whatsappTemplateSettings,
      ]) {
        await pushRoute(tester, route);
        expect(tester.takeException(), isNull, reason: route);
        await tester.tap(find.byType(BackButton).first);
        await tester.pumpAndSettle();
      }
    });
  }
}
