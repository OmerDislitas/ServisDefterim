# Servis Defterim

Kombi bakımı ve tamiri yapan bir usta için geliştirilmiş, **internet olmadan çalışan** bir Android uygulaması.
Müşteriler, adresler, kombiler, yapılan servisler, randevular ve alacaklar tek bir yerde tutulur.
Periyodik bakım zamanı gelen kombiler otomatik olarak listelenir.

Uygulamanın dili Türkçedir. Sahada eldivenli ya da kirli elle kullanılacağı düşünülerek büyük dokunma alanlarıyla tasarlanmıştır.

> Ayrıntılı ürün ve teknik plan: [PLAN.md](PLAN.md)

---

## Özellikler

### Bugün ekranı
- Bugünkü randevular, bakımı gecikmiş ve bu hafta bakımı gelen kombiler
- Son yapılan servisler
- Son yedek bilgisi ve Drive yedeği hata kartı

### Müşteri, adres, kombi
- Bir müşterinin birden fazla adresi, bir adresin birden fazla kombisi olabilir. Kombi adrese bağlıdır, böylece kiracı değişse de kombinin geçmişi adreste kalır.
- Türkçe karakterlere duyarsız tek arama kutusu (ad, telefon, adres, marka, seri no)
- Tek dokunuşla arama ve WhatsApp, düzenlenebilir bakım hatırlatma mesajı şablonu

### Servis kaydı
- Bakım, arıza, montaj, kontrol ve diğer servis türleri
- Bakım kontrol listesi (ayarlardan düzenlenebilir), su basıncı, genleşme tankı, baca gazı CO değeri
- Kullanılan parçalar; ücret parça toplamından otomatik gelir, istenirse elle değiştirilir
- Ödeme durumu (tamamı alındı, alınmadı veya kısmi)
- Periyodik bakımda sonraki bakım tarihinin otomatik hesaplanması
- **Otomatik taslak:** Form yarıda kalırsa kaydedilir, uygulama tekrar açılınca devam edilebilir.

### Randevu ve takvim
- Randevu oluşturma, randevudan tek dokunuşla servis kaydı başlatma
- Aylık takvimde randevular, bakımı gelen kombiler ve yapılan servisler

### Alacaklar
- Müşteri bazında toplam borç ve borçlu servislerin listesi
- Hızlı ödeme alma

### Yedekleme
- Tüm veri ve fotoğraflar tek bir `.zip` dosyasına aktarılıp paylaşılabilir (`servis_defterim_yedek_YYYY-MM-DD_HHmm.zip`).
- Dosyadan geri yükleme: önce yedeğin içeriği gösterilir. Geri yüklemeden önce mevcut veri otomatik olarak güvenlik yedeğine alınır, hata olursa geri dönülür.
- **Google Drive yedeği:**
  - Sadece uygulamanın kendi oluşturduğu dosyalara erişir (`drive.file` kapsamı).
  - "Şimdi yedekle" ve otomatik yedek seçenekleri var. Otomatik yedek günde en fazla bir kez ve sadece veri değiştiyse alınır.
  - Drive'dan geri yükleme yapılabilir. Drive'da en yeni 15 yedek tutulur.

### Fotoğraflar
- Kombi ve servis kayıtlarına kameradan ya da galeriden (çoklu seçim) fotoğraf eklenir.
- Kaydederken küçültülür (uzun kenar en fazla 1600 px, JPEG kalite 80) ve küçük resim üretilir. Listelerde sadece küçük resim yüklenir.
- Tam ekran görüntüleyicide kaydırarak geçiş, iki parmakla yakınlaştırma ve silme yapılabilir.
- Fotoğraflar yedek zip'ine dahildir. Veritabanında sadece dosya adları tutulur.

### Bildirimler
- Bakımı yaklaşan kombiler için hatırlatma: bakım tarihinden seçilen gün kadar önce, seçilen saatte. Aynı güne düşen kombiler tek bildirimde toplanır.
- Randevudan 1 saat önce hatırlatma
- Bildirime dokununca ilgili ekran açılır (kombi, bakımı gelenler ya da randevu).
- Ayarlardan tamamen ya da tür bazında kapatılabilir; deneme bildirimi gönderilebilir.
- Sunucu ya da arka plan işi gerekmez: zamanlanmış yerel bildirimler kullanılır. Bildirimler telefon yeniden başlasa da korunur.

