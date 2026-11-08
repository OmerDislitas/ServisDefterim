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
  static const editService = 'Servisi düzenle';
  static const serviceDetail = 'Servis';
  static const saved = 'Kaydedildi';
  static const change = 'Değiştir';
  static const customer = 'Müşteri';
  static const address = 'Adres';
  static const searchCustomerHint = 'Müşteri ara: ad, telefon, adres';
  static const selectCustomer = 'Müşteri seçin';
  static const selectAddress = 'Adres seçin';
  static const selectDevice = 'Kombi seçin';
  static const selectServiceType = 'Servis türünü seçin';
  static const selectThisCustomer = 'Bu müşteriyi seç';
  static const addNewCustomer = 'Yeni müşteri';
  static const addNewAddress = 'Yeni adres';
  static const addNewDevice = 'Yeni kombi';
  static const serviceInfo = 'Servis bilgisi';
  static const serviceType = 'Tür';
  static const serviceDate = 'Tarih';
  static const complaint = 'Müşteri şikayeti';
  static const errorCode = 'Hata kodu';
  static const checklist = 'Yapılan kontroller';
  static const selectAll = 'Tümünü seç';
  static const clearAll = 'Temizle';
  static const measurements = 'Ölçümler';
  static const waterPressure = 'Su basıncı (bar)';
  static const expansionTank = 'Genleşme tankı (bar)';
  static const flueCo = 'Baca gazı CO (ppm)';
  static const workNotes = 'Yapılan iş';
  static const parts = 'Parçalar';
  static const addPart = 'Parça ekle';
  static const partName = 'Parça';
  static const quantity = 'Adet';
  static const unitPrice = 'Birim fiyat';
  static const removePart = 'Parçayı kaldır';
  static const feeAndPayment = 'Ücret ve ödeme';
  static const laborFee = 'İşçilik';
  static const partsTotal = 'Parça toplamı';
  static const total = 'Toplam';
  static const autoTotal = 'Otomatik hesapla';
  static const paymentReceived = 'Alınan ödeme';
  static const payFull = 'Tamamı';
  static const payNone = 'Hiç (veresiye)';
  static const paymentTooHigh = 'Ödeme toplamdan fazla olamaz';
  static const invalidAmount = 'Geçerli bir tutar girin';
  static const periodicMaintenance = 'Periyodik bakım';
  static const periodicMaintenanceHint = 'Kapatırsanız kombinin sonraki bakım tarihi değişmez';
  static const paid = 'Ödenen';
  static const remaining = 'Kalan';
  static const payments = 'Ödemeler';
  static const noPayments = 'Henüz ödeme yok';
  static const takePayment = 'Ödeme al';
  static const paymentAmount = 'Tutar';
  static const paymentDate = 'Ödeme tarihi';
  static const paymentSaved = 'Ödeme kaydedildi';
  static const paymentDeleted = 'Ödeme silindi';
  static const deletePaymentTitle = 'Ödeme silinsin mi?';
  static const deletePaymentBody = 'Bu ödeme silinirse kalan tutar artar.';
  static const serviceDeleted = 'Servis kaydı silindi';
  static const deleteServiceTitle = 'Servis kaydı silinsin mi?';
  static const deleteServiceBody = 'Parçaları ve ödemeleri de silinecek.';
  static String updateNextMaintenanceTo(String date) => 'Kombinin sonraki bakım tarihini $date yap';
  static const updateNextMaintenanceTitle = 'Sonraki bakım tarihi güncellensin mi?';
  static String updateNextMaintenanceBody(String date) =>
      'Servis tarihi değişti. Kombinin sonraki bakım tarihi $date olarak güncellensin mi?';
  static const keep = 'Değiştirme';
  static const update = 'Güncelle';
  static const draftTitle = 'Yarım kalan servis kaydı';
  static const draftResumeBody = 'Tamamlanmamış bir servis kaydınız var. Devam etmek ister misiniz?';
  static const draftContinue = 'Devam et';
  static const draftDiscard = 'Sil';
  static const draftStartNew = 'Yeni kayıt başlat';
  static const leaveFormTitle = 'Kayıt tamamlanmadı';
  static const leaveFormBody = 'Girdiğiniz bilgiler taslak olarak saklansın mı?';
  static const keepDraft = 'Taslak olarak sakla';
  static const discardChangesTitle = 'Değişiklikler kaydedilmedi';
  static const discardChangesBody = 'Çıkarsanız yaptığınız değişiklikler kaybolur.';
  static const discard = 'Çık';
  static const stayHere = 'Vazgeç';
  static const appointmentLinked = 'Randevudan başlatıldı';

  // Ayarlar
  static const settingsMaintenance = 'Bakım';
  static const defaultInterval = 'Varsayılan bakım periyodu';
  static String monthsValue(int n) => '$n ay';
  static const checklistItems = 'Checklist maddeleri';
  static const checklistItemsHint = 'Bakımda işaretlenecek kontroller';
  static const addChecklistItem = 'Madde ekle';
  static const editChecklistItem = 'Maddeyi düzenle';
  static const checklistItemLabel = 'Madde';
  static const checklistInactiveHint = 'Kapalı maddeler servis formunda görünmez';
  static const otherSettingsLater = 'Yedekleme, bildirim ve WhatsApp ayarları sonraki aşamalarda eklenecek.';

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
