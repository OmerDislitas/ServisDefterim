/// Kullaniciya gorunen tum Turkce metinler.
abstract final class S {
  static const appName = 'Servis Defterim';

  // Alt menu
  static const tabToday = 'Bugün';
  static const tabCalendar = 'Takvim';
  static const tabCustomers = 'Müşteriler';
  static const tabReceivables = 'Alacaklar';

  // Ortak
  static const newService = 'Yeni Servis';
  static const settings = 'Ayarlar';
  static const comingSoon = 'Bu bölüm yakında eklenecek.';
  static const cancel = 'Vazgeç';
  static const delete = 'Sil';

  // Bos durumlar (gecici)
  static const todayEmpty = 'Bugünkü randevular ve bakımı gelen kombiler burada görünecek.';
  static const calendarEmpty = 'Bakım ve randevu takvimi burada görünecek.';
  static const customersEmpty = 'Henüz müşteri yok, ilk servis kaydını oluştur.';
  static const receivablesEmpty = 'Henüz alacak yok.';
  static const settingsEmpty = 'Yedekleme, bakım ve bildirim ayarları burada olacak.';
  static const newServiceEmpty = 'Servis kayıt formu burada olacak.';

  // Goreli gunler
  static const today = 'bugün';
  static const yesterday = 'dün';
  static const tomorrow = 'yarın';
  static String daysAgo(int n) => '$n gün önce';
  static String daysLater(int n) => '$n gün sonra';

  // Cihaz tipi
  static const deviceCondensing = 'Yoğuşmalı';
  static const deviceHermetic = 'Hermetik';
  static const deviceFlue = 'Bacalı';
  static const other = 'Diğer';

  // Servis turu
  static const serviceMaintenance = 'Bakım';
  static const serviceRepair = 'Arıza';
  static const serviceInstallation = 'Montaj';
  static const serviceInspection = 'Kontrol';

  // Randevu durumu
  static const apptPlanned = 'Planlandı';
  static const apptDone = 'Yapıldı';
  static const apptCancelled = 'İptal';

  // Odeme durumu
  static const paymentPaid = 'Ödendi';
  static const paymentUnpaid = 'Veresiye';
  static const paymentPartial = 'Kısmi';

  // Bakim durumu
  static const maintOverdue = 'Gecikmiş';
  static const maintThisWeek = 'Bu hafta';
  static const maintUpcoming = 'Yaklaşan';
  static const maintLater = 'İleride';
  static const maintUnknown = 'Tarih bilinmiyor';

  // WhatsApp
  static const defaultWhatsappTemplate =
      'Merhaba {ad}, kombinizin ({marka}) yıllık bakım zamanı geldi. '
      'Uygun olduğunuz bir gün ayarlayalım mı?';

  // Seed: varsayilan bakim checklist'i (PLAN 5)
  static const defaultChecklist = [
    'Genel görsel kontrol',
    'Gaz kaçak kontrolü',
    'Brülör temizliği',
    'Yanma odası temizliği',
    'Eşanjör temizliği / kireç kontrolü',
    'Fan kontrolü ve temizliği',
    'Baca / hava-duman kanalı kontrolü',
    'Gaz basıncı ayarı',
    'Tesisat su basıncı kontrolü',
    'Genleşme tankı basınç kontrolü',
    'Pompa kontrolü',
    'Su filtresi temizliği',
    'Yoğuşma sifonu temizliği',
    'Ateşleme / iyonizasyon elektrot kontrolü',
    'Emniyet sistemleri kontrolü',
    'Baca gazı ölçümü',
  ];

  // Seed: marka otomatik tamamlama
  static const brandSuggestions = [
    'Demirdöküm', 'Vaillant', 'Baymak', 'Bosch', 'ECA', 'Buderus', 'Viessmann', 'Ariston',
    'Immergas', 'Protherm', 'Airfel', 'Alarko', 'Ferroli', 'Baxi', 'Warmhaus',
  ];

  // Debug araclari
  static const debugSection = 'Geliştirici (sadece debug)';
  static const debugGenerateSample = 'Örnek veri oluştur';
  static const debugGenerateSampleHint = '~300 müşteri, 500 cihaz, 1.500 servis, 200 randevu ekler';
  static const debugWipeAll = 'Tüm veriyi sil';
  static const debugWipeAllHint = 'Müşteri, cihaz, servis, ödeme ve randevuları kalıcı olarak siler';
  static const debugWipeConfirmTitle = 'Tüm veri silinsin mi?';
  static const debugWipeConfirmBody = 'Bu işlem geri alınamaz. Ayarlar ve checklist korunur.';
  static const debugSampleDone = 'Örnek veri oluşturuldu';
  static const debugWipeDone = 'Tüm veri silindi';
  static String recordCounts(int customers, int devices, int services, int appointments) =>
      '$customers müşteri · $devices cihaz · $services servis · $appointments randevu';
}