### Diğer
- Karanlık / aydınlık mod
- Silinen kayıtlar için "Geri al" (soft delete, bağlı kayıtlarla birlikte)

### Yol haritası
- [x] M0–M5: Veri katmanı, müşteri/cihaz, servis, randevu/takvim, alacaklar
- [x] M6: Dışa / içe aktarma, imzalı release APK
- [x] M7: Google Drive yedeği
- [x] M8: Bakım ve randevu bildirimleri
- [x] M9: Kombi ve servis fotoğrafları
- [ ] M10: Cilalama ve performans

---

## Teknolojiler

| Alan | Kullanılan |
|---|---|
| Framework | Flutter (yalnızca Android), Material 3 |
| State yönetimi | Riverpod 3 |
| Navigasyon | go_router (`StatefulShellRoute` ile alt menü) |
| Veritabanı | Drift (SQLite), reaktif `watch()` sorguları |
| Takvim | table_calendar |
| Yedekleme | archive (zip), share_plus, file_picker |
| Google Drive | google_sign_in v7, googleapis (Drive v3) |
| Bildirimler | flutter_local_notifications, timezone |
| Fotoğraf | image_picker, flutter_image_compress |
| Diğer | intl (tr_TR), url_launcher, connectivity_plus, uuid |

Firebase kullanılmaz; uygulama sunucusuz ve tamamen çevrimdışı çalışır.

---

## Mimari

```
lib/
  core/
    db/            Drift veritabanı, tablolar, DAO'lar, sağlayıcılar
    router/        go_router rotaları
    services/      Yedekleme, Google Drive, bildirim ve fotoğraf servisleri
    theme/         Material 3 tema (aydınlık / karanlık)
    utils/         Tarih, para, telefon, Türkçe arama, bakım hesapları
    strings.dart   Tüm arayüz metinleri
  features/        Ekranlar (today, calendar, customers, devices, services,
                   appointments, receivables, due_maintenance, photos, settings)
  shared/          Ortak bileşenler ve eylemler
test/              Birim, veritabanı ve widget testleri
drift_schemas/     Şema anlık görüntüleri (migration testleri için)
```

Veri modeliyle ilgili bazı kararlar:
- **Kimlikler ve silme:** Tüm kayıtlarda UUID kimlik, `createdAt` / `updatedAt` ve `deletedAt` (soft delete) bulunur. Bu yapı ileride senkronizasyona hazırlıktır.
- **Para:** Tutarlar her zaman tam sayı **kuruş** olarak saklanır.
- **Türkçe arama:** Arama için normalize edilmiş bir `searchText` kolonu tutulur (ı/i, ş/s, ğ/g …).
- **Ekranların güncellenmesi:** Listeler ve detay ekranları Drift stream'lerini izler. Bir kayıt değişince ilgili ekranlar kendiliğinden güncellenir.

---

## Geliştirme

Gereksinimler: Flutter (stable), Android SDK, Java 17.

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Drift tabloları değişirse kodu yeniden üretin:

```bash
dart run build_runner build
```

Şema değişikliklerinde `schemaVersion` artırılır ve migration yazılır:

```bash
dart run drift_dev make-migrations
```

### Release APK

1. Kendi imza anahtarınızı oluşturun.
2. `android/key.properties.example` dosyasını `android/key.properties` olarak kopyalayıp doldurun. Bu dosya ve anahtar **asla commit edilmez**.
3. APK'yı derleyin:

```bash
flutter build apk --release --split-per-abi
```

Çıktılar `build/app/outputs/flutter-apk/` klasörüne yazılır; çoğu telefon için `app-arm64-v8a-release.apk` kullanılır.

### Google Drive kurulumu

Drive yedeği için bir kerelik Google Cloud kurulumu gerekir. Adımlar [docs/GOOGLE_DRIVE_KURULUM.md](docs/GOOGLE_DRIVE_KURULUM.md) dosyasında.
Kendi kopyanızı derliyorsanız kendi Web istemci kimliğinizi `lib/core/services/drive_config.dart` dosyasına yazın. Ayrıca kendi imza SHA-1'inizi Cloud'a ekleyin.

---

## Geliştirici

**Ömer Faruk Dişlitaş**

- GitHub: [github.com/OmerDislitas](https://github.com/OmerDislitas)
- LinkedIn: [linkedin.com/in/ömer-faruk-dişlitaş-585645256](https://www.linkedin.com/in/%C3%B6mer-faruk-di%C5%9Flita%C5%9F-585645256)
