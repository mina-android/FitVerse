# FitVerse — AI-Powered Fitness App
 
A Flutter fitness app combining real-time biometric tracking, an adaptive accelerometer-based step counter, a 93-exercise library, AI-generated post-workout reports, and a Gemini-powered coaching chat — all synced to Firebase/Firestore for cross-device persistence.
 
See `CHANGELOG.md` for what's changed since the original local-only build, and `CLAUDE.md` for full architecture notes and build lessons.
 
---
 
## 📱 Features
 
### Onboarding & Health Profile
New users sign in with Google, which `AuthProvider` immediately bridges into a Firebase Auth session. A four-state auth machine (`unknown → unauthenticated → newUser → authenticated`) routes first-time users through `ProfileSetupScreen` to capture age, weight, height, gender, and a fitness goal (Build Muscle, Lose Weight, Improve Endurance, General Fitness, or Athletic Performance), from which the app derives BMI and a BMI category automatically. From there, `HealthConditionsScreen` offers an optional, explicitly opt-in checklist of eight conditions — mild asthma, Type 2 diabetes, hypertension, knee pain, lower-back pain, heart condition, obesity, and arthritis — which is never required to continue, but is fed straight into the AI Coach's system prompt so its advice can avoid or flag contraindicated movements.
 
### Home Dashboard
The home screen surfaces live heart rate, blood oxygen (SpO2), step count, and calories burned as metric cards, sourced from whichever pipeline is active (Health Connect or the accelerometer fallback). Below that, an `fl_chart`-powered weekly activity chart visualizes recent training volume, a workout-history list shows the most recent sessions with duration/calories/accuracy, and an AI suggestion banner surfaces a short, Gemini-generated nutrition or recovery tip pulled from the user's latest workout report.
 
### Workout Library & Anatomical Body Map
`WorkoutsScreen` renders a custom-painted, tappable anatomical body map with a front/back toggle — tapping a muscle region opens `MuscleExercisesScreen`, filtered to that group. In total the library spans 20 muscle groups (chest, back, shoulders, legs, arms, core, calves, glutes, forearms, cardio, trapezius, neck, lower back, hamstrings, quadriceps, hip flexors, adductors, abductors, serratus anterior, obliques) and 93 individual exercises. Each exercise has its own detail screen (`WorkoutDetailScreen`) with step-by-step instructions, form cues, target muscles, equipment needed, a difficulty rating, an estimated calorie burn, and — where available — an animated demonstration pulled frame-by-frame from the open-source `free-exercise-db` GitHub repository, falling back to a simple emoji icon when no demo exists.
 
### Workout Presets
Beyond individual exercises, 22 curated multi-exercise presets (Push Day, Pull Day, Leg Day Protocol, HIIT Cardio Blast, Zero Equipment Workout, Posterior Chain Master, Shoulder Health & Stability, and more) bundle a sequence of exercises with a target level (Beginner/Intermediate/Advanced) and an estimated duration. Running a preset walks the user through each exercise back-to-back via `LiveTrackingScreen`, and `PresetWorkoutScreen` aggregates every sub-session's reps, calories, and accuracy into a single combined session record at the end.
 
### Live Form Tracking
During any tracked exercise, the accelerometer feeds an adaptive four-stage signal pipeline (gravity-removal filter → dynamic magnitude → smoothing → adaptive peak detection) that both counts reps and scores form quality in real time. A `FormStatus` of good, warning, or error drives the on-screen color and triggers a spoken correction cue via Flutter TTS, throttled by a cooldown so it doesn't talk over every rep. See the [Live Form Tracking](#-live-form-tracking) section below for the full detection table.
 
### AI Coach
The AI Coach tab is a persistent Gemini-powered chat (model `gemini-2.5-flash`) with a system prompt built from the user's full profile, health conditions, and last five workout sessions, so advice stays personalized and condition-aware turn after turn. Chat history is saved message-by-message to Firestore and survives app restarts and device changes; the underlying context silently refreshes whenever a new session is logged, without ever clearing the visible conversation. After every completed workout, the same AI pipeline generates a one-shot coaching report (stored as `session.aiSuggestion`) summarizing how the workout went and what to focus on next.
 
