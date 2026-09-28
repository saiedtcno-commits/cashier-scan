# Cashier Scan

**Cashier Scan** is a minimal, fast, offline-first Arabic Flutter cashier app for Android.

## Included

- Arabic RTL UI.
- Continuous camera scanning.
- EAN-13, EAN-8, UPC, Code 128 and QR support through `mobile_scanner`.
- Local SQLite product database.
- Automatic invoice quantity increment when a barcode is scanned again.
- Duplicate scan protection for about one second.
- Beep/click + light haptic feedback + green scan flash.
- Unknown barcode flow with immediate product registration.
- Invoice + / - quantity controls and swipe-to-delete.
- Live grand total in EGP (`ج.م`).
- Flashlight control.
- New invoice button.
- Product search by name or barcode.
- Add / edit / delete products.

## Requirements

- Flutter stable with Dart 3.12+.
- Android SDK and Android Studio for local Android builds.

## Local run

```bash
flutter create . --platforms=android --project-name cashier_scan --org com.cashier --overwrite
flutter pub get
flutter analyze
flutter run
```

## Build APK locally

```bash
flutter build apk --release
```

APK output:

`build/app/outputs/flutter-apk/app-release.apk`

## GitHub Actions

The repository includes `.github/workflows/build-apk.yml`.

Push the project to a GitHub repository with a `main` branch, then open:

**Actions → Build APK → Run workflow**

The workflow generates the Android scaffolding, restores the app source, runs `flutter analyze`, builds the release APK, and uploads it as an artifact named **cashier-scan-apk**.

## Data

Products are stored locally in SQLite. The app does not require an internet connection for scanning, invoicing, or product management.

## Scope

The current version intentionally does **not** include reports, printing, sales history, discounts, cloud sync, users, or online services.
