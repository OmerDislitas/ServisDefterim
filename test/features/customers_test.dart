import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servis_defterim/core/db/database.dart';
import 'package:servis_defterim/core/strings.dart';

import '../db/test_db.dart';
import '../helpers.dart';

Finder field(String label) => find.widgetWithText(TextFormField, label);

Future<void> openCustomersTab(WidgetTester tester) async {
  await tester.tap(find.text(S.tabCustomers));
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String label, String text) async {
  await tester.ensureVisible(field(label));
  await tester.enterText(field(label), text);
}

Future<void> tapSave(WidgetTester tester) async {
  await tester.tap(find.text(S.save));
  await tester.pumpAndSettle();
}

void main() {
  testAppWidgets('Yeni müşteri: zorunlu alanlar doğrulanır', (tester) async {
    await pumpApp(tester);
    await openCustomersTab(tester);
    await tester.tap(find.widgetWithText(FilledButton, S.newCustomer));
    await tester.pumpAndSettle();

    await tapSave(tester);
    expect(find.text(S.requiredField), findsNWidgets(2)); // ad ve telefon

    await enter(tester, S.customerName, 'Ali');
    await enter(tester, S.phone, '12');
    await tapSave(tester);
    expect(find.text(S.invalidPhone), findsOneWidget);

    // Adres alanlarindan biri doluysa acik adres zorunlu olur
    await enter(tester, S.phone, '0532 111 22 33');
    await enter(tester, S.district, 'Esenyurt');
    await tapSave(tester);
    expect(find.text(S.requiredField), findsOneWidget);
  });

  testAppWidgets('Yeni müşteri adresle kaydedilir ve detayı açılır', (tester) async {
    final db = await pumpApp(tester);
    await openCustomersTab(tester);
    await tester.tap(find.widgetWithText(FilledButton, S.newCustomer));
    await tester.pumpAndSettle();

    await enter(tester, S.customerName, 'Şükrü Öztürk');
    await enter(tester, S.phone, '+90 532 111 22 33');
    await enter(tester, S.district, 'Başakşehir');
    await enter(tester, S.neighborhood, 'Kayabaşı');
    await enter(tester, S.addressLine, 'Gül Sk. No:5');
    await tapSave(tester);

    // Detay ekrani
    expect(find.text('Şükrü Öztürk'), findsOneWidget);
    expect(find.text('0532 111 22 33'), findsOneWidget);
    expect(find.text('Kayabaşı, Başakşehir'), findsOneWidget);
    expect(find.text(S.noDevicesAtAddress), findsOneWidget);

    final customers = await firstOf(tester, db.customersDao.watchCustomerList());
    expect(customers.single.phone, '5321112233');

    // Listeye donuste musteri gorunur
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Şükrü Öztürk'), findsOneWidget);
  });

  testAppWidgets('Aynı telefonla kayıtlı müşteri uyarısı gösterilir', (tester) async {
    await pumpApp(tester, seed: (db) => createCustomerWithDevice(db, name: 'Ahmet Yılmaz'));
    await openCustomersTab(tester);
    await tester.tap(find.byTooltip(S.newCustomer));
    await tester.pumpAndSettle();

    await enter(tester, S.phone, '05321112233');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text(S.duplicatePhone('Ahmet Yılmaz')), findsOneWidget);
  });

  testAppWidgets('Arama Türkçe karakterlerden bağımsız çalışır', (tester) async {
    await pumpApp(tester, seed: (db) async {
      await createCustomerWithDevice(db, name: 'Şükrü Öztürk', phone: '05321112233');
      await createCustomerWithDevice(db, name: 'Mehmet Demir', phone: '05445556677', brand: 'Vaillant');
    });
    await openCustomersTab(tester);
    expect(find.text('Şükrü Öztürk'), findsOneWidget);
    expect(find.text('Mehmet Demir'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'sukru');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('Şükrü Öztürk'), findsOneWidget);
    expect(find.text('Mehmet Demir'), findsNothing);

    await tester.enterText(find.byType(TextField), 'vaillant');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('Mehmet Demir'), findsOneWidget);
    expect(find.text('Şükrü Öztürk'), findsNothing);

    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text(S.noSearchResults), findsOneWidget);
  });

  testAppWidgets('Müşteri silinir ve geri alınır', (tester) async {
    await pumpApp(tester, seed: (db) => createCustomerWithDevice(db, name: 'Ahmet Yılmaz'));
    await openCustomersTab(tester);
    await tester.tap(find.text('Ahmet Yılmaz'));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.byType(PopupMenuButton<void>)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.delete));
    await tester.pumpAndSettle();
    expect(find.text(S.deleteCustomerTitle('Ahmet Yılmaz')), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, S.delete));
    await tester.pumpAndSettle();

    // Listeye donuldu, musteri yok, "Geri al" gorunur
    expect(find.text(S.customerDeleted), findsOneWidget);
    expect(find.text('Ahmet Yılmaz'), findsNothing);

    await tester.tap(find.text(S.undo));
    await tester.pumpAndSettle();
    expect(find.text('Ahmet Yılmaz'), findsOneWidget);
  });

  testAppWidgets('Adrese kombi eklenir, kombi detayı açılır', (tester) async {
    late AppDatabase database;
    await pumpApp(tester, seed: (db) async {
      database = db;
      final c = await db.customersDao.insertCustomer(name: 'Ayşe Kaya', phone: '05001112233');
      await db.customersDao.insertAddress(customerId: c, district: 'Avcılar', addressLine: 'Lale Sk. 3');
    });
    await openCustomersTab(tester);
    await tester.tap(find.text('Ayşe Kaya'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(S.addDevice));
    await tester.pumpAndSettle();
    await enter(tester, S.brand, 'Vaillant');
    await enter(tester, S.model, 'ecoTEC Pro');
    final chip = find.widgetWithText(ChoiceChip, S.deviceHermetic);
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pump();
    await tapSave(tester);

    // Musteri detayinda kombi ve "Tarih bilinmiyor" rozeti
    expect(find.text('Vaillant ecoTEC Pro'), findsOneWidget);
    expect(find.text(S.maintUnknown), findsOneWidget);

    final device = (await database.devicesDao.brandSuggestions()).contains('Vaillant');
    expect(device, isTrue);

    await tester.tap(find.text('Vaillant ecoTEC Pro'));
    await tester.pumpAndSettle();
    expect(find.text(S.deviceHermetic), findsOneWidget);
    expect(find.text(S.intervalMonths(12)), findsOneWidget);
    expect(find.text(S.startService), findsOneWidget);
  });
}
