# Kombi Servis — Proje Planı

> Bu doküman, Claude Code'un uygulamayı adım adım geliştirmesi için hazırlanmıştır.
> Önce bu dosyanın tamamını oku. Sonra **Bölüm 15'teki çalışma kurallarına** uyarak **Milestone 0**'dan başla.

---

## 1. Proje Özeti

Kombi tamiri ve bakımı yapan tek bir usta için, **tamamen internetsiz çalışan** bir Android uygulaması.

Usta şu ana kadar hiçbir kayıt tutmuyordu. Uygulama sıfırdan başlayacak, içe aktarılacak eski veri yok.

**Uygulamanın üç temel işi:**
1. Bir eve bakıma ya da tamire gidildiğinde müşteri, adres, kombi ve yapılan işi hızlıca kaydetmek
2. Periyodik bakımı gelen kombileri takvimde ve listelerde göstermek, ustaya hatırlatmak
3. Veriyi kaybetmemek: dosya olarak dışa/içe aktarma ve Google Drive yedeği

**Kullanıcı profili:** Teknik olmayan, sahada çalışan biri. Uygulama çoğu zaman müşterinin evinde, ayakta, tek elle ve kısıtlı zamanda kullanılacak. Sadelik ve hız her şeyden önemli.

**Bu ilk sürüm deneysel bir prototip.** Usta kullandıkça geri bildirim verecek, yeni özellikler sonra eklenecek. Ancak usta gerçek veri girmeye başladığı andan itibaren **veri kaybı kabul edilemez** (bkz. Bölüm 15, migration kuralı).

---

## 2. Kapsam

### Kapsamda (v1)
- Müşteri / adres / cihaz (kombi) kayıtları
- Servis kayıtları (bakım, arıza, montaj, kontrol), checklist, parçalar, ücret, ödeme
- Periyodik bakım tarihi takibi
- "Bugün" ana ekranı, takvim, bakımı gelenler listesi
- Randevular
- Alacak (veresiye) takibi ve sonradan ödeme alma
- Arama ve WhatsApp kısayolları, WhatsApp bakım hatırlatma mesajı şablonu
- Yerel bildirimler (bakım ve randevu hatırlatmaları)
- Veritabanını dışa aktarma (WhatsApp vb. ile paylaşma) ve içe aktarma
- Google Drive yedekleme ve Drive'dan geri yükleme
- Kombi ve servis fotoğrafları

### Kapsam dışı (şimdilik yapılmayacak)
- Fiş, fatura, PDF çıktısı
- Parça stok takibi
- Apartman/site yönetimi, toplu anlaşmalar, "bina" katmanı
- Çoklu kullanıcı, sunucu, senkronizasyon
- iOS
- Play Store yayını (dağıtım APK ile yapılacak)

