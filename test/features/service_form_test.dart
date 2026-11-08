import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servis_defterim/core/db/daos/services_dao.dart';
import 'package:servis_defterim/core/db/daos/settings_dao.dart';
import 'package:servis_defterim/core/db/database.dart';
import 'package:servis_defterim/core/router/app_router.dart';
import 'package:servis_defterim/core/strings.dart';
import 'package:servis_defterim/core/utils/dates.dart';
import 'package:servis_defterim/features/services/service_draft.dart';

import '../db/test_db.dart';
import '../helpers.dart';

Finder field(String label) => find.widgetWithText(TextFormField, label);

/// Uzun formda oge henuz cizilmemis olabilir: bulunana kadar asagi, sonra yukari kaydir.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  final list = find.byType(ListView).first;
  for (var i = 0; i < 20 && finder.evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(0, -250));
    await tester.pumpAndSettle();
  }
  for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(0, 250));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<String> fieldText(WidgetTester tester, String label) async {
  await reveal(tester, field(label));
  return tester.widget<TextFormField>(field(label)).controller!.text;
}

Future<void> enter(WidgetTester tester, Finder finder, String text) async {
  await reveal(tester, finder);
  await tester.enterText(finder, text);
  await tester.pump();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, S.save));
  await tester.pumpAndSettle();
}

