import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Uygulamanin dosya yollari. Veritabani ve fotograflar belgeler klasorunde yasar.
class AppPaths {
  const AppPaths({required this.documentsDir, required this.tempDir});

  final String documentsDir;
  final String tempDir;

  static const dbFileName = 'servis_defterim.sqlite';

  String get dbFile => p.join(documentsDir, dbFileName);

  /// Fotograflar (M9). Veritabaninda bu klasore gore goreli ad tutulur.
  String get photosDir => p.join(documentsDir, 'photos');

  /// Geri yukleme oncesi otomatik alinan guvenlik yedekleri (son 3).
  String get safetyBackupsDir => p.join(documentsDir, 'safety_backups');

  /// Paylasim icin olusturulan yedekler (gecici).
  String get exportsDir => p.join(tempDir, 'exports');

  static Future<AppPaths> resolve() async => AppPaths(
        documentsDir: (await getApplicationDocumentsDirectory()).path,
        tempDir: (await getTemporaryDirectory()).path,
      );
}
