import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

/// Uygulamanin tek veritabani baglantisi. Testlerde bellek ici veritabani ile override edilir.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final recordCountsProvider = StreamProvider.autoDispose<RecordCounts>(
  (ref) => ref.watch(databaseProvider).watchRecordCounts(),
);