void main() {
  testAppWidgets('Zorunlu alanlar: müşteri ve tür seçilmeden kaydedilmez', (tester) async {
    final db = await pumpApp(tester);
    await tester.tap(find.text(S.newService));
    await tester.pumpAndSettle();

    await save(tester);
    expect(find.text(S.selectCustomer), findsWidgets);
    expect(find.text(S.selectServiceType), findsOneWidget);
    expect(find.text(S.newService), findsOneWidget); // hala formda
    expect((await firstOf(tester, db.watchRecordCounts())).services, 0);
  });

  testAppWidgets('Kombiden başlatılan arıza kaydı: toplam hesaplanır, tamamı ödenir', (tester) async {
    late ({String customerId, String addressId, String deviceId}) ids;
    final db = await pumpApp(tester, seed: (db) async => ids = await createCustomerWithDevice(db));
    await pushRoute(tester, Routes.newServiceFor(deviceId: ids.deviceId));

    // Musteri/adres/kombi secili gelir
    expect(find.text('Ahmet Yılmaz'), findsOneWidget);
    expect(find.text('Demirdöküm Nitromix'), findsOneWidget);

    await tapVisible(tester, find.widgetWithText(ChoiceChip, S.serviceRepair));
    expect(field(S.complaint), findsOneWidget);
    await enter(tester, field(S.complaint), 'Sıcak su gelmiyor');

    await tapVisible(tester, find.text(S.addPart));
    await enter(tester, field(S.partName), 'Pompa');
    await enter(tester, field(S.quantity), '2');
    await enter(tester, field(S.unitPrice), '150');
    // Ucret parca toplamindan otomatik gelir; usta isterse uzerine yazar
    expect(await fieldText(tester, S.fee), '300');
    await enter(tester, field(S.fee), '800');
    expect(field('İşçilik'), findsNothing);

    await tapVisible(tester, find.widgetWithText(ChoiceChip, S.payFull));
    expect(await fieldText(tester, S.paymentReceived), '800');

    await save(tester);

    // Servis detayi
    expect(find.text(S.saved), findsOneWidget);
    expect(find.text('800,00 ₺'), findsWidgets);
    expect(find.text(S.paymentPaid), findsOneWidget);
    expect(find.text('Sıcak su gelmiyor'), findsOneWidget);
    expect(find.text('Pompa'), findsOneWidget);

    final list = await firstOf(tester, db.servicesDao.watchServiceList());
    expect(list.single.totalAmount, 80000);
    expect(list.single.paidAmount, 80000);
  });

  testAppWidgets('Periyodik bakım: checklist ve sonraki bakım tarihi', (tester) async {
    late ({String customerId, String addressId, String deviceId}) ids;
    final db = await pumpApp(tester, seed: (db) async => ids = await createCustomerWithDevice(db));
    await pushRoute(tester, Routes.newServiceFor(deviceId: ids.deviceId));

    await tapVisible(tester, find.widgetWithText(ChoiceChip, S.serviceMaintenance));
    expect(find.text(S.defaultChecklist.first), findsOneWidget);
    await tapVisible(tester, find.text(S.selectAll));

    final expectedNext = addMonths(today(), 12);
    await reveal(tester, find.text(formatDateLong(expectedNext)));
    expect(find.text(formatDateLong(expectedNext)), findsOneWidget);

    await enter(tester, field(S.fee), '1000');
    await tapVisible(tester, find.widgetWithText(ChoiceChip, S.payNone));
    await save(tester);

    expect(find.text(S.paymentUnpaid), findsOneWidget);
    final device = await db.devicesDao.getDevice(ids.deviceId);
    expect(device!.nextMaintenanceDate, expectedNext);
    final s = await firstOf(tester, db.servicesDao.watchServiceList());
    final record = await db.servicesDao.getService(s.single.id);
    expect(record!.checklistItems, hasLength(S.defaultChecklist.length));
    expect(record.isPeriodicMaintenance, isTrue);

    // Detaydan odeme al: varsayilan kalan tutar
    await tapVisible(tester, find.widgetWithText(FilledButton, S.takePayment));
    expect(find.widgetWithText(TextFormField, '1000'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, S.save).last);
    await tester.pumpAndSettle();
    await reveal(tester, find.text(S.paymentPaid));
    expect(find.text(S.paymentPaid), findsOneWidget);
    expect(await firstOf(tester, db.servicesDao.watchTotalReceivable()), 0);
  });

  testAppWidgets('Yeni müşteri, adres ve kombi formun içinde oluşturulur', (tester) async {
    final db = await pumpApp(tester);
    await tester.tap(find.text(S.newService));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text(S.addNewCustomer));
    await enter(tester, field(S.customerName), 'Zeynep Kaya');
    await enter(tester, field(S.phone), '0544 555 66 77');
    await enter(tester, field(S.addressLine), 'Lale Sk. 3');
    await enter(tester, field(S.brand), 'Baymak');
    await tapVisible(tester, find.widgetWithText(ChoiceChip, S.serviceInspection));
    await save(tester);

    expect(find.text(S.saved), findsOneWidget);
    final counts = await firstOf(tester, db.watchRecordCounts());
    expect((counts.customers, counts.devices, counts.services), (1, 1, 1));
    final customers = await firstOf(tester, db.customersDao.watchCustomerList());
    expect(customers.single.name, 'Zeynep Kaya');
  });

  testAppWidgets('Otomatik taslak: geri tuşunda saklanır, tekrar açınca devam edilir', (tester) async {
    final db = await pumpApp(tester);
    await tester.tap(find.text(S.newService));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text(S.addNewCustomer));
    await enter(tester, field(S.customerName), 'Taslak Müşteri');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    final raw = await db.settingsDao.getValue(SettingKeys.serviceDraft);
    expect(ServiceDraft.decode(raw)!.newCustomerName, 'Taslak Müşteri');

    // Geri: "Taslak olarak sakla"
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text(S.leaveFormTitle), findsOneWidget);
    await tester.tap(find.text(S.keepDraft));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);

    // Tekrar acinca sorulur, devam edilir
    await tester.tap(find.text(S.newService));
    await tester.pumpAndSettle();
    expect(find.text(S.draftResumeBody), findsOneWidget);
    await tester.tap(find.text(S.draftContinue));
    await tester.pumpAndSettle();
    expect(await fieldText(tester, S.customerName), 'Taslak Müşteri');

    // Geri: "Sil" taslagi siler
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.draftDiscard));
    await tester.pumpAndSettle();
    expect(await db.settingsDao.getValue(SettingKeys.serviceDraft), isNull);
  });

  testAppWidgets('Açılışta yarım kalan taslak sorulur', (tester) async {
    await pumpApp(
      tester,
      seed: (db) => db.settingsDao.setValue(
        SettingKeys.serviceDraft,
        ServiceDraft(date: DateTime(2026, 11, 8), newCustomer: true, newCustomerName: 'Yarım').encode(),
      ),
    );
    expect(find.text(S.draftResumeBody), findsOneWidget);
    await tester.tap(find.text(S.draftContinue));
    await tester.pumpAndSettle();
    expect(await fieldText(tester, S.customerName), 'Yarım');
  });

  testAppWidgets('Servis düzenlenir ve silinir', (tester) async {
    late String serviceId;
    final db = await pumpApp(tester, seed: (db) async {
      final ids = await createCustomerWithDevice(db);
      serviceId = await db.servicesDao.insertService(ServiceInput(
        deviceId: ids.deviceId,
        date: DateTime(2026, 10, 1, 10),
        type: ServiceType.repair,
        totalAmount: 50000,
      ));
    });
    await pushRoute(tester, Routes.service(serviceId));
    expect(find.text(S.paymentUnpaid), findsOneWidget);

    await tester.tap(find.byTooltip(S.edit));
    await tester.pumpAndSettle();
    expect(await fieldText(tester, S.fee), '500');
    await enter(tester, field(S.fee), '650');
    await save(tester);
    expect(find.text('650,00 ₺'), findsWidgets);

    await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.byType(PopupMenuButton<void>)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, S.delete));
    await tester.pumpAndSettle();
    expect(find.text(S.serviceDeleted), findsOneWidget);
    expect((await firstOf(tester, db.watchRecordCounts())).services, 0);
  });
}