### Google Health Connect & Adaptive Fallback
`HealthProvider` runs two mutually exclusive pipelines. When Health Connect is available and permission is granted, it reads heart rate, blood oxygen, steps, and active calories directly (including data synced from a paired Wear OS watch), refreshing every 5 seconds and pushing to Firestore every 30. When Health Connect is unavailable or denied, the app transparently switches to its own adaptive accelerometer-based pedometer — sampling at 20 Hz and using a decaying running-max threshold to count steps without any manual calibration — so the dashboard never just shows zeros.
 
### Background Step Tracking
A native Android foreground service (`StepCounterService.kt`) keeps the accelerometer pedometer running even while FitVerse is backgrounded or the screen is off, so daily step counts stay accurate across the whole day rather than only while the app is open. Step and calorie totals are handed back to Flutter through a dedicated `MethodChannel` the moment the app is resumed.
 
### Cloud Sync
Every profile, workout session, daily health snapshot, and AI chat message is synced to Cloud Firestore under `/users/{uid}`, with SharedPreferences acting as an instant local cache so the UI never shows a blank screen while the network catches up. Signing in on a new device pulls the full profile and recent session history straight from the cloud, and any drift between cached and computed workout/calorie totals is detected and silently repaired. See [Cloud Sync & Data Model](#%EF%B8%8F-cloud-sync--data-model) below for the full schema.
 
### Profile & Settings
From Settings, users can edit their profile data, connect or disconnect Google Health Connect, supply and validate their own Gemini API key (overriding the bundled default), toggle voice-alert (TTS) coaching on or off, clear their entire workout history, or sign out — each action applying instantly to the local cache and asynchronously to Firestore.
 
---
 
## 🚀 Setup & Deployment
 
### Prerequisites
- Flutter SDK ≥ 3.19.0, Dart SDK `>=3.2.0 <4.0.0`
- Android Studio / VS Code with the Flutter plugin
- Android device or emulator running API 26+ (Android 8.0+)
- A Google Cloud / Firebase project
---
 
### Step 1 — Clone & Install Dependencies
 
```bash
git clone <your-repo-url> fitverse
cd fitverse
flutter pub get
```
 
---
 
### Step 2 — Configure Firebase & Google Sign-In
 
The app ships pre-configured for the `fitverse-6513c` Firebase project. To use your own:
 
1. Run `flutterfire configure` to generate your own `lib/firebase_options.dart`.
2. In [Firebase Console](https://console.firebase.google.com), enable **Authentication → Google**, and **Firestore Database** (production mode).
3. Download `google-services.json` and place it at `android/app/google-services.json` (already gitignored).
4. Get your SHA-1 fingerprint and register it under Google Cloud Console → APIs & Services → Credentials:
```bash
   # Debug
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   # Release
   keytool -list -v -keystore /path/to/your/release.keystore -alias your_alias
```
5. Deploy Firestore security rules (see `firestore.rules` and `FIRESTORE_SETUP.md` for the full schema and rules walkthrough):
```bash
   npm install -g firebase-tools
   firebase login
   firebase deploy --only firestore:rules
```
 
---
 
### Step 3 — Configure the Gemini API Key
 
The app ships with a built-in default key for convenience during development, but you should supply your own before any real or public build:
 
- **In-app (recommended for end users):** open **Settings → Gemini API Key**, paste your key from [Google AI Studio](https://aistudio.google.com/app/apikey), and save — it's validated and stored locally, overriding the default.
- **At build time (recommended for releases):** replace the hardcoded default in `lib/providers/ai_provider.dart` with a `--dart-define` secret:
```bash
  flutter run --dart-define=GEMINI_KEY=AIza...
```
```dart
  const key = String.fromEnvironment('GEMINI_KEY');
```
 
> ⚠️ **Security note:** the source currently ships with a real fallback key compiled into the app. Treat any key baked into `ai_provider.dart` as compromised the moment the APK is distributed — rotate it and move secrets out of source control before a public release.
 
---
 
### Step 4 — Health Connect Setup
 
Health Connect requires **Android 8.0+ (API 26)** and the **Health Connect app** on-device.
 
1. Install Health Connect from the [Play Store](https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata).
2. The app requests permissions on first launch.
3. For Wear OS data, pair your watch and enable Health Connect sync in the Wear app.
**Permissions requested** (already in `AndroidManifest.xml`):
- `health.READ_HEART_RATE`
- `health.READ_OXYGEN_SATURATION`
- `health.READ_STEPS`
- `health.READ_ACTIVE_CALORIES_BURNED`
- plus `BODY_SENSORS`, `BODY_SENSORS_BACKGROUND`, `ACTIVITY_RECOGNITION`, and foreground-service permissions for the background step counter.
> If Health Connect is unavailable or permissions are denied, the app automatically falls back to its own adaptive accelerometer-based step counter — see `CLAUDE.md` §10 for the algorithm.
 
---
 
### Step 5 — Run the App
 
```bash
# Debug mode
flutter run
 
# Release APK
flutter build apk --release
 
# Release AAB (for Play Store)
flutter build appbundle --release
```
 
---
 
## 📁 Project Structure
 
```
fitverse/
├── android/
│   └── app/
│       ├── build.gradle                  # applicationId com.ma.fitverse, minSdk 26, compileSdk 36
│       ├── google-services.json          # gitignored — add your own
│       └── src/main/
│           ├── AndroidManifest.xml
│           └── kotlin/com/fitverse/app/
│               ├── MainActivity.kt        # FlutterFragmentActivity, MethodChannels
│               └── StepCounterService.kt  # Foreground service for background steps
├── lib/
│   ├── main.dart                          # Entry point, Firebase init, Provider tree
│   ├── app.dart                           # Root widget, auth-state routing
│   ├── firebase_options.dart              # Platform Firebase config
│   ├── core/
│   │   ├── constants/workout_data.dart    # 20 muscle groups, 93 exercises, 22 presets
│   │   └── theme/app_theme.dart           # Material 3 dark theme, design tokens
│   ├── models/
│   │   ├── user_model.dart                # UserModel + BMI helpers
│   │   └── workout_model.dart             # MuscleGroup, Exercise, Preset, Session, ChatMessage
│   ├── providers/                         # ChangeNotifier state management (Provider)
│   │   ├── auth_provider.dart             # Google Sign-In ↔ Firebase Auth bridge
│   │   ├── user_provider.dart             # Profile/session CRUD, two-layer Firestore sync
│   │   ├── health_provider.dart           # Health Connect + adaptive accelerometer pipeline
│   │   ├── workout_provider.dart          # Live tracking, rep counting, TTS cues
│   │   └── ai_provider.dart               # Gemini chat session + workout report generation
│   ├── services/
│   │   └── web_sync_service.dart          # Fire-and-forget sync to an external backend
│   └── features/
│       ├── auth/                          # onboarding, sign-in, profile setup, health conditions
│       ├── main/main_shell.dart           # Bottom nav: Home / Workouts / AI Coach
│       ├── home/                          # dashboard + widgets
│       ├── workouts/                      # body map, exercise/preset detail, live tracking
│       ├── ai_coach/                      # chat UI
│       ├── profile/
│       └── settings/                      # API key, Health Connect, voice alerts, sign out
├── firestore.rules
├── firestore.indexes.json
├── firebase.json
├── FIRESTORE_SETUP.md                     # Firestore schema + deploy walkthrough
├── CLAUDE.md                              # Full architecture & build-lesson reference
├── CHANGELOG.md
├── LICENSE                                # MIT
└── pubspec.yaml
```
 
---
 
## 🏋️ Live Form Tracking
 
In-workout rep counting and step counting share the same adaptive four-stage signal pipeline: gravity-removal low-pass filter → dynamic magnitude → magnitude smoothing → adaptive peak detection (decaying running-max threshold with valley confirmation). Detected issues drive both the on-screen status and a spoken correction cue:
 
| Exercise | Detection Method | Alert |
|---|---|---|
| Push-ups | Z-axis amplitude < 0.8g | "Go deeper on your push-up" |
| Pull-ups | Y-axis range < 1.5g | "Pull higher — chin over bar" |
| Squats | Variance too low | "Squat deeper for full range" |
| Plank | Too much X-axis movement | "Hold still — stabilize your core" |
| General | Excessive jerk (> 4.0g) | "Slow down — control the movement" |
 
Voice alerts use Flutter TTS with a cooldown between alerts to avoid annoyance; this can be disabled entirely in Settings.
 
---
 
## 🤖 AI Coach (Gemini)
 
The chat system prompt includes:
- Name, age, gender, weight, height, BMI + category, and fitness goal
- Any selected health conditions (asthma, diabetes, hypertension, etc.)
- The last 5 workout sessions with duration, calories, and accuracy
- Instructions to give personalized, condition-aware advice as a persona named "Coach"
The context is rebuilt automatically whenever a new session is logged, without resetting the visible chat history. Quick-prompt shortcuts are available for muscle-gain tips, cardio, nutrition, recovery, and progress analysis.
 
---
 
## ☁️ Cloud Sync & Data Model
 
Every user document lives at `/users/{uid}` with three subcollections: `sessions`, `health_daily` (one document per day, upserted via merge), and `chat_messages`. Firestore is treated as authoritative; SharedPreferences is an instant local cache that's reconciled on every launch and login. Denormalized counters (`totalWorkouts`, `totalCalories`) are recomputed from the session list on every write, with automatic drift correction if they ever fall out of sync. Full schema and security-rule details are in `FIRESTORE_SETUP.md` and `firestore.rules`.
 
---
 
## ⚙️ Configuration Checklist
 
Before building for release:
 
- [ ] Your own `google-services.json` placed in `android/app/`
- [ ] SHA-1 fingerprint registered in Google Cloud Console
- [ ] Firestore security rules deployed (`firebase deploy --only firestore:rules`)
- [ ] The bundled fallback Gemini API key rotated/removed and replaced via `--dart-define` or a user-supplied key
- [ ] `android/local.properties` updated with correct SDK paths
- [ ] Health Connect app installed on test device
- [ ] Release signing keystore configured in `android/app/build.gradle`
- [ ] Application ID `com.ma.fitverse` registered in Play Console (if publishing)
---
 
## 🔐 Security Notes
 
- Never commit `google-services.json`, keystores, or API keys — `.gitignore` already excludes these along with `secrets.dart` and `.env*`.
- Firestore rules enforce owner-only access on every path and reject any document containing credential-shaped fields (`password`, `token`, `secret`, `credential`, etc.).
- The hardcoded Gemini API key fallback in `lib/providers/ai_provider.dart` should be treated as public once the APK ships; rotate it and prefer `--dart-define` or the in-app per-user key for anything beyond local development.
---
 
## 📦 Dependencies
 
| Package | Version | Purpose |
|---|---|---|
| provider | ^6.1.2 | State management |
| google_sign_in | ^6.2.1 | Authentication |
| firebase_core | ^3.8.0 | Firebase initialization |
| firebase_auth | ^5.3.1 | Firebase Auth (bridged from Google Sign-In) |
| cloud_firestore | ^5.4.5 | Cloud data sync |
| google_generative_ai | ^0.4.6 | Gemini AI (chat + reports) |
| health | ^12.0.0 | Health Connect / HealthKit |
| sensors_plus | ^4.0.2 | Accelerometer |
| permission_handler | ^11.3.1 | Runtime permissions |
| flutter_tts | ^4.0.2 | Voice alerts |
| fl_chart | ^0.68.0 | Charts |
| shared_preferences | ^2.3.2 | Local cache |
| google_fonts | ^6.2.1 | Typography (Inter) |
| cached_network_image | ^3.3.1 | Profile photo caching |
| http | ^1.2.2 | Web sync service |
| intl | ^0.19.0 | Date formatting |
| uuid | ^4.4.2 | Session ID generation |
 
Dev dependencies: `flutter_lints ^4.0.0`, `flutter_launcher_icons ^0.13.1` (generates Android launcher/adaptive icons from `assets/images/app_icon.png`).
 
---
 
## 📄 License
 
MIT License — see [`LICENSE`](./LICENSE) for the full text. Update the copyright holder name in that file before distributing the app publicly.
 
---
 
*Built with Flutter · Powered by Gemini AI · Synced with Firebase/Firestore*
