import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servis_defterim/core/db/daos/services_dao.dart';
import 'package:servis_defterim/core/db/database.dart';
import 'package:servis_defterim/core/router/app_router.dart';
import 'package:servis_defterim/core/strings.dart';

import '../db/test_db.dart';
import '../helpers.dart';

Future<void> seedDebts(AppDatabase db) async {
  final a = await createCustomerWithDevice(db, name: 'Ahmet Borçlu', phone: '05001112233');
  final b = await createCustomerWithDevice(db, name: 'Zeynep Kısmi', phone: '05004445566');
  await db.servicesDao.insertService(ServiceInput(
    deviceId: a.deviceId,
    date: DateTime(2026, 10, 1),
    type: ServiceType.repair,
    totalAmount: 150000,
  ));
  await db.servicesDao.insertService(ServiceInput(
    deviceId: b.deviceId,
    date: DateTime(2026, 10, 5),
    type: ServiceType.maintenance,
    totalAmount: 100000,
    initialPayment: 60000,
  ));
}

void main() {
  testAppWidgets('Alacaklar: toplam, müşteri bazında borç ve ödeme al', (tester) async {
    final db = await pumpApp(tester, seed: seedDebts);
    await tester.tap(find.text(S.tabReceivables));
    await tester.pumpAndSettle();

    expect(find.text('1.900,00 ₺'), findsOneWidget); // 1500 + 400
    expect(find.text(S.receivableCustomers(2)), findsOneWidget);
    expect(find.text('Ahmet Borçlu'), findsOneWidget);
    expect(find.text('Zeynep Kısmi'), findsOneWidget);

    // Musteriye dokununca borclu servisleri acilir
    await tester.tap(find.text('Zeynep Kısmi'));
    await tester.pumpAndSettle();
    expect(find.text(S.paymentPartial), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, S.takePayment));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '400'), findsOneWidget); // varsayilan: kalan
    await tester.tap(find.widgetWithText(FilledButton, S.save));
    await tester.pumpAndSettle();

    // Borcu kapanan musteri listeden cikar
    expect(find.text('Zeynep Kısmi'), findsNothing);
    expect(find.text('1.500,00 ₺'), findsWidgets);
    expect(await firstOf(tester, db.servicesDao.watchTotalReceivable()), 150000);
  });

  testAppWidgets('Müşteri detayındaki alacak kartından ödeme alınır', (tester) async {
    late String customerId;
    final db = await pumpApp(tester, seed: (db) async {
      await seedDebts(db);
      customerId = (await db.customersDao.findByPhone('05001112233')).single.id;
    });
    await pushRoute(tester, Routes.customer(customerId));
    expect(find.text('${S.receivable}: 1.500,00 ₺'), findsOneWidget);

    await tester.tap(find.text('${S.receivable}: 1.500,00 ₺'));
    await tester.pumpAndSettle();
    expect(find.text(S.debtServices), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, S.takePayment));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '1500'), '1000');
    await tester.tap(find.widgetWithText(FilledButton, S.save));
    await tester.pumpAndSettle();

    final debt = await firstOf(tester, db.servicesDao.watchDebtServices(customerId));
    expect(debt.single.remaining, 50000);
  });
}
