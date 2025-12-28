# WayReader OCR

Lightweight Flutter app to capture book pages and extract text using on-device OCR. It is intended for organzing images/scans - useful for personal archives, study notes, or lightweight scanning workflows.

**Features**

- Camera capture and image import
- On-device OCR processing
- Simple export / copy workflow for recognized text
- Theme controller and basic settings

<div>
  <img width="135" height="300" alt="Screenshot_1766938992" src="https://github.com/user-attachments/assets/841a2883-2909-422b-9273-e1258ae38e71" />
  <img width="135" height="300" alt="Screenshot_1766938977" src="https://github.com/user-attachments/assets/30d488d5-cbb3-42a9-9bc1-d5b08c647909" />
</div>

Getting started
---------------

Prerequisites

- Flutter SDK (stable channel, 3.x or newer recommended)
- Android Studio / Xcode and device or emulator for testing

Clone and run

```bash
git clone https://github.com/Hundway/wayreader-ocr.git
cd wayreader-ocr
flutter pub get
flutter run
```

If you target Android specifically, ensure `local.properties` points to your SDK or run from Android Studio.

Usage
-----

- Open the app and grant camera permissions when prompted.
- Use the `Camera` view to capture a page or import an image.
- Navigate to the `OCR` page to process the captured image and view extracted text.
- Use the `Settings` page to adjust theme and OCR-related options.

Project structure
-----------------

- `lib/main.dart` — app entry point and routing
- `lib/pages/home.dart` — main dashboard
- `lib/pages/camera.dart` — camera UI and capture logic
- `lib/pages/ocr.dart` — OCR processing and results view
- `lib/pages/settings.dart` — app settings
- `lib/controller/theme.dart` — theme management
- `assets/` — bundled images and resources
