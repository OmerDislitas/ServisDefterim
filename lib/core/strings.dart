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
  static const fee = 'Ücret';
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

  // Bugun
  static const backupNone = 'Henüz yedek alınmadı';
  static String backupOld(int days) => 'Son yedek $days gün önce';
  static const backupNowHint = 'Verilerinizi kaybetmemek için yedek alın.';
  static const backupNow = 'Şimdi yedekle';
  static String backupLast(String when) => 'Son yedek: $when';
  static const todayAppointments = 'Bugünkü randevular';
  static const noAppointmentsToday = 'Bugün randevu yok';
  static const overdueMaintenance = 'Gecikmiş bakımlar';
  static const thisWeekMaintenance = 'Bu hafta bakımı gelenler';
  static const recentServices = 'Son servisler';
  static const seeAll = 'Tümünü gör';
  static String moreItems(int n) => '+$n daha';
  static const nothingDue = 'Bu hafta bakımı gelen kombi yok';

  // Bakimi gelenler
  static const dueMaintenance = 'Bakımı Gelenler';
  static const filterOverdue = 'Gecikmiş';
  static const filterThisWeek = 'Bu hafta';
  static const filterThisMonth = 'Bu ay';
  static const filterNextMonth = 'Gelecek ay';
  static const filterUnknown = 'Tarihi bilinmeyen';
  static const noDueDevices = 'Bu filtrede kombi yok';
  static const remindWhatsapp = 'WhatsApp hatırlat';
  static const createAppointment = 'Randevu oluştur';
  static String remindedAgo(String when) => '$when hatırlatıldı';

  // Randevular
  static const appointment = 'Randevu';
  static const newAppointment = 'Yeni randevu';
  static const editAppointment = 'Randevuyu düzenle';
  static const appointmentDate = 'Tarih';
  static const appointmentTime = 'Saat';
  static const deviceOptional = 'Kombi (isteğe bağlı)';
  static const noDeviceSelected = 'Belirtilmedi';
  static const startServiceFromAppointment = 'Servisi başlat';
  static const cancelAppointment = 'Randevuyu iptal et';
  static const replanAppointment = 'Tekrar planla';
  static const openServiceRecord = 'Servis kaydını aç';
  static const appointmentCancelled = 'Randevu iptal edildi';
  static const appointmentDeleted = 'Randevu silindi';
  static const deleteAppointmentTitle = 'Randevu silinsin mi?';
  static const deleteAppointmentBody = 'Bu randevu silinecek.';
  static const addAppointmentForDay = 'Bu güne randevu ekle';

  // Takvim
  static const formatMonth = 'Ay';
  static const formatWeek = 'Hafta';
  static const legendMaintenance = 'Bakım';
  static const legendOverdue = 'Gecikmiş';
  static const legendAppointment = 'Randevu';
  static const legendService = 'Servis';
  static const dayEmpty = 'Bu günde kayıt yok';
  static const maintenanceDue = 'Bakımı gelenler';
  static const servicesDone = 'Yapılan servisler';

  // Alacaklar
  static const totalReceivable = 'Toplam alacak';
  static String receivableCustomers(int n) => '$n müşteri';
  static String oldestDebt(String date, String ago) => 'En eski borç: $date ($ago)';
  static String debtServiceCount(int n) => '$n borçlu servis';
  static const debtServices = 'Borçlu servisler';
  static const noReceivables = 'Alacak yok. Tüm servislerin ödemesi alınmış.';

  // Yedekleme
  static const backup = 'Yedekleme';
  static const exportBackup = 'Yedeği dışa aktar ve paylaş';
  static const exportBackupHint = 'WhatsApp ile kendinize ya da başka bir yere gönderin';
  static const restoreFromFile = 'Dosyadan geri yükle';
  static const restoreFromFileHint = 'Daha önce aldığınız bir yedek dosyasını seçin';
  static const backupPreparing = 'Yedek hazırlanıyor…';
  static const backupShareSubject = 'Servis Defterim yedeği';
  static const backupShared = 'Yedek paylaşıldı';
  static const backupFailed = 'Yedek oluşturulamadı. Telefonda yer olduğundan emin olun.';
  static const backupInvalidFile = 'Bu dosya geçerli bir Servis Defterim yedeği değil.';
  static const backupWrongApp = 'Bu yedek başka bir uygulamaya ait.';
  static const backupNewerVersion =
      'Bu yedek uygulamanın daha yeni bir sürümüyle alınmış, önce uygulamayı güncelleyin.';
  static const restoreConfirmTitle = 'Yedek geri yüklensin mi?';
  static String restoreConfirmBody(int customers, int services, String date) =>
      'Bu yedekte $customers müşteri, $services servis kaydı var ($date).\n\n'
      'Mevcut tüm verilerin yerini alacak. Devam edilsin mi?';
  static const restore = 'Geri yükle';
  static const restoring = 'Geri yükleniyor…';
  static const restoreDone = 'Yedek geri yüklendi';
  static const restoreFailed =
      'Geri yükleme başarısız oldu. Verileriniz önceki haline döndürüldü.';
  static const ok = 'Tamam';

  // Google Drive
  static const googleDrive = 'Google Drive';
  static const driveNotConfigured = 'Google Drive henüz yapılandırılmadı';
  static const driveNotConfiguredHint = 'Kurulum tamamlanınca buradan bağlanabileceksiniz.';
  static const driveConnect = "Google Drive'a bağlan";
  static const driveConnectHint = 'Yedekler Drive\'ınızda "Servis Defterim Yedekleri" klasörüne yüklenir';
  static String driveConnectedAs(String email) => 'Bağlı hesap: $email';
  static const driveDisconnect = 'Bağlantıyı kes';
  static const driveDisconnectTitle = 'Drive bağlantısı kesilsin mi?';
  static const driveDisconnectBody = "Drive'daki yedekler silinmez. Otomatik yedek kapanır.";
  static const driveConnected = "Google Drive'a bağlandı";
  static const driveAutoBackup = 'Otomatik Drive yedeği';
  static const driveAutoBackupHint = 'Uygulama açıldığında, günde en fazla bir kez, veri değiştiyse';
  static const driveBackupNow = "Drive'a şimdi yedekle";
  static String driveLastBackup(String when) => 'Son Drive yedeği: $when';
  static const driveNoBackupYet = 'Henüz Drive yedeği yok';
  static const driveUploading = "Drive'a yükleniyor…";
  static const driveBackupDone = "Drive'a yedeklendi";
  static const driveRestore = "Drive'dan geri yükle";
  static const driveRestoreHint = "Drive'daki yedeklerden birini seçin";
  static const driveLoadingList = 'Yedekler getiriliyor…';
  static const driveNoBackups = "Drive'da yedek bulunamadı";
  static const driveDownloading = 'Yedek indiriliyor…';
  static const driveConnectFailed =
      "Google Drive'a bağlanılamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.";
  static const driveNetworkError = "Drive'a bağlanılamadı. İnternet bağlantınızı kontrol edin.";
  static const driveReconnect = 'Drive yedeği başarısız: tekrar bağlanın';
  static const driveFailed = 'Drive işlemi başarısız oldu. Daha sonra tekrar deneyin.';
  static const goToSettings = 'Ayarlar';
  static const about = 'Hakkında';
  static const settingsAppearance = 'Görünüm';
  static const darkMode = 'Karanlık mod';
  static const darkModeHint = 'Kapalıyken aydınlık tema kullanılır';
  static const developer = 'Geliştirici';
  static const developerName = 'Ömer Faruk Dişlitaş';
  static const linkedin = 'LinkedIn';
  static const github = 'GitHub';
  static const linkFailed = 'Bağlantı açılamadı';
  static String appVersion(String v) => 'Uygulama sürümü: $v';
  static String schemaVersion(int v) => 'Veritabanı şema sürümü: $v';

  // WhatsApp sablonu
  static const whatsappTemplate = 'WhatsApp mesaj şablonu';
  static const whatsappTemplateHint = 'Bakım hatırlatmasında gönderilecek mesaj';
  static const whatsappTemplateVars = 'Değişkenler: {ad} müşteri adı, {marka} kombi markası, {tarih} bakım tarihi';
  static const resetToDefault = 'Varsayılana dön';
  static const preview = 'Önizleme';

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
  static const clearSearch = 'Aramayı temizle';

  // Fotograflar (M9)
  static const photos = 'Fotoğraflar';
  static const addPhoto = 'Fotoğraf ekle';
  static const takePhoto = 'Kamerayla çek';
  static const pickFromGallery = 'Galeriden seç';
  static const noPhotos = 'Henüz fotoğraf yok';
  static const photoSaving = 'Fotoğraf kaydediliyor…';
  static const photoFailed = 'Fotoğraf eklenemedi';
  static const photoDeleteTitle = 'Fotoğraf silinsin mi?';
  static const photoDeleteBody = 'Fotoğraf kalıcı olarak silinir.';
  static const photoDeleted = 'Fotoğraf silindi';
  static String photoCount(int i, int n) => '$i / $n';
  static String photosRecovered(int n) => '$n fotoğraf kaydedildi';

  // Bildirimler (M8)
  static const settingsNotifications = 'Bildirimler';
  static const notificationsEnabled = 'Bildirimler';
  static const notificationsEnabledHint = 'Kapalıyken hiçbir hatırlatma gönderilmez';
  static const maintenanceNotifications = 'Bakım hatırlatmaları';
  static const appointmentNotifications = 'Randevu hatırlatmaları';
  static const appointmentNotificationsHint = 'Randevudan 1 saat önce';
  static const notificationHour = 'Bildirim saati';
  static const remindDaysBefore = 'Kaç gün önce hatırlatılsın';
  static String daysBeforeValue(int n) => n == 0 ? 'Bakım günü' : '$n gün önce';
  static String maintenanceNotificationsHint(int days, String hour) =>
      'Bakım tarihinden ${daysBeforeValue(days).toLowerCase()}, saat $hour';
  static const notificationPermissionOff = 'Bildirim izni kapalı';
  static const notificationPermissionOffHint = 'İzin vermek için dokunun';
  static const notificationPermissionDenied =
      'Bildirim izni verilmedi. Telefonun Ayarlar > Uygulamalar > Servis Defterim bölümünden açabilirsiniz.';
  static const sendTestNotification = 'Deneme bildirimi gönder';
  static const testNotificationTitle = 'Servis Defterim';
  static const testNotificationBody = 'Bildirimler çalışıyor.';
  static const channelMaintenance = 'Bakım hatırlatmaları';
  static const channelMaintenanceDesc = 'Bakımı yaklaşan kombiler';
  static const channelAppointments = 'Randevu hatırlatmaları';
  static const channelAppointmentsDesc = 'Randevudan 1 saat önce';
  static const maintenanceReminderTitle = 'Bakım hatırlatması';
  static String maintenanceWhen(int daysBefore, String date) => switch (daysBefore) {
        0 => 'bugün',
        1 => 'yarın ($date)',
        _ => '$daysBefore gün sonra ($date)',
      };
  static String maintenanceSingle(String customer, String brand, String when) =>
      '$customer – $brand: bakım $when.';
  static String maintenanceGroupTitle(int count) => '$count kombinin bakımı yaklaşıyor';
  static String maintenanceGroup(String when, int count, String names) =>
      '${when[0].toUpperCase()}${when.substring(1)} $count kombinin bakımı var: $names';
  static String appointmentReminderTitle(String time) => 'Randevu: $time';
  static const settingsMessages = 'Mesajlar';

  // Bos durumlar
  static const customersEmpty = 'Henüz müşteri yok, ilk servis kaydını oluştur.';

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
