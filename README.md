# Servis Defterim

Kombi bakım ve tamiri yapan tek bir usta için, tamamen internetsiz çalışan Android uygulaması.
Ayrıntılı plan: [PLAN.md](PLAN.md)

## Geliştirme

```bash
flutter pub get
dart run build_runner build   # Drift kod üretimi (M1'den itibaren)
flutter analyze
flutter test
flutter run
```

Release APK:

```bash
flutter build apk --release --split-per-abi
```

Ustaya `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` gönderilir.
Her APK'da `pubspec.yaml` içindeki build numarası (`+N`) artırılmalıdır.
