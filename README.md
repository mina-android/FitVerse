<div align="center">

<img src="assets/icons/splash_icon.png" alt="FitVerse Logo" width="120" height="120" style="border-radius: 24px"/>

# FitVerse

### Your AI-driven personal coaching ecosystem

[![Flutter](https://img.shields.io/badge/Flutter-3.19%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)](https://android.com)
[![Version](https://img.shields.io/badge/Version-1.0.0-brightgreen)](CHANGELOG.md)
[![License](https://img.shields.io/badge/License-MIT-blue)](LICENSE)

**FitVerse** combines real-time biometric tracking, an accelerometer-powered live form coach, a 93-exercise workout library, and a Gemini-powered AI coach — synced to the cloud so your progress follows you across devices.

[**Download**](#-installation) · [**Features**](#-features) · [**Screenshots**](#-screenshots) · [**Build from Source**](#-build-from-source)

</div>

---

## Why FitVerse?

<!-- 2-3 sentences: what problem this solves and why it's different from alternatives. -->
Most fitness apps either lock real coaching behind a subscription or give you a library of exercises with no idea who you are. FitVerse builds a live profile of your body, your health conditions, and your workout history, then feeds that context straight into Google's Gemini model so every piece of advice — nutrition, recovery, muscle-building — is actually personalized. Biometrics come from Google Health Connect when available, with a self-built adaptive accelerometer pedometer as a fallback that keeps working even without a smartwatch. Everything is cached locally first for an instant UI, then synced to Firestore so a new device picks up your full history the moment you sign in.

---

## ✨ Features

<!-- Keep each bullet to one line. Bold the feature name, then a short plain-language benefit. -->
- **Authentication & Onboarding** — Google Sign-In bridged to Firebase Auth (`request.auth.uid`), 4-state auth routing with silent session restore, and guided profile setup capturing fitness goals and optional health conditions
- **Home Dashboard** — Live metric cards (heart rate, SpO2, steps, calories burned), 7-day activity bar chart (`fl_chart`), recent workout history, AI-generated nutrition banners, and real-time stats row recomputed live
- **Workout Library & Anatomical Map** — 20 muscle groups, 93 exercises, and 18 multi-exercise presets browsable via an interactive custom-painted body map with step-by-step instructions and animated previews
- **Live Form Tracking & Rep Counting** — Accelerometer-based rep counting and form-quality scoring during resistance training with non-spammy spoken voice corrections via Flutter TTS and automatic AI workout reports
- **Personalized AI Coach (Gemini 2.5 Flash)** — Context-aware chat using your profile, BMI, health conditions, and last 5 workout sessions with quick-prompt chips, persistent chat history, and bring-your-own API key support
- **Health & Activity Tracking** — Automatic switching between Google Health Connect (5s refresh) and a self-built 20 Hz adaptive accelerometer pedometer fallback running via a foreground service with daily snapshots
- **Cross-Device Cloud Sync (Firestore)** — Instant local caching via SharedPreferences combined with asynchronous Firestore sync, union-by-session-ID profile merging, recomputed drift-free counters, and full offline persistence
- **Profile & Settings Management** — Editable body metrics, voice alert toggles, Health Connect management, Gemini API key configuration, and secure workout history management

---

## 📸 Screenshots

<p align="center">
  <img src="screenshots/home.png" width="30%" alt="Home" />
  <img src="screenshots/workouts.png" width="30%" alt="Workouts" />
  <img src="screenshots/live_tracking.png" width="30%" alt="Live Tracking" />
  <img src="screenshots/muscle_exercises.png" width="30%" alt="Muscle Exercises" />
  <img src="screenshots/ai_coach.png" width="30%" alt="AI Coach" />
  <img src="screenshots/health_connect.png" width="30%" alt="Health Connect" />
</p>

---

## 📲 Installation

1. Go to [**Releases**](https://github.com/YourUsername/fitverse/releases)
2. Download `app-release.apk`
3. On your phone: go to **Settings → Security → Install Unknown Apps** and enable for your file manager
4. Open and install

> Requires Android 8.0 (API 26) or higher.

---

## 🛠 Build from Source

**Prerequisites:** Flutter SDK 3.19+, Android Studio (Latest), Java JDK 17+, Firebase CLI

```bash
git clone https://github.com/YourUsername/fitverse.git
cd fitverse
flutter pub get
flutter run

# Release build
flutter build apk --release
```

Output lands in `build/app/outputs/flutter-apk/app-release.apk`.

<details>
<summary><strong>Project Configuration Steps (Firebase, Google Sign-In, Gemini API Key, Health Connect)</strong></summary>

### Step 1 — Configure Firebase
FitVerse uses **Firebase Auth** (Google Sign-In bridge) and **Cloud Firestore** (cross-device sync).
1. Go to [Firebase Console](https://console.firebase.google.com) and create a project
2. Run `flutterfire configure` to generate your own `lib/firebase_options.dart`
3. Download `google-services.json` and place it at:
   ```
   android/app/google-services.json
   ```
4. Enable **Firestore Database** (production mode) and deploy the bundled rules:
   ```bash
   firebase login
   firebase init firestore     # select your project
   firebase deploy --only firestore:rules
   ```
See [`FIRESTORE_SETUP.md`](FIRESTORE_SETUP.md) for the full schema, sync behaviour, and security rule details.

### Step 2 — Configure Google Sign-In
1. In [Google Cloud Console](https://console.cloud.google.com), open the Firebase-linked project
2. Under **APIs & Services → Credentials → OAuth 2.0 Client IDs**, create:
   - **Android client** with your SHA-1 fingerprint
   - **Web client** (required for Firebase Auth token validation)

#### Get your SHA-1 fingerprint:
```bash
# For debug builds
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# For release builds
keytool -list -v -keystore /path/to/your/release.keystore -alias your_alias
```

### Step 3 — Configure Gemini API Key
1. Visit [Google AI Studio](https://aistudio.google.com/app/apikey) and create a key
2. Open `lib/providers/ai_provider.dart`
3. Replace the placeholder:
   ```dart
   // BEFORE
   const _kGeminiKey = 'YOUR_GEMINI_API_KEY';

   // AFTER
   const _kGeminiKey = 'AIza...your-actual-key...';
   ```
> ⚠️ **Security Note:** Move the key off this hardcoded constant before shipping to production — use `--dart-define` or a secrets vault:
> ```bash
> flutter run --dart-define=GEMINI_KEY=AIza...
> ```
> Then read it with: `const key = String.fromEnvironment('GEMINI_KEY');`
>
> End users can also supply their own key from inside the app — see **Settings → Gemini API Key**.

### Step 4 — Health Connect Setup
Health Connect requires **Android 8.0+ (API 26)** and the **Health Connect app** installed on the device.
1. Install Health Connect from the [Play Store](https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata)
2. The app requests permissions on first launch
3. For Wear OS smartwatch data, pair your watch and enable Health Connect sync in the Wear app

**Required Health Connect permissions** (already declared in `AndroidManifest.xml`):
- `android.permission.health.READ_HEART_RATE`
- `android.permission.health.READ_OXYGEN_SATURATION`
- `android.permission.health.READ_STEPS`
- `android.permission.health.READ_ACTIVE_CALORIES_BURNED`

> If Health Connect is unavailable or permissions are denied, FitVerse falls back to its own adaptive accelerometer pedometer — no biometric data is ever lost.

</details>

<details>
<summary><strong>Tech Stack & Project Structure</strong></summary>

### Tech Stack
| Layer | Technology |
|-------|-----------|
| **Framework** | Flutter (Dart SDK `>=3.2.0 <4.0.0`) |
| **State** | provider ^6.1.2 (ChangeNotifier) |
| **Auth** | google_sign_in ^6.2.1 + firebase_auth ^5.3.1 |
| **Database** | cloud_firestore ^5.4.5 — per-user documents, offline persistence enabled |
| **Firebase Core** | firebase_core ^3.8.0 |
| **AI** | google_generative_ai ^0.4.6 — Gemini 2.5 Flash |
| **Health** | health ^12.0.0 — Health Connect (Android) |
| **Sensors** | sensors_plus ^4.0.2 — accelerometer pipeline |
| **Permissions** | permission_handler ^11.3.1 |
| **Voice** | flutter_tts ^4.0.2 |
| **Charts** | fl_chart ^0.68.0 |
| **Local Cache** | shared_preferences ^2.3.2 |
| **HTTP** | http ^1.2.2 — optional web backend sync |
| **Fonts** | google_fonts ^6.2.1 (Inter) |
| **Images** | cached_network_image ^3.3.1 |
| **Date Formatting** | intl ^0.19.0 |
| **UUIDs** | uuid ^4.4.2 |

### Project Structure
```
lib/
├── main.dart                          # Entry point — Firebase init, Provider tree
├── app.dart                           # FitVerseApp widget, auth-state routing
├── firebase_options.dart              # Platform-specific Firebase config
├── core/
│   ├── constants/
│   │   └── workout_data.dart          # 20 muscle groups, 93 exercises, 18 presets
│   └── theme/
│       └── app_theme.dart             # Dark Material 3 theme, design tokens
├── models/
│   ├── user_model.dart                # UserModel + BMI helpers
│   └── workout_model.dart             # MuscleGroup, Exercise, WorkoutPreset,
│                                       #   SessionModel, ChatMessage
├── providers/
│   ├── auth_provider.dart             # Google Sign-In + Firebase Auth bridge
│   ├── user_provider.dart             # Profile CRUD, sessions, Firestore sync
│   ├── health_provider.dart           # Health Connect + adaptive accelerometer pipeline
│   ├── workout_provider.dart          # Live tracking, rep counting, TTS cues
│   └── ai_provider.dart               # Gemini chat session + workout report gen
├── services/
│   └── web_sync_service.dart          # Fire-and-forget HTTP sync to an optional backend
└── features/
    ├── auth/
    │   ├── onboarding_screen.dart
    │   ├── sign_in_screen.dart
    │   ├── profile_setup_screen.dart
    │   └── health_conditions_screen.dart
    ├── main/
    │   └── main_shell.dart            # IndexedStack bottom nav (3 tabs)
    ├── home/
    │   ├── home_screen.dart           # Dashboard — metrics, chart, history, AI banner
    │   └── widgets/
    │       ├── metric_card.dart
    │       ├── workout_history_card.dart
    │       └── ai_suggestion_banner.dart
    ├── workouts/
    │   ├── workouts_screen.dart       # Anatomical body map + muscle group tabs
    │   ├── muscle_exercises_screen.dart
    │   ├── workout_detail_screen.dart
    │   ├── live_tracking_screen.dart  # Live rep counting + form coaching
    │   └── preset_workout_screen.dart # Multi-exercise preset sequencing
    ├── ai_coach/
    │   └── ai_coach_screen.dart       # Gemini chat UI + quick prompts
    ├── profile/
    │   └── profile_screen.dart
    └── settings/
        └── settings_screen.dart       # Voice alerts, Health Connect, API key, sign out
```

</details>

<details>
<summary><strong>Gradle Config & Android Permissions</strong></summary>

### Gradle / Build Config
| Component | Version |
|-----------|---------|
| Gradle | **8.10.2** |
| Android Gradle Plugin | **8.7.3** |
| Kotlin | **2.1.21** |
| Java / Kotlin target | 17 |
| `google-services` plugin | 4.4.2 |
| Namespace | `com.fitverse.app` |
| Application ID | `com.ma.fitverse` |
| compileSdk / targetSdk | 36 |
| Min SDK | 26 (Android 8.0) |
| NDK | 28.2.13676358 |

> **`MainActivity` must extend `FlutterFragmentActivity`** (not `FlutterActivity`) — required for Health Connect's `ActivityResultLauncher` to register correctly.
> **Health Connect permission name is `READ_OXYGEN_SATURATION`**, not `READ_BLOOD_OXYGEN` — a single typo here silently fails the entire `requestAuthorization()` call.
> **Adaptive icon foreground must live in `mipmap-*`** (referenced as `@mipmap/ic_launcher_foreground`), not `drawable/` — otherwise release builds fail with an AAPT link error.

### Android Permissions
| Permission | Purpose |
|-----------|---------|
| `INTERNET` | Firebase sync, Gemini API calls, exercise GIF previews |
| `ACCESS_NETWORK_STATE` | Check connectivity before network calls |
| `BODY_SENSORS` / `BODY_SENSORS_BACKGROUND` | Accelerometer-based rep counting and step detection |
| `ACTIVITY_RECOGNITION` | Required for step counting on Android 10+ |
| `health.READ_HEART_RATE` | Health Connect heart rate |
| `health.READ_OXYGEN_SATURATION` | Health Connect blood oxygen |
| `health.READ_STEPS` | Health Connect steps |
| `health.READ_ACTIVE_CALORIES_BURNED` | Health Connect active calories |
| `POST_NOTIFICATIONS` | Workout and reminder notifications |
| `RECEIVE_BOOT_COMPLETED` | Restore foreground service state after reboot |
| `VIBRATE` / `WAKE_LOCK` | Live tracking feedback and screen-on during workouts |
| `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_HEALTH` | Background step counting service |
| `RECORD_AUDIO` | Required by the text-to-speech engine on some OEM builds |

</details>

<details>
<summary><strong>Build troubleshooting</strong></summary>

- **`AAPT: error: resource drawable/ic_launcher_foreground not found`:** The adaptive icon foreground must be placed in `mipmap-*` folders, not `drawable/`. Move it and rebuild.
- **Stats (Workouts / Total kcal) showing zero despite having sessions:** This is the known counter-drift issue — `UserProvider._pullSessions()` recomputes and patches the Firestore document automatically on the next sync. Force a sync by pulling to refresh or restarting the app.
- **Gradle build fails on classpath / `io.flutter.*` not found:** Ensure the Flutter Gradle plugin is loaded via `includeBuild` from your local Flutter SDK in `settings.gradle` — never pin it as a separate Maven dependency.
- **Health Connect permissions not granted / silently fails:** Double-check the manifest permission is `android.permission.health.READ_OXYGEN_SATURATION`, **not** `READ_BLOOD_OXYGEN`. A mismatch here fails the whole authorization request without an obvious error.
- **Gemini Coach not responding:** Check **Settings → Gemini API Key** — the status badge will read "Not configured" if the active key doesn't start with `AIza`. Add your own key from [ai.google.dev](https://aistudio.google.com/app/apikey).
- **Accept Android SDK licenses:** Run `flutter doctor --android-licenses` in your terminal.

</details>

---

## 🔒 Privacy

<!-- Delete/edit lines that don't apply. Keep it short and skimmable. -->
- All profile data, sessions, and health snapshots are cached locally first — the app works fully offline
- Cloud sync via **Firestore** is strictly per-user (`request.auth.uid == uid`), with security rules rejecting any credential-like fields (`passwordHash`, `token`, `secret`, `credential`)
- AI Coach chat and workout context (profile, BMI, health conditions, recent sessions) are sent securely to **Google's Gemini API** to generate responses
- You can supply your own Gemini API key in Settings instead of using the built-in default
- No third-party ads, no external analytics or crash reporting beyond Firebase's own infrastructure

---

## 🗺 Roadmap

- [x] Google Health Connect integration with adaptive accelerometer fallback
- [x] Firestore cloud sync with cross-device session merge
- [x] Gemini-powered AI Coach with personalized context
- [x] Live accelerometer-based rep counting and form coaching
- [x] Bring-your-own Gemini API key
- [ ] iOS support (HealthKit equivalents for the Health Connect pipeline)
- [ ] Automated test coverage (`flutter_test` is wired up, no tests yet)
- [ ] Move the built-in Gemini key off a hardcoded constant before any public release
- [ ] Local caching/fallback for exercise preview GIFs (currently CDN-dependent)
- [ ] Home screen widget (today's steps / streak)
- [ ] Localisation / multiple languages

---

## 🤝 Contributing

1. Fork the repo
2. Create a branch: `git checkout -b feature/my-feature`
3. Commit and push your changes: `git commit -m "Add my feature" && git push origin feature/my-feature`
4. Open a Pull Request

Code style: providers are `ChangeNotifier`s accessed via `context.read<X>()` for one-time calls and `context.watch<X>()` for reactive rebuilds; derive counters (`totalWorkouts`, `totalCalories`) from the live session list, never from cached model fields; `flutter analyze` must pass.

---

## License

MIT License — see [LICENSE](LICENSE) for details.
Copyright © 2026 [Mina Android](https://github.com/mina-android)

<div align="center">

Made with ❤️ and Flutter · [**More projects**](https://github.com/mina-android)

</div>
