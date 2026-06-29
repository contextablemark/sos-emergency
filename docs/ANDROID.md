# Building SOS Emergency for Android

This project is scaffolded to build and run on Android. The deterministic
emergency UI and the AI-composed (GenUI/A2UI) surfaces work on device; the
**hands-free voice tab does not** (see [Known limitations](#known-limitations)).

## Prerequisites

- **Flutter SDK** matching `pubspec.yaml` (Dart `^3.12.1` / Flutter 3.44+).
- **Android Studio** with the Android SDK + an emulator or a physical device.
- On first open, Android Studio will create `android/local.properties` and point
  `flutter.sdk` / `sdk.dir` at your machine. That file is git-ignored on purpose
  — never commit it (it holds machine-specific paths).

The Gradle wrapper (`android/gradlew`, `gradle-wrapper.jar`) **is** committed, so
`./gradlew` and Android Studio's Gradle sync work immediately after pulling.

## Run

```sh
flutter pub get

# Emulator (10.0.2.2 = the host machine as seen from the emulator):
flutter run -d emulator-5554 --dart-define=BACKEND_BASE=http://10.0.2.2:8000

# Physical device on the same Wi-Fi (use your dev machine's LAN IP and add that
# IP to android/.../res/xml/network_security_config.xml):
flutter run -d <device-id> --dart-define=BACKEND_BASE=http://192.168.1.50:8000

# A deployed HTTPS backend needs no cleartext exception:
flutter run -d <device-id> --dart-define=BACKEND_BASE=https://your-backend.example.com
```

Build artifacts:

```sh
flutter build apk --debug      # quick install/test
flutter build apk --release    # signed with debug keys by default (see below)
flutter build appbundle        # Play Store
```

## Backend connectivity

The app talks to the FastAPI backend (`/backend`) for AI compose + voice. The
client reads the base URL from `--dart-define=BACKEND_BASE` (default
`http://localhost:8000`, which is **not** reachable from a device).

- `localhost` on a device means the *device*, not your dev machine. Use
  `10.0.2.2` (emulator), your LAN IP, `adb reverse tcp:8000 tcp:8000`, or a
  deployed URL.
- Android blocks plain `http://` by default. `network_security_config.xml`
  already whitelists `10.0.2.2`, `localhost`, and `127.0.0.1` for cleartext;
  add your LAN IP there for physical-device testing. HTTPS works with no change.

## Before publishing

- **Application ID** is `com.example.sos_emergency`
  ([app/build.gradle.kts](../android/app/build.gradle.kts)). Change it to your
  own reverse-DNS id before any store release.
- **Signing** — release builds currently use the **debug** keystore (so
  `flutter run --release` works out of the box). Add a real keystore +
  `key.properties` and a `signingConfig` before shipping. `key.properties` and
  `*.jks/*.keystore` are git-ignored.

## Known limitations

- **Voice tab is silent on Android.** Mic capture + TTS playback are a no-op stub
  on non-web targets ([voice_audio_io_stub.dart](../lib/data/voice_session/voice_audio_io_stub.dart));
  the real implementation only exists for web. To enable voice on device, wire a
  native mic plugin (e.g. `package:record`) into a non-web `voice_audio_io` impl
  and uncomment the `RECORD_AUDIO` / `MODIFY_AUDIO_SETTINGS` permissions in
  `AndroidManifest.xml`.
- The canonical layout is a **landscape tablet**; the app orientation-locks to
  landscape on device (`main.dart`).
