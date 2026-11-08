import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:servis_defterim/app.dart';
import 'package:servis_defterim/core/db/database.dart';
import 'package:servis_defterim/core/db/db_providers.dart';
import 'package:servis_defterim/core/router/app_router.dart';

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

/// Drift `watch()` akisinin ilk degeri. Widget testinin sahte saatinde `.first`
/// gecikebildigi icin gercek zamanli calistirilir.
Future<T> firstOf<T>(WidgetTester tester, Stream<T> stream) async => (await tester.runAsync(() => stream.first)) as T;

/// Uygulama icinde bir rotaya gider (UI uzerinden gezinmeden).
Future<void> pushRoute(WidgetTester tester, String location) async {
  final container = ProviderScope.containerOf(tester.element(find.byType(App)));
  container.read(routerProvider).push(location);
  await tester.pumpAndSettle();
}

/// Uygulamayi bellek ici veritabaniyla baslatir. [seed] ile once veri eklenebilir.
Future<AppDatabase> pumpApp(WidgetTester tester, {Future<void> Function(AppDatabase db)? seed}) async {
  await initializeDateFormatting('tr_TR');
  final db = createTestDb();
  addTearDown(db.close);
  if (seed != null) await seed(db);
  await tester.pumpWidget(ProviderScope(
    // Testte hata veren provider'lar tekrar denenmesin (zamanlayici birakir)
    retry: (_, _) => null,
    overrides: [
      databaseProvider.overrideWithValue(db),
      packageInfoProvider.overrideWithValue(
        AsyncData(PackageInfo(appName: 'Servis Defterim', packageName: 'test', version: '1.0.0', buildNumber: '1')),
      ),
    ],
    child: const App(),
  ));
  await tester.pumpAndSettle();
  return db;
}
