import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servis_defterim/core/strings.dart';

import 'helpers.dart';

void main() {
  testAppWidgets('Uygulama Bugün sekmesiyle açılır, 4 sekme görünür', (tester) async {
    await pumpApp(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    for (final label in [S.tabToday, S.tabCalendar, S.tabCustomers, S.tabReceivables]) {
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
          findsOneWidget);
    }
    expect(find.text(S.todayAppointments), findsOneWidget);
    expect(find.text(S.backupNone), findsOneWidget);
    expect(find.text(S.newService), findsOneWidget);
  });

  testAppWidgets('Sekmeler arasında geçiş yapılır', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text(S.tabCustomers));
    await tester.pumpAndSettle();
    expect(find.text(S.customersEmpty), findsOneWidget);

    await tester.tap(find.text(S.tabReceivables));
    await tester.pumpAndSettle();
    expect(find.text(S.noReceivables), findsOneWidget);
    // Alacaklar sekmesinde "Yeni Servis" butonu yok
    expect(find.text(S.newService), findsNothing);
  });

  testAppWidgets('Ayarlar ve Yeni Servis sayfaları açılır', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip(S.settings));
    await tester.pumpAndSettle();
    expect(find.text(S.defaultInterval), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text(S.newService));
    await tester.pumpAndSettle();
    expect(find.text(S.searchCustomerHint), findsOneWidget);
  });
}
