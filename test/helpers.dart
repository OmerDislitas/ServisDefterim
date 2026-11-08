import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servis_defterim/app.dart';
import 'package:servis_defterim/core/db/database.dart';
import 'package:servis_defterim/core/db/db_providers.dart';

import 'db/test_db.dart';

/// Uygulamayi kullanan widget testi. Test sonunda agaci kaldirip Drift'in
/// stream kapatma zamanlayicilarinin calismasini bekler ("A Timer is still pending").
void testAppWidgets(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      // Test basarisiz olsa bile agaci kaldir; yoksa veritabani kapanirken test takilir.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    }
  });
}

/// Uygulamayi bellek ici veritabaniyla baslatir. [seed] ile once veri eklenebilir.
Future<AppDatabase> pumpApp(WidgetTester tester, {Future<void> Function(AppDatabase db)? seed}) async {
  final db = createTestDb();
  addTearDown(db.close);
  if (seed != null) await seed(db);
  await tester.pumpWidget(ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: const App(),
  ));
  await tester.pumpAndSettle();
  return db;
}
