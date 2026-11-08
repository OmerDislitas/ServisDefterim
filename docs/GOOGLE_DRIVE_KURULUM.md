# Google Drive Kurulumu (bir kerelik)

Uygulamanın Drive'a yedek atabilmesi için Google Cloud'da bir proje gerekir.
Firebase kullanılmaz. Uygulama yalnızca **kendi oluşturduğu dosyalara** erişir
(`drive.file` kapsamı); bu "hassas olmayan" bir kapsam olduğu için Google'ın
uygulama doğrulaması gerekmez.

## Gerekli bilgiler

| Bilgi | Değer |
|---|---|
| Paket adı | `com.faruk.servisdefterim` |
| Release SHA-1 (ustaya giden APK) | `48:79:81:B2:4D:3E:96:B5:17:2D:FC:B3:66:36:28:93:84:D5:39:21` |
| Debug SHA-1 (geliştirme, bu bilgisayar) | `AE:1E:DA:9E:A8:9D:3E:2C:68:3D:DF:A2:1E:16:D9:72:81:39:F0:EF` |

SHA-1'leri yeniden almak için:

```bash
keytool -list -v -keystore C:\Users\omer\servis-defterim-imza.jks -alias servisdefterim
keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android
```

## Adımlar

1. **Proje:** <https://console.cloud.google.com> → üstteki proje seçici → **Yeni proje** →
   ad: `Servis Defterim` → Oluştur. Sonra bu projeyi seçin.

2. **Drive API'yi aç:** Menü → **APIs & Services → Library** → "Google Drive API" → **Enable**.

3. **OAuth izin ekranı:** Menü → **Google Auth Platform** (eski adı "OAuth consent screen") → **Get started**:
   - App name: `Servis Defterim`, User support email: kendi e-postanız
   - Audience: **External**
   - Contact information: kendi e-postanız → kabul edip **Create**

4. **Kapsam:** Google Auth Platform → **Data access** → **Add or remove scopes** →
   `https://www.googleapis.com/auth/drive.file` işaretleyin → **Update** → **Save**.

5. **Yayınla:** Google Auth Platform → **Audience** → **Publish app** → onaylayın (durum: *In production*).
   > "Testing" durumunda bırakılırsa izinler 7 günde bir sona erer ve otomatik yedek
   > haftada bir "tekrar bağlanın" hatası verir. Sadece `drive.file` kullanıldığı için
   > yayınlamak doğrulama gerektirmez.

6. **Android istemcisi (release):** Google Auth Platform → **Clients** → **Create client** →
   Application type: **Android** → Name: `Servis Defterim Android` →
   Package name: `com.faruk.servisdefterim` → SHA-1: *release SHA-1* → **Create**.

7. **Android istemcisi (debug):** Aynı adımı tekrarlayın, Name: `Servis Defterim Android Debug`,
   SHA-1: *debug SHA-1*. (Bilgisayardan `flutter run` ile denerken gerekir.)

8. **Web istemcisi:** **Create client** → Application type: **Web application** →
   Name: `Servis Defterim Web` → (yönlendirme adresi gerekmez) → **Create**.
   Açılan pencerede **Client ID**'yi kopyalayın (`....apps.googleusercontent.com`).
   > Client ID gizli bilgi değildir. **Client secret'a ihtiyaç yok, kimseyle paylaşmayın.**

9. Client ID'yi `lib/core/services/drive_config.dart` içindeki `serverClientId`
   alanına yazın ve yeni APK derleyin. (Yapıldı: sürüm 1.0.1+2.)

## Sorun giderme

- **Hesap seçildikten sonra bağlantı iptal oluyor / "bağlanılamadı":** Neredeyse her zaman
  yanlış SHA-1 ya da paket adıdır. APK'nın imzası ile Cloud'daki SHA-1 aynı olmalı
  (debug APK → debug SHA-1, release APK → release SHA-1).
- **Değişiklikler hemen yansımayabilir:** Cloud tarafındaki ayarların etkinleşmesi
  birkaç dakika sürebilir.
- **Drive'da yedekler:** "Servis Defterim Yedekleri" klasöründe görünür; buradan
  bilgisayara indirilebilir. Uygulama en yeni 15 yedeği tutar.
