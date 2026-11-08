import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servis_defterim/app.dart';
import 'package:servis_defterim/core/db/db_providers.dart';
import 'package:servis_defterim/core/strings.dart';

import 'db/test_db.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    final db = createTestDb();
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const App(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Uygulama Bugün sekmesiyle açılır, 4 sekme görünür', (tester) async {
    await pumpApp(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    for (final label in [S.tabToday, S.tabCalendar, S.tabCustomers, S.tabReceivables]) {
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
          findsOneWidget);
    }
    expect(find.text(S.todayEmpty), findsOneWidget);
    expect(find.text(S.newService), findsOneWidget);
  });

  testWidgets('Sekmeler arasında geçiş yapılır', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text(S.tabCustomers));
    await tester.pumpAndSettle();
    expect(find.text(S.customersEmpty), findsOneWidget);

    await tester.tap(find.text(S.tabReceivables));
    await tester.pumpAndSettle();
    expect(find.text(S.receivablesEmpty), findsOneWidget);
    // Alacaklar sekmesinde "Yeni Servis" butonu yok
    expect(find.text(S.newService), findsNothing);
  });

  testWidgets('Ayarlar ve Yeni Servis sayfaları açılır', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip(S.settings));
    await tester.pumpAndSettle();
    expect(find.text(S.settingsEmpty), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text(S.newService));
    await tester.pumpAndSettle();
    expect(find.text(S.newServiceEmpty), findsOneWidget);
  });
}
