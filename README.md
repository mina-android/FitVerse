<div align="center">

<img src="assets/icons/splash_icon.png" alt="FitVerse Logo" width="112" height="112" />

# FitVerse

[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=flat&logo=android&logoColor=white)](https://developer.android.com) [![Framework](https://img.shields.io/badge/Framework-Flutter-02569B?style=flat&logo=flutter&logoColor=white)](https://flutter.dev) [![Release](https://img.shields.io/badge/Release-v1.0.0-blue?style=flat)](https://github.com/mina-android/FitVerse/releases) [![License](https://img.shields.io/badge/License-GPL--3.0-black?style=flat)](LICENSE)

<p align="center">
  A mobile fitness coaching and workout tracking platform combining hardware biometric telemetry, real-time accelerometer motion coaching, and Gemini-assisted training analysis.
</p>

</div>

---

## Navigation

[Features](#features) &bull; [Screenshots](#screenshots) &bull; [Downloads](#downloads) &bull; [Self Building & Local Setup](#self-building--local-setup) &bull; [Contribution](#contribution) &bull; [About the Developer](#about-the-developer) &bull; [Donate](#donate) &bull; [License](#license)

---

## Features

### Core Capabilities

- **Exercise Library & Routine Planning**: Over 90 structured exercises categorized by targeted muscle anatomy, equipment requirements, and movement biomechanics with custom workout builder routines.
- **Motion Sensor Repetition Tracking**: Real-time rep counting and cadence tracking utilizing device accelerometer sensors when wearable hardware is unavailable.
- **Biometric Health Connect Integration**: Native Android Health Connect synchronization collecting steps, resting heart rate, active calorie expenditure, and sleep phase telemetry.
- **Contextual Gemini AI Coach**: Integrates user training volume, recovery metrics, and recorded fatigue indicators directly into Gemini API prompts to produce personalized training adjustments.
- **Rest & Interval Timers**: Background audio-signaled interval timers providing countdown chimes and set-break pacing.

### Architecture & Data Handling

- **Local-First with Cloud Sync**: Interfaces render directly against local on-device SQLite caches to ensure instant UI responsiveness, subsequently synchronizing state to Cloud Firestore when network connectivity is established.
- **Authentication**: Optional Google Firebase Authentication supporting credentialed multi-device session portability.
- **Data Privacy**: Biometric measurements remain on the device and are passed to AI services only within ephemeral session requests when analysis is explicitly requested.

---

## Screenshots

<table width="100%" border="0" cellspacing="0" cellpadding="4">
  <tr>
    <td width="33.33%" align="center" valign="top">
      <img src="screenshots/onboarding.png" alt="Onboarding Flow" width="100%" />
    </td>
    <td width="33.33%" align="center" valign="top">
      <img src="screenshots/sign_in.png" alt="Authentication" width="100%" />
    </td>
    <td width="33.33%" align="center" valign="top">
      <img src="screenshots/profile_setup.png" alt="Profile Setup" width="100%" />
    </td>
  </tr>
  <tr>
    <td width="33.33%" align="center" valign="top">
      <img src="screenshots/home.png" alt="FitVerse Dashboard" width="100%" />
    </td>
    <td width="33.33%" align="center" valign="top">
      <img src="screenshots/workouts.png" alt="Workouts Browser" width="100%" />
    </td>
    <td width="33.33%" align="center" valign="top">
      <img src="screenshots/preset_workout.png" alt="Preset Workout Plan" width="100%" />
    </td>
  </tr>
  <tr>
    <td width="33.33%" align="center" valign="top">
      <img src="screenshots/live_tracking.png" alt="Live Workout Tracking" width="100%" />
    </td>
    <td width="33.33%" align="center" valign="top">
      <img src="screenshots/ai_coach.png" alt="AI Coaching Interface" width="100%" />
    </td>
    <td width="33.33%" align="center" valign="top">
      <img src="screenshots/muscle_exercises.png" alt="Exercise Anatomy Library" width="100%" />
    </td>
  </tr>
  <tr>
    <td width="33.33%" align="center" valign="top">
      <img src="screenshots/health_connect.png" alt="Health Connect Integration" width="100%" />
    </td>
    <td width="33.33%" align="center" valign="top">
      <img src="screenshots/profile.png" alt="User Profile & History" width="100%" />
    </td>
    <td width="33.33%" align="center" valign="top">
      <img src="screenshots/settings.png" alt="Application Settings" width="100%" />
    </td>
  </tr>
</table>

---

## Downloads

Official release packages are published under the [GitHub Releases](https://github.com/mina-android/fitverse/releases) section.

| Platform | Architecture | Package Type | Download Link | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Android** | arm64-v8a | `.apk` | [Download (v1.0.0)](https://github.com/mina-android/fitverse/releases/latest) | Standard 64-bit Android builds (recommended) |
| **Android** | armeabi-v7a | `.apk` | [Download (v1.0.0)](https://github.com/mina-android/fitverse/releases/latest) | Legacy 32-bit hardware |
| **Android** | x86_64 | `.apk` | [Download (v1.0.0)](https://github.com/mina-android/fitverse/releases/latest) | Android desktop emulators |
| **Android** | Universal | `.apk` | [Download (v1.0.0)](https://github.com/mina-android/fitverse/releases/latest) | Multi-architecture APK installer |

---

## Self Building & Local Setup

### 1. Prerequisites

Verify that the following development toolchains are installed:

- **Flutter SDK**: `3.19.0` or higher
- **Dart SDK**: `3.3.0` or higher
- **Android SDK**: API level `34` (Android 14)
- **Java Development Kit**: JDK `17`
- **Firebase CLI**: Configured if deploying custom backend instances

### 2. Repository Setup

```bash
# Clone the repository
git clone https://github.com/mina-android/fitverse.git

# Navigate into the project root
cd fitverse

# Verify Flutter tooling
flutter doctor
```

### 3. Backend & API Configuration

1. **Firebase**: Create a project in the Firebase Console, enable Firestore and Authentication, and execute:
   ```bash
   flutterfire configure
   ```
2. **Gemini API Key**: Obtain a key from Google AI Studio and configure it in your local environment file or build config:
   ```bash
   export GEMINI_API_KEY="your-api-key"
   ```

### 4. Dependency Installation & Build

```bash
# Install dependencies
flutter pub get

# Compile release APK
flutter build apk --split-per-abi --release
```

Compiled binaries will be placed in `build/app/outputs/flutter-apk/`.

### 5. Running Locally

```bash
flutter run --release
```

---

## Contribution

Contributions focusing on exercise database expansion, sensor calibration, and UI improvements are welcome.

### Contribution Process

1. Review existing issues to prevent redundant feature requests.
2. For large architectural changes or new sensor pipelines, open a discussion ticket prior to submitting code.
3. Verify test integrity before opening pull requests:
   ```bash
   flutter analyze
   flutter test
   ```
4. Submit your pull request against `main`.

---

## About the Developer

This project is authored and maintained by **mina-android**, focused on developing transparent, local-first utilities and privacy-conscious software.

[![Portfolio](https://img.shields.io/badge/Portfolio-mina--android-181717?style=flat&logo=cloudflare&logoColor=white)](https://portfolio.minaashraf285.workers.dev/) [![GitHub](https://img.shields.io/badge/GitHub-mina--android-181717?style=flat&logo=github&logoColor=white)](https://github.com/mina-android) [![Issues](https://img.shields.io/badge/Issues-Report%20a%20Bug-181717?style=flat&logo=github&logoColor=white)](https://github.com/mina-android/FitVerse/issues)

---

## Donate

Development and maintenance of this software are independent and self-supported. If this project helps you in your workflow, consider supporting development:

[![PayPal](https://img.shields.io/badge/PayPal-Donate-00457C?style=flat&logo=paypal&logoColor=white)](https://paypal.me/minaashraf285) [![GitHub Sponsors](https://img.shields.io/badge/GitHub%20Sponsors-Sponsor-EA4AAA?style=flat&logo=githubsponsors&logoColor=white)](https://github.com/sponsors/mina-android) [![Ko-fi](https://img.shields.io/badge/Ko--fi-Support-FF5E5B?style=flat&logo=kofi&logoColor=white)](https://ko-fi.com/minaashraf285)

---

## License

Distributed under the **GNU General Public License v3.0 (GPL-3.0)**. See the [`LICENSE`](LICENSE) file in the root directory for legal text.

```text
Copyright (c) 2026 mina-android
Licensed under the GNU General Public License v3.0.
```
