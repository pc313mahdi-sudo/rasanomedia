# رسایار | RASAYAR

Flutter app foundation for Android and iOS. Persian-first RTL UI.

## Version 0.3 – Story editor milestone
- Dedicated 9:16 story canvas
- Live Persian text editing and preview
- Six gradient backgrounds and six text colors
- Text size, alignment, shadow, and outline controls
- PNG rendering from the canvas at 3x pixel ratio
- Save PNG to the device gallery (`gal`)
- Share PNG through the platform share sheet (`share_plus`)

## Still planned
- Import custom TTF/OTF fonts and use them in the canvas
- Import PNG/JPG assets and add/move/scale/rotate layers
- Save and reopen editable projects
- More typography effects, gradients, masks, blend modes, and templates
- Full testing on physical Android and iOS devices

## Requirements
- Flutter stable, Dart 3.3+
- Android Studio / Android SDK for Android builds
- macOS + Xcode for iOS builds

## Run
```bash
flutter pub get
flutter run
```

## Build Android
```bash
flutter build apk --release
```

## Build iOS (macOS only)
```bash
flutter build ios --release
```

Note: This source milestone has not been compiled in this environment because Flutter/Dart SDK are not installed here. Run `flutter pub get` and test on target devices before release.
