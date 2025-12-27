# WayReader OCR

Lightweight Flutter app to capture book pages and extract text using on-device OCR.

This repository contains a simple mobile app intended for digitizing printed pages
— useful for personal archives, study notes, or lightweight scanning workflows.

**Objectives**

- Provide a minimal, easy-to-use interface for capturing page images.
- Extract selectable, editable text from captured images using an OCR engine.
- Offer a small, extensible codebase as a starting point for further OCR tooling.

**Features**

- Camera capture and image import
- On-device OCR processing (configurable engine)
- Simple export / copy workflow for recognized text
- Theme controller and basic settings

Getting started
---------------

Prerequisites

- Flutter SDK (stable channel, 3.x or newer recommended)
- Android Studio / Xcode and device or emulator for testing

Clone and run

```bash
git clone https://github.com/your-username/book_ocr.git
cd book_ocr
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
- `lib/pages/camera.dart` — camera UI and capture logic
- `lib/pages/ocr.dart` — OCR processing and results view
- `lib/pages/home.dart` — main dashboard
- `lib/pages/settings.dart` — app settings
- `lib/controller/theme.dart` — theme management
- `assets/` — bundled images and resources

Development notes
-----------------

- The app uses Flutter's plugin system for camera and platform integration. Replace or configure the OCR engine in `lib/pages/ocr.dart` as needed.
- Keep platform permissions updated in `android/app/src/main/AndroidManifest.xml` (camera, storage) and the equivalent iOS plist if adding iOS support.