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
  static const edit = 'Düzenle';
  static const save = 'Kaydet';
  static const undo = 'Geri al';
  static const call = 'Ara';
  static const whatsapp = 'WhatsApp';
  static const notSet = 'Belirtilmedi';
  static const unknownDate = 'Bilinmiyor';
  static const recordNotFound = 'Kayıt bulunamadı. Silinmiş olabilir.';
  static const requiredField = 'Bu alan zorunlu';
  static const invalidPhone = 'Geçerli bir telefon numarası girin';
  static const invalidNumber = 'Geçerli bir sayı girin';
  static const invalidYear = 'Geçerli bir yıl girin';
  static const callFailed = 'Arama başlatılamadı';
  static const whatsappFailed = 'WhatsApp açılamadı';
  static const loadFailed = 'Bir sorun oluştu, tekrar deneyin.';

  // Musteriler
  static const newCustomer = 'Yeni müşteri';
  static const editCustomer = 'Müşteriyi düzenle';
  static const customerName = 'Ad soyad';
  static const phone = 'Telefon';
  static const phone2 = 'İkinci telefon';
  static const note = 'Not';
  static const searchHint = 'Ad, telefon, adres ya da kombi ara';
  static const noSearchResults = 'Aramaya uygun müşteri bulunamadı';
  static const sort = 'Sırala';
  static const sortByLastService = 'Son servise göre';
  static const sortByName = 'Ada göre';
  static const receivable = 'Alacak';
  static const customerDeleted = 'Müşteri silindi';
  static String deleteCustomerTitle(String name) => '$name silinsin mi?';
  static const deleteCustomerBody = 'Adresleri, kombileri, servis kayıtları ve randevuları da silinecek.';
  static String duplicatePhone(String name) => 'Bu numara $name adına kayıtlı.';
  static const goToCustomer = 'Müşteriye git';

  // Adresler
  static const addresses = 'Adresler';
  static const addAddress = 'Adres ekle';
  static const newAddress = 'Yeni adres';
  static const editAddress = 'Adresi düzenle';
  static const addressOptional = 'Adres (isteğe bağlı)';
  static const addressLabel = 'Adres adı';
  static const addressLabels = ['Ev', 'Yazlık', 'İşyeri'];
  static const district = 'İlçe';
  static const neighborhood = 'Mahalle';
  static const addressLine = 'Açık adres';
  static const addressLineHint = 'Sokak, bina no';
  static const floor = 'Kat';
  static const apartmentNo = 'Daire';
  static const directions = 'Tarif';
  static const directionsHint = 'Örn. market yanı, 3. bina';
  static const noAddresses = 'Henüz adres yok';
  static const addressDeleted = 'Adres silindi';
  static const deleteAddressTitle = 'Adres silinsin mi?';
  static const deleteAddressBody = 'Bu adresteki kombiler ve servis kayıtları da silinecek.';
  static String floorShort(String v) => 'Kat $v';
  static String apartmentShort(String v) => 'Daire $v';

  // Kombiler
  static const device = 'Kombi';
  static const addDevice = 'Kombi ekle';
  static const newDevice = 'Yeni kombi';
  static const editDevice = 'Kombiyi düzenle';
  static const brand = 'Marka';
  static const model = 'Model';
  static const serialNo = 'Seri no';
  static const deviceType = 'Tip';
  static const installYear = 'Kurulum yılı';
  static const warrantyEnd = 'Garanti bitişi';
  static const warrantyActive = 'Garanti devam ediyor';
  static const warrantyExpired = 'Garanti bitti';
  static const maintenanceInterval = 'Bakım periyodu (ay)';
  static const maintenance = 'Bakım';
  static const nextMaintenance = 'Sonraki bakım';
  static const fromLastMaintenance = 'Son bakım tarihinden hesapla';
  static const changeDate = 'Tarihi değiştir';
  static const clearDate = 'Tarihi temizle';
  static String intervalMonths(int n) => '$n ayda bir';
  static String reminderSent(String when) => 'WhatsApp hatırlatması: $when';
  static const noDevicesAtAddress = 'Bu adreste kayıtlı kombi yok';
  static const deviceDeleted = 'Kombi silindi';
  static const deleteDeviceTitle = 'Kombi silinsin mi?';
  static const deleteDeviceBody = 'Bu kombinin servis kayıtları da silinecek.';
  static const startService = 'Servis başlat';

  // Servisler
  static const serviceHistory = 'Servis geçmişi';
  static const noServices = 'Henüz servis kaydı yok';

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
