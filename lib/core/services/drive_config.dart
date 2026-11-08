/// Google Drive yapilandirmasi (PLAN 8.4).
abstract final class DriveConfig {
  /// Google Cloud Console'daki "Web application" turundeki OAuth istemci kimligi.
  /// google_sign_in v7 Android'de bunu `serverClientId` olarak ister.
  /// Bu bir gizli bilgi DEGILDIR (client secret degil); kodda durabilir.
  /// Bos ise Ayarlar'da "Drive yapilandirilmadi" gorunur.
  static const serverClientId = '624473750303-gdkjqejpq5gdjti62972gk8h2kh2u2v6.apps.googleusercontent.com';

  /// Kullanicinin Drive'inda yedeklerin tutuldugu klasor.
  static const folderName = 'Servis Defterim Yedekleri';

  /// Drive'da tutulan en fazla yedek sayisi; eskiler silinir.
  static const keepBackups = 15;

  /// Otomatik yedekler arasi en az sure.
  static const autoBackupInterval = Duration(hours: 24);

  static bool get isConfigured => serverClientId.isNotEmpty;
}