Veri modeli, ileride çoklu kullanıcı ve senkronizasyon eklenebilecek şekilde tasarlanır (UUID id'ler, zaman damgaları, soft delete). Bu özellikler şimdi **yapılmaz**.

---

## 3. Teknoloji Yığını

| Alan | Seçim |
|---|---|
| Framework | Flutter (güncel stable), sadece Android hedefi |
| State yönetimi | Riverpod (`flutter_riverpod`) |
| Navigasyon | `go_router`, alt menü için `StatefulShellRoute.indexedStack` |
| Veritabanı | Drift (SQLite), `drift_flutter` |
| Tarih/yerelleştirme | `intl`, `flutter_localizations`, tr_TR |
| Takvim | `table_calendar` |
| Dış uygulamalar | `url_launcher` (telefon, WhatsApp) |
| Paylaşma | `share_plus` |
| Dosya seçme | `file_picker` |
| Zip | `archive` |
| Google Drive | `google_sign_in` (v7+ API), `googleapis` (Drive v3), `extension_google_sign_in_as_googleapis_auth` |
| Bildirimler | `flutter_local_notifications`, `timezone`, `flutter_timezone` |
| Fotoğraf | `image_picker`, `flutter_image_compress` |
| Yardımcılar | `uuid`, `path_provider`, `path`, `package_info_plus`, `connectivity_plus` |
| Dev | `drift_dev`, `build_runner`, `flutter_lints` |

**Notlar:**
- Paketlerin güncel stable sürümlerini kullan, pub.dev'de uyumluluğu kontrol et.
- `google_sign_in` v7 ile API köklü değişti (`GoogleSignIn.instance.initialize()`, `authenticate()`, `authorizationClient`). Eski v6 örneklerini kullanma, paketin güncel dokümantasyonunu ve örneğini takip et.
- Firebase **kullanılmayacak**.
- Bu listede olmayan bir paket eklemen gerekirse nedenini kullanıcıya açıkla.

---

## 4. Mimari ve Klasör Yapısı

Feature bazlı, katmanlı yapı:

```
lib/
  main.dart
  app.dart                     # MaterialApp.router, tema, locale
  core/
    db/
      database.dart            # Drift database, tablolar, migration stratejisi
      tables/                  # Tablo tanımları
      daos/                    # Feature bazlı DAO'lar
    router/app_router.dart
    theme/app_theme.dart
    strings.dart               # Tüm Türkçe UI metinleri tek yerde
    utils/
      text_normalize.dart      # Türkçe arama normalizasyonu
      phone.dart               # Telefon normalizasyonu, WhatsApp linki
      money.dart               # Kuruş <-> TL formatlama
      dates.dart               # Tarih yardımcıları
    services/
      backup_service.dart      # Zip oluşturma/okuma, doğrulama
      drive_service.dart       # Google Drive işlemleri
      notification_service.dart
      photo_service.dart
  features/
    today/                     # Bugün ekranı
    calendar/
    customers/                 # Müşteri listesi, detay, adres
    devices/                   # Cihaz detay/form
    services/                  # Servis kaydı formu ve detayı
    appointments/
    receivables/               # Alacaklar
    due_maintenance/           # Bakımı gelenler
    settings/                  # Ayarlar, yedekleme, checklist, şablon
  shared/widgets/              # Ortak widget'lar
test/
```

- UI → Riverpod provider'ları → Repository/DAO → Drift.
- Listeler ve detay ekranları Drift `watch()` stream'leri ile reaktif çalışır. Bir kayıt değişince ilgili ekranlar kendiliğinden güncellenir.
- Kod (sınıf, değişken, tablo adları) **İngilizce**, kullanıcıya görünen her metin **Türkçe** ve `strings.dart` içinde.

---

## 5. Veri Modeli

### Genel kurallar
- Tüm tablolarda `id TEXT` (UUID v4) primary key.
- Tüm tablolarda `createdAt`, `updatedAt`, `deletedAt` (nullable, soft delete).
- Sorgular varsayılan olarak `deletedAt IS NULL` filtresiyle çalışır.
- **Para her zaman tam sayı kuruş (`int`)** olarak tutulur, asla `double` kullanılmaz.
- **Sadece tarih olan alanlar** (bakım tarihi, garanti bitişi) saat dilimi kaymasına uğramamalı. `yyyy-MM-dd` text olarak ya da yerel gece yarısı olarak tutulmalı, seçilen yöntem tutarlı uygulanmalı.
- Arama yapılan tablolarda `searchText` kolonu bulunur (bkz. Bölüm 6.4).

### Tablolar

**customers**
| Kolon | Tip | Not |
|---|---|---|
| name | text | zorunlu |
| phone | text | zorunlu, sadece rakam olarak normalize edilip saklanır |
| phone2 | text? | |
| note | text? | |
| searchText | text | name + phone + phone2 normalize |

**addresses**: bir müşterinin birden fazla adresi olabilir
| Kolon | Tip | Not |
|---|---|---|
| customerId | text FK | |
| label | text? | "Ev", "Yazlık", "İşyeri" vb. |
| district | text? | ilçe |
| neighborhood | text? | mahalle |
| addressLine | text | açık adres, zorunlu |
| floor | text? | |
| apartmentNo | text? | |
| directions | text? | tarif ("market yanı, 3. bina") |
| searchText | text | |

**devices**: kombi. Müşteriye değil **adrese** bağlıdır (kiracı değişse de kombi ve geçmişi adreste kalır)
| Kolon | Tip | Not |
|---|---|---|
| addressId | text FK | |
| brand | text | zorunlu, otomatik tamamlamalı |
| model | text? | |
| serialNo | text? | |
| type | text enum | `condensing` (yoğuşmalı), `hermetic` (hermetik), `flue` (bacalı), `other` |
| installYear | int? | |
| warrantyEnd | date? | |
| maintenanceIntervalMonths | int | varsayılan ayarlardan (12) |
| nextMaintenanceDate | date? | bkz. Bölüm 6.1 |
| lastReminderSentAt | datetime? | WhatsApp hatırlatması en son ne zaman gönderildi |
| note | text? | |
| searchText | text | brand + model + serialNo |

**service_records**
| Kolon | Tip | Not |
|---|---|---|
| deviceId | text FK | |
| date | datetime | varsayılan: şimdi |
| type | text enum | `maintenance`, `repair`, `installation`, `inspection`, `other` |
| isPeriodicMaintenance | bool | bakım türünde varsayılan true |
| complaint | text? | müşteri şikayeti |
| errorCode | text? | kombinin gösterdiği hata kodu |
| workNotes | text? | yapılan işin serbest açıklaması |
| checklistItems | text (JSON) | işaretlenen maddelerin **metin olarak** anlık kopyası (şablon sonradan değişse de geçmiş bozulmaz) |
| waterPressureBar | real? | tesisat su basıncı |
| expansionTankBar | real? | genleşme tankı ön basıncı |
| flueCoPpm | int? | baca gazı CO |
| laborFee | int | kuruş |
| totalAmount | int | kuruş. Parça toplamı + işçilik olarak önerilir, elle değiştirilebilir |
| appointmentId | text? | randevudan başlatıldıysa |

**service_parts**
| Kolon | Tip | Not |
|---|---|---|
| serviceId | text FK | |
| name | text | daha önce girilen parça adlarından otomatik tamamlama |
| quantity | int | varsayılan 1 |
| unitPrice | int | kuruş |

**payments**
| Kolon | Tip | Not |
|---|---|---|
| serviceId | text FK | |
| amount | int | kuruş |
| date | datetime | |
| note | text? | |

Ödenen tutar = `SUM(payments.amount)`. Ödeme durumu hesaplanır, saklanmaz:
- ödenen ≥ toplam → **Ödendi**
- ödenen = 0 → **Veresiye**
- arada → **Kısmi**

**appointments**
| Kolon | Tip | Not |
|---|---|---|
| customerId | text FK | |
| deviceId | text? FK | |
| scheduledAt | datetime | |
| type | text enum | servis türleriyle aynı |
| status | text enum | `planned`, `done`, `cancelled` |
| note | text? | |

**photos**
| Kolon | Tip | Not |
|---|---|---|
| ownerType | text enum | `device`, `service` |
| ownerId | text | |
| fileName | text | uygulama `photos/` klasörüne göre **göreli** yol |
| thumbFileName | text | |

**checklist_templates**: bakım checklist'inin varsayılan maddeleri
| Kolon | Tip | Not |
|---|---|---|
| label | text | |
| sortOrder | int | |
| isActive | bool | |

**settings**: key-value. Anahtarlar:
- `defaultIntervalMonths` (12)
- `notificationHour` (9)
- `remindDaysBefore` (3)
- `whatsappTemplate`
- `driveAutoBackup` (bool)
- `driveAccountEmail`
- `lastBackupAt`
- `lastLocalChangeAt`

### İndeksler
`customers.searchText`, `customers.phone`, `devices.serialNo`, `devices.nextMaintenanceDate`, `service_records.deviceId + date`, `appointments.scheduledAt`, tüm FK kolonları.

### Varsayılan checklist maddeleri (seed)
Usta ayarlardan düzenleyebilir:
1. Genel görsel kontrol
2. Gaz kaçak kontrolü
3. Brülör temizliği
4. Yanma odası temizliği
5. Eşanjör temizliği / kireç kontrolü
6. Fan kontrolü ve temizliği
7. Baca / hava-duman kanalı kontrolü
8. Gaz basıncı ayarı
9. Tesisat su basıncı kontrolü
10. Genleşme tankı basınç kontrolü
11. Pompa kontrolü
12. Su filtresi temizliği
13. Yoğuşma sifonu temizliği
14. Ateşleme / iyonizasyon elektrot kontrolü
15. Emniyet sistemleri kontrolü
16. Baca gazı ölçümü

### Marka otomatik tamamlama (seed listesi, serbest metin girişi de serbest)
Demirdöküm, Vaillant, Baymak, Bosch, ECA, Buderus, Viessmann, Ariston, Immergas, Protherm, Airfel, Alarko, Ferroli, Baxi, Warmhaus. Daha önce girilen markalar da önerilere eklenir.

---

## 6. İş Kuralları

### 6.1 Periyodik bakım tarihi
- `devices.nextMaintenanceDate` saklanan, düzenlenebilir bir alandır.
- `isPeriodicMaintenance = true` olan bir servis kaydedildiğinde: `nextMaintenanceDate = servis tarihi + maintenanceIntervalMonths`. Bu tarih servis formunda **"Sonraki bakım"** alanında önceden hesaplanmış olarak gösterilir, usta isterse değiştirir.
- Yeni cihaz eklenirken son bakım tarihi bilinmiyorsa alan boş kalabilir. Bu cihazlar takvimde görünmez, "Bakım tarihi bilinmeyenler" olarak ayrıca listelenebilir.
- Bir servis kaydı silinir veya tarihi değişirse ustaya sonraki bakım tarihini güncellemek isteyip istemediği sorulur. Otomatik geri hesaplama yapılmaz.

### 6.2 Bakım durumu
- **Gecikmiş:** `nextMaintenanceDate < bugün`
- **Yaklaşan:** önümüzdeki 30 gün içinde
- **Bu hafta:** önümüzdeki 7 gün içinde

### 6.3 Telefon
- Kayıtta sadece rakamlar saklanır. `0532...` ve `+90 532...` girişlerinin ikisi de `5321234567` gibi tutarlı bir forma normalize edilir.
- Arama: `tel:` linki.
- WhatsApp: `https://wa.me/90XXXXXXXXXX?text=<url-encoded mesaj>`.
- Android 11+ paket görünürlüğü için `AndroidManifest.xml`'e gerekli `<queries>` (tel, https) eklenir.

### 6.4 Türkçe arama normalizasyonu
SQLite'ın `lower()` fonksiyonu Türkçe karakterleri doğru işlemez (İ/ı sorunu). Bu yüzden:
- Kayıt eklenirken/güncellenirken `searchText` üretilir: Türkçe kurallarına göre küçük harf (İ→i, I→ı), ardından aksan kaldırma (ç→c, ğ→g, ı→i, ö→o, ş→s, ü→u).
- Arama terimi aynı fonksiyondan geçirilip `LIKE '%terim%'` ile aranır. "sukru" yazınca "Şükrü" bulunur.
- Telefon araması için terimin rakam kısmı ayrıca `phone` kolonunda aranır.
- Tek arama kutusu müşteri adı, telefon, adres ve cihaz seri no/marka alanlarında arar, sonuçları müşteri bazında gruplar.
- Arama girdisi 150 ms debounce edilir.
- Veri hacmi küçük olacağı için (birkaç bin kayıt) FTS5 gerekmez. Performans yetersiz kalırsa sonradan eklenir.

### 6.5 WhatsApp hatırlatma şablonu
Varsayılan:
> Merhaba {ad}, kombinizin ({marka}) yıllık bakım zamanı geldi. Uygun olduğunuz bir gün ayarlayalım mı?

Değişkenler: `{ad}`, `{marka}`, `{tarih}`. Şablon ayarlardan düzenlenebilir. Mesaj butonuna basıldığında `lastReminderSentAt` güncellenir ve listede "3 gün önce hatırlatıldı" gibi gösterilir.

### 6.6 Silme
- Soft delete. Silme işlemi onay ister ve "Geri al" snackbar'ı gösterir.
- Müşteri silinirse bağlı adres, cihaz, servis, ödeme ve randevular da soft delete edilir.

---

## 7. Ekranlar ve Akışlar

### Navigasyon
Alt menü (4 sekme, `StatefulShellRoute.indexedStack` ile canlı tutulur, sekme geçişi anlık):
1. **Bugün**
2. **Takvim**
3. **Müşteriler**
4. **Alacaklar**

Ayarlar, Bugün ekranının app bar'ından açılır. **"Yeni Servis"** butonu (büyük FAB) Bugün, Takvim ve Müşteriler sekmelerinde bulunur.

### 7.1 Bugün (ana ekran)
Yukarıdan aşağıya:
- **Yedek uyarısı:** Son yedek 7 günden eskiyse ya da hiç yedek yoksa dikkat çekici bir kart ("Son yedek 9 gün önce, şimdi yedekle"). Yedek varsa küçük bir satır: "Son yedek: dün 18:40".
- **Bugünkü randevular:** saat, müşteri, adres (ilçe/mahalle). Dokununca randevu detayı, "Servisi başlat" butonu.
- **Gecikmiş bakımlar:** kırmızı vurgulu, sayı rozeti.
- **Bu hafta bakımı gelenler**
- **Son servisler** (son 5)

Her müşteri/cihaz satırında hızlı aksiyonlar: **Ara**, **WhatsApp hatırlat**, **Randevu oluştur**, **Servis başlat**.

Bakım bölümlerinde "Tümünü gör" → **Bakımı Gelenler** ekranı: filtreler (Gecikmiş / Bu ay / Gelecek ay / Tarihi bilinmeyen), aynı hızlı aksiyonlar.

### 7.2 Takvim
- `table_calendar` aylık görünüm, Türkçe, hafta pazartesi başlar.
- Gün işaretleri: **turuncu** = bakım zamanı, **kırmızı** = gecikmiş (bugünden önceki günlerde bakımı yapılmamış), **mavi** = randevu, **yeşil** = o gün yapılmış servis.
- Güne dokununca altta o günün listesi açılır.
- "Bu güne randevu ekle" butonu.
- Ay/hafta görünümü arasında geçiş.

### 7.3 Müşteriler
- Üstte arama kutusu (Bölüm 6.4), altta liste (varsayılan sıralama: son servis tarihi, alternatif: ada göre).
- Liste satırı: ad, telefon, ilk adresin ilçe/mahallesi, cihaz sayısı.
- "Yeni müşteri" butonu.

### 7.4 Müşteri detayı
- Ad, telefon(lar), not; büyük **Ara** ve **WhatsApp** butonları
- Adresler. Her adresin altında o adresteki cihazlar (marka/model, bakım durumu rozeti)
- Servis geçmişi (tüm cihazlar, tarih sırasıyla)
- Toplam alacak (varsa)
- Düzenle / sil

### 7.5 Cihaz detayı
- Marka, model, seri no, tip, kurulum yılı, garanti, fotoğraflar
- Bakım kartı: sonraki bakım tarihi, durum rozeti, periyot. Tarihi elle değiştirme.
- Servis geçmişi zaman çizelgesi
- Bu cihaz için "Servis başlat" butonu (müşteri/adres/cihaz önceden seçili gelir)

### 7.6 Yeni Servis Kaydı (en kritik ekran)
Usta sahada, müşterinin yanında bu formu dolduracak. Hızlı ve hataya dayanıklı olmalı.

**Giriş noktaları:**
- FAB'dan: boş başlar
- Cihaz detayından: müşteri/adres/cihaz seçili gelir
- Randevudan: müşteri/cihaz seçili gelir, kayıt randevuya bağlanır

**Yapı:** Tek kaydırılabilir sayfa, bölümler halinde.

1. **Müşteri:** Arama ile seç ya da "+ Yeni müşteri" (sadece ad ve telefon zorunlu, aynı sayfada açılan kısa form). Telefon girilince aynı numaralı müşteri varsa uyarı ve "Bu müşteriyi seç" önerisi.
2. **Adres:** Müşterinin tek adresi varsa otomatik seçilir. Yoksa listeden seç ya da yeni ekle.
3. **Cihaz:** Adreste tek cihaz varsa otomatik seçilir. Yoksa listeden seç ya da yeni ekle (marka otomatik tamamlama, tip seçimi chip'lerle).
   - Seçimi tamamlanan bölümler tek satırlık özet kartına dönüşür ("Ahmet Yılmaz · Başakşehir · Demirdöküm Nitromix"), dokununca değiştirilebilir.
4. **Servis bilgisi:**
   - Tür: chip'ler (Bakım / Arıza / Montaj / Kontrol / Diğer)
   - Tarih: varsayılan şimdi
   - Arıza türünde şikayet ve hata kodu alanları öne çıkar
   - Bakım türünde checklist görünür: tümünü seç/temizle, maddeler büyük dokunma alanlı
   - Ölçümler (opsiyonel, katlanmış bölüm): su basıncı, genleşme tankı basıncı, baca gazı CO. Sayısal klavye.
   - Yapılan iş notu (serbest metin)
   - Fotoğraf ekle
5. **Parçalar:** Satır ekle (ad otomatik tamamlama, adet, birim fiyat), satır toplamı.
6. **Ücret ve ödeme:**
   - İşçilik
   - Toplam (parça + işçilik otomatik, elle değiştirilebilir)
   - **Alınan ödeme:** hızlı butonlar "Tamamı", "Hiç (veresiye)", ya da tutar gir
7. **Sonraki bakım:** Periyodik bakımsa hesaplanmış tarih gösterilir, değiştirilebilir. "Bu periyodik bakım değil" anahtarı.
8. **Kaydet** (sabit alt buton).

**Kurallar:**
- Zorunlu alanlar: müşteri, adres, cihaz, tür. Diğer her şey opsiyonel.
- Form durumu **otomatik taslak** olarak kaydedilir. Uygulama kapansa ya da telefon gelse bile veri kaybolmaz. Uygulama açılınca yarım taslak varsa "Yarım kalan servis kaydına devam et" sorulur.
- Geri tuşunda veri girilmişse "Taslak olarak sakla / Sil" sorulur.
- Kayıt sonrası servis detay ekranına gidilir ve "Kaydedildi" snackbar'ı gösterilir.

### 7.7 Servis detayı
Tüm bilgiler, ödeme geçmişi, kalan alacak, **"Ödeme al"** butonu, düzenle/sil.

### 7.8 Randevu formu
Müşteri (ve opsiyonel cihaz), tarih-saat, tür, not. Randevu listesi Bugün ve Takvim ekranlarında görünür. Randevudan servis başlatılıp kaydedilince randevu `done` olur.

### 7.9 Alacaklar
- Üstte toplam alacak.
- Müşteri bazında gruplu liste: müşteri, toplam borç, en eski borç tarihi.
- Müşteriye dokununca borçlu servisler. Her biri için **"Ödeme al"**: tutar (varsayılan kalan tutar), tarih → `payments` kaydı.
- Müşteri satırında Ara/WhatsApp kısayolu.

### 7.10 Ayarlar
- **Yedekleme** (Bölüm 8):
  - Yedeği dışa aktar ve paylaş
  - Google Drive: bağlan / bağlı hesap / bağlantıyı kes
  - Drive'a şimdi yedekle
  - Otomatik Drive yedeği (aç/kapa)
  - Drive'dan geri yükle
  - Dosyadan geri yükle
- **Bakım:** varsayılan periyot (ay)
- **Bildirimler:** bildirim saati, kaç gün önce hatırlatılsın
- **Checklist maddeleri:** ekle, sil, sırala, pasifleştir
- **WhatsApp mesaj şablonu**
- **Hakkında:** uygulama sürümü, veritabanı şema sürümü, kayıt sayıları
- **Sadece debug build'de:** "Örnek veri oluştur" ve "Tüm veriyi sil"

---

## 8. Yedekleme (Dışa / İçe Aktarma ve Drive)

Bu bölüm uygulamanın en kritik güvenilirlik özelliği. İnternet olmadığı için veri tek telefonda yaşıyor.

### 8.1 Yedek dosya formatı
Tek bir zip dosyası: `kombi_yedek_YYYY-MM-DD_HHmm.zip`

```
manifest.json
kombi.db
photos/
  <uuid>.jpg
  <uuid>_thumb.jpg
```

`manifest.json` içeriği:
```json
{
  "app": "kombi_servis",
  "appVersion": "1.0.0+5",
  "schemaVersion": 3,
  "createdAt": "2026-11-08T18:40:00+03:00",
  "counts": { "customers": 124, "devices": 160, "services": 310 }
}
```

- Veritabanının tutarlı bir kopyası `VACUUM INTO '<geçici yol>'` ile alınır. Açık veritabanı dosyası doğrudan kopyalanmaz (WAL dosyaları nedeniyle tutarsız olabilir).
- Zip oluşturma ağır bir iş. UI'ı dondurmaması için arka plan isolate'inde (`Isolate.run` / `compute`) yapılır, ilerleme göstergesiyle.

### 8.2 Dışa aktar ve paylaş
"Yedeği dışa aktar" → zip oluşturulur → `share_plus` paylaşım menüsü açılır. Usta dosyayı WhatsApp'tan kendine, Faruk'a ya da başka bir yere gönderir. Başarılı paylaşım sonrası `lastBackupAt` güncellenir.

### 8.3 İçe aktar (geri yükleme)
1. Dosya seçilir (`file_picker`) ya da Drive'dan indirilir.
2. Zip açılır, `manifest.json` doğrulanır:
   - `app` alanı eşleşmeli
   - `schemaVersion` mevcut sürümden **büyükse** reddedilir ("Bu yedek uygulamanın daha yeni bir sürümüyle alınmış, önce uygulamayı güncelleyin")
   - Küçükse kabul edilir, açıldıktan sonra Drift migration'ları çalışır
3. **Önizleme ve onay:** "Bu yedekte 124 müşteri, 310 servis kaydı var (8 Kasım 2026, 18:40). Mevcut tüm verilerin yerini alacak. Devam edilsin mi?"
4. Mevcut veriden otomatik olarak **yerel bir güvenlik yedeği** alınır (uygulama klasöründe, son 3 tanesi tutulur). Geri yükleme başarısız olursa bundan dönülür.
5. Veritabanı bağlantısı kapatılır, `kombi.db` ve `photos/` değiştirilir, veritabanı yeniden açılır, tüm provider'lar yenilenir.
6. Bildirimler yeniden planlanır (Bölüm 9).

### 8.4 Google Drive
- **Kapsam:** sadece `https://www.googleapis.com/auth/drive.file`. Uygulama yalnızca kendi oluşturduğu dosyalara erişir. Bu kapsam "hassas olmayan" kategoride olduğu için Google uygulama doğrulaması gerekmez.
- Yedekler kullanıcının Drive'ında **"Kombi Servis Yedekleri"** klasörüne yüklenir. Usta bu dosyaları Drive'da görebilir, bilgisayara indirebilir.
- **Akış:** Ayarlar → "Google Drive'a bağlan" → Google hesabı seçimi → izin → bağlı hesap e-postası gösterilir.
- **Drive'a şimdi yedekle:** zip oluştur → yükle → `lastBackupAt` güncelle.
- **Drive'dan geri yükle:** klasördeki yedekleri tarih ve boyutla listele → seçileni indir → Bölüm 8.3 akışı.
- **Otomatik yedek:** Arka plan işi (workmanager) **kullanılmayacak**, çünkü arka plan isolate'inde Google yetkilendirmesi güvenilir değil. Bunun yerine **fırsatçı ön plan yedeği**: uygulama açıldığında ya da ön plana geldiğinde şu koşulların hepsi sağlanıyorsa sessizce Drive'a yedek atılır:
  - otomatik yedek açık
  - son Drive yedeği 24 saatten eski
  - son yedekten bu yana veri değişmiş (`lastLocalChangeAt > lastBackupAt`)
  - internet bağlantısı var (`connectivity_plus`)
- Otomatik yedekler için Drive'da son **15** yedek tutulur, daha eskiler silinir.
- Hatalar (internet yok, yetki süresi doldu) kullanıcıyı engellemez. Bugün ekranındaki yedek kartında gösterilir ("Drive yedeği başarısız: tekrar bağlanın").
- Google Cloud tarafındaki kurulum (proje, Drive API, OAuth ekranı, client ID'ler) **kullanıcı tarafından elle yapılır**. Bu adıma gelince kullanıcıya gerekli adımları ve SHA-1 parmak izini nasıl alacağını açıkla. Android'de `google_sign_in` v7'nin gerektirdiği yapılandırmayı (Android OAuth client'ları için paket adı + SHA-1, gerekiyorsa `serverClientId` olarak Web client ID) paketin güncel dokümantasyonuna göre belirt.

---

## 9. Bildirimler

- `flutter_local_notifications` ile **zamanlanmış yerel bildirimler**. Arka plan işi gerekmez.
- **Bakım bildirimi:** Bakımı yaklaşan cihazlar için, bakım tarihinden `remindDaysBefore` gün önce, `notificationHour` saatinde. Aynı güne düşen birden fazla cihaz tek bildirimde gruplanır ("Bu hafta 4 kombinin bakımı var: Ahmet Yılmaz, Mehmet Demir…").
- **Randevu bildirimi:** randevudan 1 saat önce.
- **Senkronizasyon stratejisi:** Uygulama her açıldığında ve ilgili veri her değiştiğinde tüm bildirimler iptal edilip önümüzdeki 60 gün için yeniden planlanır (en yakın 100 bildirimle sınırlı).
- **İzinler:** Android 13+ için `POST_NOTIFICATIONS` izni ilk açılışta değil, kullanıcı ilk kez bir bakım tarihi oluşturduğunda ya da ayarlardan istenir. Exact alarm izni **istenmez**, `inexactAllowWhileIdle` kullanılır (birkaç dakikalık sapma sorun değil).
- Telefon yeniden başlatıldığında bildirimlerin korunması için paketin boot receiver yapılandırması eklenir.
- Bildirime dokununca ilgili ekran açılır (Bakımı Gelenler ya da randevu detayı).

---

## 10. Fotoğraflar

- Kamera ya da galeriden (`image_picker`).
- Kaydederken küçültülür: uzun kenar en fazla 1600 px, JPEG kalite 80. Ayrıca 300 px'lik thumbnail üretilir.
- Uygulamanın documents klasöründe `photos/` altında saklanır. Veritabanında **sadece göreli dosya adı** tutulur (geri yüklemede yol değişebilir).
- Listelerde ve detaylarda sadece thumbnail yüklenir. Tam boyut sadece fotoğrafa dokununca açılan görüntüleyicide.
- Kayıt silinince fotoğraf dosyaları da silinir (soft delete edilen kayıtlar için dosyalar kalır, kalıcı temizlik ileride).

---

## 11. Performans Gereksinimleri

"Hızlı olacak" ana gereksinimlerden biri. Hedefler (orta segment Android cihazda, **profile/release modda**):

| Ölçüt | Hedef |
|---|---|
| Soğuk açılış → Bugün ekranı | < 1.5 sn |
| Alt menü sekme geçişi | anlık (sekmeler canlı tutulur) |
| Sayfa geçişleri | takılmasız, 60 fps |
| 2.000+ kayıtlı listede kaydırma | takılmasız |
| Arama sonucu (yazarken) | < 100 ms |

**Uygulanacaklar:**
- Açılışta sadece veritabanı açılır ve Bugün ekranının sorguları çalışır. Bildirim senkronizasyonu ve otomatik yedek kontrolü ilk frame çizildikten sonra.
- Tüm listeler `ListView.builder` / `SliverList`.
- Gerekli sorgularda indeks, N+1 sorgu yok. Liste ekranları için join'li tek sorgu.
- Ağır işler (zip, resim sıkıştırma) isolate'te.
- Sayfa geçiş animasyonları kısa ve sade.
- `const` constructor'lar, gereksiz rebuild'lerden kaçınma (Riverpod `select`).
- Debug build'de **"Örnek veri oluştur"**: ~300 müşteri, ~400 adres, ~500 cihaz, ~1.500 servis, ~200 randevu. Performans bu veriyle test edilir.

---

## 12. UI / UX İlkeleri

- Material 3, açık tema varsayılan (karanlık tema opsiyonel, sistem ayarına uyar).
- Tüm arayüz Türkçe. Tarihler "8 Kasım 2026, Pazar" formatında, para "1.250,00 ₺" formatında.
- **Büyük dokunma alanları:** minimum 48 dp, birincil butonlar 56 dp. Usta eldivenli ya da kirli elle kullanabilir.
- Yüksek kontrast, okunaklı yazı boyutları, sistem yazı boyutu ayarına uyum.
- Sık yapılan her işlem ana ekrandan en fazla 2 dokunuş uzakta olmalı.
- Gereksiz onay dialogları yok (sadece silme ve geri yükleme gibi geri dönüşü zor işlemlerde).
- Sayısal alanlarda sayısal klavye, telefon alanında telefon klavyesi.
- Boş durumlar yol göstermeli: Müşteri listesi boşken "Henüz müşteri yok, ilk servis kaydını oluştur" ve buton.
- Hata mesajları teknik olmamalı ("Drive'a bağlanılamadı. İnternet bağlantınızı kontrol edin.").

---

## 13. Build ve Dağıtım

- **applicationId:** `com.faruk.kombiservis` (yer tutucu, kullanıcı değiştirebilir). **Uygulama adı:** "Kombi Servis" (yer tutucu).
- `minSdk`: 24. `targetSdk`: Flutter'ın güncel varsayılanı.
- **Release imzalama:**
  - Keystore oluşturma komutunu kullanıcıya ver, kendin oluşturma ya da şifre belirleme
  - `android/key.properties` + `build.gradle(.kts)` imza yapılandırması
  - `key.properties` ve `*.jks` / `*.keystore` dosyaları **`.gitignore`'da** olmalı, asla commit edilmemeli
  - Kullanıcıya keystore'u birden fazla güvenli yerde yedeklemesi gerektiğini hatırlat. Kaybolursa güncellemeler eski sürümün üstüne kurulamaz.
- **Build:** `flutter build apk --release --split-per-abi` → ustaya `app-arm64-v8a-release.apk` gönderilir.
- **Sürümleme:** `pubspec.yaml`'da `version: x.y.z+build`. Her APK'da build numarası mutlaka artırılır (aksi halde güncelleme kurulmaz).
- Güncellemeler aynı imzayla eskisinin üstüne kurulur, veriler korunur.

---

## 14. Test Stratejisi

### Otomatik testler (`flutter test`)
- **Unit:** bakım tarihi hesaplama, ödeme durumu hesaplama, telefon normalizasyonu ve WhatsApp linki, Türkçe arama normalizasyonu, kuruş/TL formatlama, manifest doğrulama, WhatsApp şablon doldurma.
- **Veritabanı:** `NativeDatabase.memory()` ile DAO testleri (CRUD, soft delete cascade, bakımı gelenler sorgusu, alacak sorgusu, arama).
- **Migration:** İlk APK ustaya verildikten sonra her şema değişikliğinde Drift'in şema dump + migration test aracı (`drift_dev make-migrations` / schema tests) kullanılır.
- **Yedekleme roundtrip:** örnek veri → zip oluştur → boş veritabanına geri yükle → kayıt sayıları ve örnek kayıtlar eşleşmeli.
- **Widget:** Yeni servis formunda zorunlu alan doğrulaması, toplam hesaplama, taslak kaydetme.

### Manuel cihaz testi
Cihaz testini kullanıcı (Faruk) yapar ve ekran görüntüsü paylaşır. Her milestone sonunda kullanıcıya **madde madde ne test edeceğini** yaz.

---

## 15. Claude Code Çalışma Kuralları

1. **Milestone sırasına uy.** Bir milestone bitmeden diğerine geçme.
2. Her milestone sonunda:
   - `flutter analyze` → 0 sorun
   - `flutter test` → tüm testler geçmeli
   - Kısa bir özet: ne yapıldı, ne eksik kaldı, kararlar
   - Kullanıcı için madde madde manuel test listesi
   - Git commit (anlamlı mesajla)
   - Kullanıcının cihaz testi ve onayı beklenir
3. **Migration kuralı:** Ustaya gerçek kullanım için ilk APK verildiği andan itibaren (Milestone 6 sonrası) her şema değişikliği `schemaVersion` artışı ve test edilmiş bir migration ile yapılır. Veritabanını silip yeniden oluşturmak **yasak**.
4. Kullanıcıya görünen tüm metinler Türkçe ve `strings.dart` içinde. Kod İngilizce.
5. Para her zaman kuruş (`int`).
6. Bu planla çelişen ya da planda belirtilmemiş önemli bir karar gerekirse kendi başına karar verme, kullanıcıya sor.
7. Gizli bilgiler (keystore, şifreler, OAuth client secret) asla commit edilmez.
8. Gereksiz soyutlama ve aşırı mühendislikten kaçın. Bu tek kullanıcılı, deneysel bir prototip.

---

## 16. Milestone'lar

### M0 — Proje iskeleti
- `flutter create` (applicationId, uygulama adı), paketler, `flutter_lints`
- Klasör yapısı (Bölüm 4), tema, Türkçe locale
- `go_router` + alt menülü shell (4 sekme, boş ekranlar), Ayarlar rotası
- `.gitignore` (keystore, key.properties dahil), git init, ilk commit

### M1 — Veri katmanı
- Tüm Drift tabloları, indeksler, DAO'lar
- `searchText` üretimi, normalizasyon yardımcıları, para ve tarih yardımcıları
- Checklist ve marka seed verisi, varsayılan ayarlar
- Debug "Örnek veri oluştur" ve "Tüm veriyi sil"
- Unit ve veritabanı testleri

### M2 — Müşteri, adres, cihaz
- Müşteri listesi + arama, müşteri detayı, müşteri formu
- Adres formu, cihaz formu (marka otomatik tamamlama), cihaz detayı
- Ara / WhatsApp butonları (Bölüm 6.3, `<queries>` dahil)
- Soft delete + geri al

### M3 — Servis kaydı
- Yeni servis formu (Bölüm 7.6), tüm giriş noktaları
- Parçalar, ücret, ilk ödeme, sonraki bakım tarihi güncelleme
- Otomatik taslak
- Servis detayı, düzenleme, silme
- Ayarlar: checklist maddeleri düzenleme, varsayılan periyot

### M4 — Bugün, bakımı gelenler, randevular, takvim
- Bugün ekranı (yedek kartı şimdilik "hiç yedek yok" durumunu gösterir)
- Bakımı Gelenler ekranı, WhatsApp hatırlatma şablonu (+ ayarı), `lastReminderSentAt`
- Randevu formu ve randevudan servis başlatma
- Takvim ekranı

### M5 — Alacaklar
- Alacaklar ekranı, müşteri bazında borçlar, "Ödeme al"
- Müşteri ve servis detayında alacak gösterimi

### M6 — Dışa / içe aktarma
- Zip yedek oluşturma (`VACUUM INTO`, manifest, isolate), paylaş
- Dosyadan geri yükleme (doğrulama, önizleme, güvenlik yedeği, yeniden açma)
- Bugün ekranındaki yedek kartı, `lastBackupAt` / `lastLocalChangeAt` takibi
- Roundtrip testi
- Release imzalama yapılandırması ve ilk APK
- **→ Bu noktadan sonra usta gerçek veri girmeye başlayabilir. Migration kuralı devreye girer.**

### M7 — Google Drive
- Kullanıcıya Google Cloud kurulum rehberi (Bölüm 8.4)
- Bağlan / bağlantıyı kes, Drive'a yedekle, Drive'dan listele ve geri yükle
- Fırsatçı otomatik yedek, eski yedekleri temizleme, hata gösterimi

### M8 — Bildirimler
- Bakım ve randevu bildirimleri, yeniden planlama stratejisi, izin akışı
- Bildirim ayarları, bildirime dokununca yönlendirme

### M9 — Fotoğraflar
- Cihaz ve servis fotoğrafları, sıkıştırma, thumbnail, görüntüleyici
- Yedek zip'ine dahil etme (format zaten destekliyor), roundtrip testine ekleme

### M10 — Cilalama ve performans
- Örnek veriyle profile modda performans kontrolü (Bölüm 11 hedefleri), darboğazların giderilmesi
- Boş durumlar, hata mesajları, erişilebilirlik kontrolü
- Final release APK

---

## 17. Gelecek Fikirleri (şimdi yapılmayacak)
- Telefon rehberinden müşteri seçme
- Adrese navigasyon (Google Maps linki), adres konumu kaydetme
- Aylık kazanç / iş raporu
- Marka bazlı hata kodu rehberi
- Müşteriye WhatsApp'tan servis özeti gönderme
- Apartman/site toplu anlaşmaları
- Çoklu usta ve senkronizasyon
