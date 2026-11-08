import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/app_paths.dart';
import '../services/backup_service.dart';
import '../services/drive_service.dart';
import 'database.dart';

/// Uygulamanin tek veritabani baglantisi. Testlerde bellek ici veritabani ile override edilir.
/// Geri yuklemeden sonra `ref.invalidate(databaseProvider)` ile yeniden acilir;
/// tum ekranlar yeni baglantiyla kendiliginden yenilenir.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase()..startChangeTracking();
  ref.onDispose(db.close);
  return db;
});

final recordCountsProvider = StreamProvider.autoDispose<RecordCounts>(
  (ref) => ref.watch(databaseProvider).watchRecordCounts(),
);

/// Tek bir ayarin canli degeri.
final settingValueProvider = StreamProvider.autoDispose.family<String?, String>(
  (ref, key) => ref.watch(databaseProvider).settingsDao.watchValue(key),
);

final appPathsProvider =FutureProvider<AppPaths>((ref) => AppPaths.resolve());

final packageInfoProvider = FutureProvider<PackageInfo>((ref) => PackageInfo.fromPlatform());

final driveServiceProvider = Provider<DriveService>((ref) => DriveService());

final backupServiceProvider = FutureProvider<BackupService>((ref) async {
  final info = await ref.watch(packageInfoProvider.future);
  return BackupService(
    paths: await ref.watch(appPathsProvider.future),
    appVersion: '${info.version}+${info.buildNumber}',
  );
});
