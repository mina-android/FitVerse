> **AI-context file for Claude (and other AI agents) working on this codebase.**
> Keep this file up-to-date whenever architecture, conventions, or major features change.

---

## 1. Project Overview

| Field | Value |
|---|---|
| **App name** | FitVerse |
| **Tagline** | AI-driven personal coaching ecosystem |
| **Version** | 1.0.0+1 |
| **Platform** | Flutter (Android-first, iOS-ready) |
| **Dart SDK** | `>=3.2.0 <4.0.0` |
| **Firebase project** | `fitverse-6513c` |
| **Backend** | `https://fitverse-backend-production.up.railway.app/api` |

FitVerse is a mobile fitness app combining real-time biometric tracking (heart rate, SpO2, steps, calories) with an accelerometer-based adaptive step counter, a curated exercise library, AI-generated post-workout reports, and a conversational Gemini-powered coaching assistant — all synced to Firestore for cross-device persistence.

---

## 2. Repository Structure

```
fitverse/
├── lib/
│   ├── main.dart                        # App entry point, Firebase init, Provider tree
│   ├── app.dart                         # FitVerseApp widget, auth-state routing
│   ├── firebase_options.dart            # Platform-specific Firebase config
│   │
│   ├── core/
│   │   ├── constants/
│   │   │   └── workout_data.dart        # All exercise & preset data (~90 KB, static)
│   │   └── theme/
│   │       └── app_theme.dart           # Dark/light MaterialTheme, design tokens
│   │
│   ├── models/
│   │   ├── user_model.dart              # UserModel + BMI helpers
│   │   └── workout_model.dart           # MuscleGroup, Exercise, WorkoutPreset,
│   │                                    #   SessionModel, ChatMessage
│   │
│   ├── providers/
│   │   ├── auth_provider.dart           # Google Sign-In + Firebase Auth bridge
│   │   ├── user_provider.dart           # Profile CRUD, sessions, Firestore sync
│   │   ├── health_provider.dart         # Health Connect + adaptive accelerometer pipeline
│   │   ├── workout_provider.dart        # Live tracking, rep counting, TTS cues
│   │   └── ai_provider.dart             # Gemini chat session + workout report gen
│   │
│   ├── services/
│   │   └── web_sync_service.dart        # Fire-and-forget HTTP sync to Railway backend
│   │
│   └── features/
│       ├── auth/
│       │   ├── onboarding_screen.dart
│       │   ├── sign_in_screen.dart
│       │   ├── profile_setup_screen.dart
│       │   └── health_conditions_screen.dart
│       ├── main/
│       │   └── main_shell.dart          # BottomNavigationBar shell (3 tabs)
│       ├── home/
│       │   ├── home_screen.dart
│       │   └── widgets/
│       │       ├── metric_card.dart
│       │       ├── ai_suggestion_banner.dart
│       │       └── workout_history_card.dart
│       ├── workouts/
│       │   ├── workouts_screen.dart     # Anatomical body map + muscle tabs
│       │   ├── muscle_exercises_screen.dart
│       │   ├── workout_detail_screen.dart
│       │   ├── live_tracking_screen.dart
│       │   └── preset_workout_screen.dart
│       ├── ai_coach/
│       │   └── ai_coach_screen.dart
│       ├── profile/
│       │   └── profile_screen.dart
│       └── settings/
│           └── settings_screen.dart
│
├── assets/
│   └── images/
│       └── app_icon.png                 # FV logo source (PNG, black bg, 3464×3464)
│
├── android/
│   └── app/
│       ├── build.gradle                 # compileSdk 36, minSdk 26, applicationId com.ma.fitverse
│       ├── google-services.json
│       └── src/main/
│           ├── AndroidManifest.xml
│           ├── kotlin/com/fitverse/app/
│           │   ├── MainActivity.kt      # FlutterFragmentActivity + MethodChannels
│           │   └── StepCounterService.kt# Foreground service for background step counting
│           └── res/
│               ├── mipmap-*/            # ic_launcher.png, ic_launcher_round.png,
│               │                        #   ic_launcher_foreground.png (all densities)
│               ├── mipmap-anydpi-v26/   # ic_launcher.xml, ic_launcher_round.xml
│               ├── drawable/            # launch_background.xml, splash_icon.png
│               └── values/             # colors.xml, styles.xml
│
├── firestore.rules
├── firestore.indexes.json
├── firebase.json
├── FIRESTORE_SETUP.md
├── pubspec.yaml
├── README.md                             # User-facing docs — features, setup, build steps
├── CHANGELOG.md                          # Keep a Changelog format, SemVer (current: 1.0.0)
└── LICENSE                               # MIT — copyright holder is a placeholder, fill in before publishing
```

---

## 3. Architecture

### 3.1 State Management

**Provider** (`^6.1.2`) with a flat `MultiProvider` at the root. All providers are `ChangeNotifier`.

```
MultiProvider
├── AuthProvider        — auth state machine, Google + Firebase credential bridge
├── UserProvider        — user profile + session history (Firestore + local cache)
├── HealthProvider      — biometrics pipeline (Health Connect → adaptive accelerometer)
├── WorkoutProvider     — active workout tracking, rep counting, TTS
└── AIProvider          — Gemini chat session + post-workout report generation
```

Providers do **not** depend on each other via constructor injection. Cross-provider reads inside screens use `context.read<X>()`. `context.watch<X>()` for reactive rebuilds.

### 3.2 Authentication Flow

```
App cold start
  └─ AuthProvider._restoreSession()
       ├─ Google signInSilently()
       │    ├─ success → _bridgeToFirebaseAuth() → AuthState.authenticated
       │    └─ failure → AuthState.unauthenticated
       └─ notifyListeners()

AuthState machine (4 states)
  unknown         → SplashScreen
  unauthenticated → OnboardingScreen
  newUser         → ProfileSetupScreen
  authenticated   → _AuthenticatedRoot
                       ├─ waits up to 8 s for FirebaseAuth.currentUser
                       ├─ calls UserProvider.syncFromCloud()
                       ├─ calls HealthProvider.startAccelMode()
                       └─ MainShell (if hasProfile) or ProfileSetupScreen
```

**Firebase Auth bridge:** Google credentials are exchanged for a Firebase Auth session on every sign-in so `request.auth.uid` is populated in Firestore security rules.

### 3.3 Navigation

No named routes. Navigation is done with `Navigator.push` / `pushAndRemoveUntil`. The main shell uses an `IndexedStack` with a `BottomNavigationBar` (3 tabs):

| Index | Tab | Screen |
|---|---|---|
| 0 | Home | `HomeScreen` |
| 1 | Workouts | `WorkoutsScreen` |
| 2 | AI Coach | `AICoachScreen` |

**Profile** and **Settings** are pushed modally from the `AppBar`.

---

## 4. Data Models

### 4.1 UserModel (`lib/models/user_model.dart`)

| Field | Type | Notes |
|---|---|---|
| `uid` | `String` | Firebase Auth UID (immutable) |
| `name` | `String` | Display name |
| `email` | `String` | From Google account |
| `photoUrl` | `String?` | Google profile photo |
| `age` | `int` | Years |
| `weightKg` | `double` | Kilograms |
| `heightCm` | `double` | Centimetres |
| `gender` | `String` | Male / Female / Non-binary / Prefer not to say |
| `healthConditions` | `List<String>` | From predefined checklist |
| `fitnessGoal` | `String` | Build Muscle / Lose Weight / Improve Endurance / General Fitness / Athletic Performance |
| `totalWorkouts` | `int` | Denormalized counter — **do not trust for display; always derive from sessions list** |
| `totalCalories` | `double` | Denormalized counter — **do not trust for display; always derive from sessions list** |

Computed properties: `bmi` (double), `bmiCategory` (Underweight / Normal / Overweight / Obese).

> **⚠️ Counter invariant:** `totalWorkouts` and `totalCalories` on the user document are denormalized caches, kept for Firestore queries only. UI must derive these values from `UserProvider.sessions` directly (see `_StatsRow` in `home_screen.dart`). `UserProvider._pullSessions()` auto-reconciles and patches the Firestore document whenever a drift is detected.

### 4.2 Exercise (`lib/models/workout_model.dart`)

Key fields: `id`, `name`, `muscleGroup`, `difficulty`, `equipment`, `durationSeconds`, `sets`, `reps` (String), `description`, `steps` (List), `formCues` (List), `kalories`, `muscles` (List), `previewEmoji`, `gifUrl`.

`gifUrl` is a folder name in the [free-exercise-db GitHub repo](https://github.com/yuhonas/free-exercise-db). Frame URLs:
```
https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/{gifUrl}/0.jpg
https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/{gifUrl}/1.jpg
```
Empty `gifUrl` → UI falls back to `previewEmoji`.

### 4.3 WorkoutPreset

Named collection of `exerciseIds` with metadata (`level`, `duration`, `icon`, `color`). Resolved via `WorkoutData.exercisesForPreset(preset)`.

### 4.4 SessionModel

| Field | Type |
|---|---|
| `id` | `String` (UUID) |
| `workoutName` | `String` |
| `muscleGroup` | `String` |
| `date` | `DateTime` |
| `durationMinutes` | `int` |
| `caloriesBurned` | `double` |
| `accuracyScore` | `double` (0–100) |
| `musclesWorked` | `List<String>` |
| `intensity` | `String` |
| `aiSuggestion` | `String` (Gemini-generated) |
| `exerciseNames` | `List<String>` |

### 4.5 ChatMessage

| Field | Type |
|---|---|
| `id` | `String` |
| `content` | `String` |
| `isUser` | `bool` |
| `timestamp` | `DateTime` |
| `isLoading` | `bool` |

---

## 5. Firestore Schema

```
/users/{uid}                            ← UserModel fields (flat document)
/users/{uid}/sessions/{sessionId}       ← SessionModel fields
/users/{uid}/health_daily/{YYYY-MM-DD}  ← daily health snapshot (upserted via merge)
/users/{uid}/chat_messages/{messageId}  ← ChatMessage fields (persistent AI chat history)
```

### health_daily document fields

| Field | Type | Source |
|---|---|---|
| `date` | `String` (YYYY-MM-DD) | Local date |
| `heartRate` | `double` | Health Connect or 0 |
| `spo2` | `double` | Health Connect or 0 |
| `steps` | `int` | Health Connect or accelerometer |
| `caloriesBurned` | `double` | Derived |
| `updatedAt` | `Timestamp` | Server timestamp |
| `source` | `String` | `'health_connect'` or `'accelerometer'` |

### Security Rules Summary

- Owner-only: every read/write checks `request.auth.uid == uid`.
- Blocks documents containing credential-class fields (`passwordHash`, `token`, `refreshToken`, `secret`, `credential`).
- Everything outside `/users/{uid}/**` is denied.

---

## 6. Providers — Key Responsibilities

### AuthProvider

- Owns `AuthState` enum: `unknown | unauthenticated | newUser | authenticated`.
- `signInWithGoogle({isNewUser})` — interactive sign-in; bridges to Firebase Auth.
- `_bridgeToFirebaseAuth()` — silently obtains Firebase Auth session from Google credential.
- `signOut()` — signs out of both Google and Firebase Auth, resets state.
- `uid` getter always returns the Firebase Auth UID (never Google's account ID).

### UserProvider

- Two-layer persistence: **SharedPreferences** (instant) + **Firestore** (authoritative).
- Cache keys: `fitverse_profile_{uid}`, `fitverse_sessions_{uid}`.
- `syncFromCloud()` — reads cache first, then Firestore, union-merges sessions by ID.
- `addSession()` — **recomputes** `totalWorkouts` and `totalCalories` from the full `_sessions` list (never increments a potentially-stale counter). Also deduplicates by session ID.
- `_pullSessions()` — after merging remote sessions, checks whether the stored counters drift from the computed reality; if so, patches the Firestore user document silently.
- `recentSessions` getter — top-5 sessions sorted by date descending.
- `clearSessions()` — removes locally + Firestore batch delete; resets counters to 0.

### HealthProvider

Two data pipelines, strictly mutually exclusive via `_Mode` enum (`idle | live | accel`):

**Pipeline 1 — Health Connect (`health: ^12.0.0`)**
- Reads `HEART_RATE`, `BLOOD_OXYGEN`, `STEPS`, `ACTIVE_ENERGY_BURNED`.
- Requires runtime permission grant.
- Refreshes on a 5-second timer; syncs to Firestore every 30 seconds.

**Pipeline 2 — Adaptive Accelerometer pedometer (fallback)**
- Activated when Health Connect is unavailable or permissions denied.
- Sampling: 20 Hz (50 ms period via `sensors_plus`).
- **Algorithm** (see §9 for full details):
  - Gravity removal: LP IIR filter on raw axes (`α = 0.85`).
  - Dynamic magnitude: Euclidean norm of the high-pass axes.
  - Magnitude smoothing: LP IIR (`α = 0.35`) to kill single-sample noise spikes.
  - Adaptive peak detection: running-max with exponential decay (`0.994/sample`); threshold = `0.52 × runningMax`, clamped `[0.9, 5.0]` m/s².
  - Valley confirmation: signal must fall to `0.28 × threshold` before the next peak is eligible.
  - Cadence gate: min 250 ms (no faster than 4 steps/s), peak-lock auto-released after 2 500 ms gap.
  - Calories: `0.045 kcal/step` (≈ 450 kcal / 10 000 steps for ~70 kg adult).
- Background continuity: `StepCounterService` foreground service keeps counting when app is backgrounded; steps are synced back via `com.fitverse.app/shared_prefs` MethodChannel on resume.
- Syncs to Firestore every 5 minutes (only when step count changed).

`HealthMetrics` snapshot: `heartRate`, `spo2`, `steps`, `caloriesBurned`, `isLive`, `isAccelSteps`, `isHrCached`, `isSpO2Cached`.

### WorkoutProvider

- `startTracking()` — begins session timer + accelerometer subscription.
- `_processAccelerometer()` — rep peak detection; simulated form-quality scoring.
- `FormStatus` enum: `good | warning | error` — drives UI colour and TTS cues.
- TTS cues (`flutter_tts: ^4.0.2`) — spoken form correction on cooldown timer.
- `stopTracking()` — returns `SessionModel` (callers persist it).
- Preset mode: `setActivePreset()` sets exercise sequence; `LiveTrackingScreen` returns each sub-session to `PresetWorkoutScreen`, which aggregates and saves one combined record.

### AIProvider

- Uses `google_generative_ai: ^0.4.6` (`gemini-2.5-flash` for both chat and report).
- `initializeSession()` — builds system prompt from `UserModel` + last 5 sessions; starts `ChatSession`.
- `refreshContext()` — rebuilds model + re-seeds chat history when session count changes (no UI wipe).
- `sendMessage()` — streams Gemini response, updates `ChatMessage` list.
- `generateWorkoutReport()` — one-shot call after workout; returns plain-text coaching summary stored as `session.aiSuggestion`.
- `_fmt(DateTime)` — formats dates as `"5 Jun 2026"` (day-name-year) to be unambiguous to the model regardless of locale. **Never use numeric-only `d/m/y` format.**
- `_keyOk` guard — checks that `_kGeminiKey` starts with `AIza`.

---

## 7. Key Screens

### HomeScreen — `_StatsRow` (Workouts / Total kcal / BMI)

> **Critical:** The bottom stats row derives `totalWorkouts` and `totalCalories` directly from `UserProvider.sessions` at render time — **not** from `user.totalWorkouts` / `user.totalCalories`. Those fields on the model can be stale. The correct pattern:

```dart
_StatsRow(
  user: user,
  totalWorkouts: allSessions.length,
  totalCalories: allSessions.fold(0.0, (sum, s) => sum + s.caloriesBurned),
)
```

### WorkoutsScreen

Custom anatomical body-map `CustomPainter` with tappable muscle regions (front/back toggle). Presets tab with `WorkoutPreset` cards.

### LiveTrackingScreen

Supports **solo mode** (saves session on exit) and **preset mode** (returns `SessionModel` to `PresetWorkoutScreen`). After finishing: generates AI report, saves session, shows result dialog.

### AICoachScreen

Chat UI backed by `AIProvider`. System prompt includes full user profile and last 5 sessions. Context auto-refreshes on new sessions without resetting the chat.

---

## 8. Theme & Design Tokens

```dart
// lib/core/theme/app_theme.dart
seedColor   = Color(0xFF00897B)   // Teal (Material 3 seed)
tealAccent  = Color(0xFF26C6DA)   // Cyan highlight
surfaceDark = Color(0xFF0F1C1E)   // Near-black scaffold background
cardDark    = Color(0xFF1A2E31)   // Card background
cardDark2   = Color(0xFF1E3538)   // Slightly lighter card
```

- **Font:** Inter (Google Fonts)
- **Theme mode:** Dark-only (`ThemeMode.dark` forced)
- **Material 3** enabled (`useMaterial3: true`)

---

## 9. App Icon & Splash Screen

**Source file:** `assets/images/app_icon.png` — the FV logo PNG (black background, 3464×3464 px).

### Android icon structure

| Path | Role |
|---|---|
| `mipmap-{density}/ic_launcher.png` | Legacy launcher icon — black bg, FV logo at 42/108 ratio, squircle mask |
| `mipmap-{density}/ic_launcher_round.png` | Same, circular mask |
| `mipmap-{density}/ic_launcher_foreground.png` | Adaptive foreground — **transparent bg**, FV logo centred |
| `mipmap-anydpi-v26/ic_launcher.xml` | Adaptive icon: `@color/ic_launcher_background` + `@mipmap/ic_launcher_foreground` |
| `drawable/splash_icon.png` | Transparent-bg FV logo for splash screen |
| `drawable/launch_background.xml` | `@color/backgroundColor` (#0F1C1E) layer + centred `splash_icon` |
| `values/colors.xml` | `ic_launcher_background = #000000` |

> **AAPT fix lesson (costly to re-learn):** The adaptive icon foreground **must** be in `mipmap-*` folders (referenced as `@mipmap/ic_launcher_foreground`), NOT `@drawable/ic_launcher_foreground`. Placing it only in `drawable/` causes `AAPT: error: resource drawable/ic_launcher_foreground not found` during release builds. This has been fixed and must not be reverted.

### Padding ratio

Logo is rendered at **42/108 of the icon canvas size** — meaning the logo occupies 38.9% of the width, with ~30.5% transparent/background padding on each side.

---

## 10. Adaptive Accelerometer Step Counter — Algorithm Reference

The step counter in `HealthProvider._processStepData()` uses a four-stage pipeline:

```
Raw accelerometer (20 Hz)
  │
  ▼ Stage 1 — Gravity removal
  LP IIR on each axis:  lp = 0.85·lp + 0.15·raw
  HP = raw − lp         (isolates body dynamics, rejects DC gravity)
  │
  ▼ Stage 2 — Dynamic magnitude
  mag = √(hpX² + hpY² + hpZ²)
  │
  ▼ Stage 3 — Magnitude smoothing
  smooth = 0.35·mag + 0.65·smooth_prev   (kills single-sample noise spikes)
  │
  ▼ Stage 4 — Adaptive peak detection
  runningMax = max(smooth, runningMax · 0.994)   ← decays if walking stops
  threshold  = clamp(0.52 · runningMax, 0.9, 5.0)
  valley     = 0.28 · threshold

  State machine:
    smooth ≥ threshold AND NOT inPeak AND elapsed ≥ 250 ms → COUNT STEP, inPeak = true
    smooth < valley                                          → inPeak = false (ready)
    gap > 2 500 ms since last step                          → force inPeak = false
```

**Constants summary:**

| Constant | Value | Meaning |
|---|---|---|
| `_gravAlpha` | 0.85 | Gravity LP — time constant ≈ 300 ms at 20 Hz |
| `_magAlpha` | 0.35 | Magnitude smoothing LP |
| `_maxDecay` | 0.994 | RunningMax decay/sample — halves in ~5.75 s |
| `_thresholdFactor` | 0.52 | Threshold = 52% of runningMax |
| `_valleyFactor` | 0.28 | Valley = 28% of threshold |
| `_minThreshold` | 0.9 m/s² | Absolute floor — prevents false steps while still |
| `_maxThreshold` | 5.0 m/s² | Absolute ceiling — prevents threshold runaway |
| `_minStepInterval` | 250 ms | Max cadence: 4 steps/s (sprinting) |
| `_maxStepInterval` | 2 500 ms | Peak-lock auto-release after long pause |
| `_calsPerStep` | 0.045 kcal | ≈ 450 kcal / 10 000 steps for ~70 kg adult |

---

## 11. Dependencies

### Production

| Package | Version | Purpose |
|---|---|---|
| `provider` | ^6.1.2 | State management |
| `google_sign_in` | ^6.2.1 | Google OAuth |
| `firebase_core` | ^3.8.0 | Firebase initialisation |
| `firebase_auth` | ^5.3.1 | Firebase Auth |
| `cloud_firestore` | ^5.4.5 | Database |
| `google_generative_ai` | ^0.4.6 | Gemini AI (chat + reports) |
| `health` | ^12.0.0 | Health Connect / HealthKit |
| `sensors_plus` | ^4.0.2 | Accelerometer |
| `permission_handler` | ^11.3.1 | Runtime permissions |
| `flutter_tts` | ^4.0.2 | Voice coaching cues |
| `fl_chart` | ^0.68.0 | Calorie line charts |
| `shared_preferences` | ^2.3.2 | Local profile/session cache |
| `google_fonts` | ^6.2.1 | Inter typeface |
| `cached_network_image` | ^3.3.1 | Profile photo caching |
| `http` | ^1.2.2 | Web sync service |
| `intl` | ^0.19.0 | Date formatting |
| `uuid` | ^4.4.2 | Session ID generation |

### Dev

| Package | Version | Purpose |
|---|---|---|
| `flutter_lints` | ^4.0.0 | Lint rules |
| `flutter_launcher_icons` | ^0.13.1 | Icon generation (supplemental) |

---

## 12. Android Configuration

| Setting | Value |
|---|---|
| **Namespace** | `com.fitverse.app` |
| **Application ID** | `com.ma.fitverse` |
| **compileSdk / targetSdk** | 36 |
| **minSdk** | 26 (required by `health` for Health Connect) |
| **NDK** | 28.2.13676358 |
| **Java / Kotlin target** | 17 |
| **MultiDex** | enabled |
| **MainActivity base** | `FlutterFragmentActivity` (required for Health Connect `ActivityResultLauncher`) |

### Required Permissions (AndroidManifest.xml)

```
android.permission.INTERNET
android.permission.ACCESS_NETWORK_STATE
android.permission.BODY_SENSORS
android.permission.BODY_SENSORS_BACKGROUND
android.permission.ACTIVITY_RECOGNITION
android.permission.health.READ_HEART_RATE
android.permission.health.READ_OXYGEN_SATURATION       ← NOT READ_BLOOD_OXYGEN
android.permission.health.READ_STEPS
android.permission.health.READ_ACTIVE_CALORIES_BURNED
android.permission.POST_NOTIFICATIONS
android.permission.RECEIVE_BOOT_COMPLETED
android.permission.VIBRATE
android.permission.WAKE_LOCK
android.permission.FOREGROUND_SERVICE
android.permission.FOREGROUND_SERVICE_HEALTH
android.permission.RECORD_AUDIO
```

### MethodChannels

| Channel | Direction | Purpose |
|---|---|---|
| `com.fitverse.app/step_service` | Flutter → Kotlin | `startService` / `stopService` for `StepCounterService` |
| `com.fitverse.app/shared_prefs` | Flutter → Kotlin | `getStepData` → returns `{steps: Int, cals: Double}` from SharedPreferences |

---

## 13. AI Integration

### Gemini Setup

```dart
// ai_provider.dart
const _kGeminiKey   = 'AIzaSy...';   // ⚠️ Move to --dart-define before production
const _kChatModel   = 'gemini-2.5-flash';
const _kReportModel = 'gemini-2.5-flash';

GenerationConfig(temperature: 0.8, maxOutputTokens: 2048)
```

### System Prompt Content

- User profile: name, age, gender, weight, height, BMI + category, fitness goal, health conditions.
- Last 5 workout sessions: name, muscle group, duration, calories, accuracy score, AI suggestion.
- Persona: professional personal trainer "Coach" — encouraging, specific, health-condition-aware.

### Date Formatting in Prompts

All `DateTime` values injected into the Gemini prompt use `_fmt()`:
```dart
String _fmt(DateTime d) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
  // e.g. "5 Jun 2026" — unambiguous regardless of model locale
}
```
**Never use numeric-only `d/m/y` or `m/d/y` — the model misreads the month as the day.**

### Context Refresh

`refreshContext()` is called when `UserProvider.sessions.length` changes. Rebuilds system prompt and re-seeds `ChatSession` history — the chat UI is preserved.

---

## 14. Firestore Sync Behaviour

| Event | SharedPreferences | Firestore |
|---|---|---|
| App launch | Read immediately | Fetch in background, reconcile |
| Profile setup | Write instantly | Push async |
| Finish workout | Write instantly | Push async (counters recomputed from full list) |
| Edit profile | Write instantly | Push async |
| Clear sessions | Delete locally | Batch delete |
| Counter drift detected | Recomputed on `_pullSessions` | Patched via merge write |
| Offline | Works from cache | Queued by SDK, auto-retries |
| New device / re-login | Empty local | Full profile + last 50 sessions fetched |

---

## 15. Common Patterns & Conventions

### Error Handling

Providers catch all exceptions internally and set `_error` string. Screens check `provider.error != null` for error UI. `WebSyncService` silently swallows all HTTP errors.

### Null Safety

Full Dart null safety. UID is obtained fresh from `FirebaseAuth.instance.currentUser?.uid` at each Firestore operation — never cached as a field.

### State Reset on Sign-Out

`AuthProvider.signOut()` → call `UserProvider.reset()`. `AIProvider` state is implicitly cleared by auth routing back to `OnboardingScreen`.

### Provider Access Pattern

```dart
// Reactive rebuild
final user = context.watch<UserProvider>().user;

// One-time read
await context.read<WorkoutProvider>().stopTracking();
```

### Logging

All providers use `debugPrint('[ProviderName] message')` with emoji prefixes:
- `✅` success
- `⚠️` warning / degraded
- `❌` error / failure
- `🔧` auto-repair (e.g. counter reconciliation)

---

## 16. Known Issues & Technical Debt

| Item | Details |
|---|---|
| **Hardcoded Gemini API key** | `_kGeminiKey` in `ai_provider.dart` must be moved to `--dart-define` or secrets vault before production |
| **Accelerometer rep counting** | ✅ Fixed (June 2026). `WorkoutProvider._processAccelerometer()` now uses the same four-stage adaptive pipeline as `HealthProvider` (gravity removal → dynamic magnitude → smoothing LP → adaptive peak detection). Constants tuned for resistance-exercise rep cadence: minThresh 1.5 m/s², minRepInterval 450 ms, maxDecay 0.990/sample. |
| **No unit tests** | `flutter_test` dev dep is set up but no tests exist |
| **Web sync is optional** | `WebSyncService` posts to Railway backend; backend must exist independently |
| **iOS not configured** | No `ios/` platform directory; Health Connect calls need HealthKit equivalents |
| **`gifUrl` CDN dependency** | Exercise animations depend on a third-party GitHub repo; add caching and fallbacks |

---

## 17. Build Lessons (Costly to Re-Learn)

| Lesson | Detail |
|---|---|
| **Flutter Gradle plugin** | `dev.flutter.flutter-gradle-plugin` must be loaded via `includeBuild` from the local Flutter SDK — never pin a version or load from Maven |
| **AGP + Kotlin classpath** | AGP 8.2+ can break `implementation` propagation to Kotlin compile classpath; explicit `compileOnly` Flutter engine JAR references may be needed |
| **`FlutterFragmentActivity`** | `MainActivity` must extend `FlutterFragmentActivity` (not `FlutterActivity`) for Health Connect's `ActivityResultLauncher` to register |
| **Health Connect minSdk** | `minSdk 26` required; correct permission is `READ_OXYGEN_SATURATION` not `READ_BLOOD_OXYGEN` |
| **Firebase Auth bridge** | Google Sign-In UID ≠ Firebase Auth UID. Always use `FirebaseAuth.instance.currentUser?.uid` for Firestore paths, never the Google account ID |
| **Adaptive icon foreground** | Must be in `mipmap-*` and referenced as `@mipmap/ic_launcher_foreground`. Putting it only in `drawable/` causes AAPT link failure in release builds |
| **Counter drift** | `user.totalWorkouts` / `user.totalCalories` stored on the Firestore user doc can be zero even when sessions exist. Always derive these from the sessions list for display |
| **AI date format** | Use `"5 Jun 2026"` in Gemini prompts, never numeric `5/6/2026` — the model reads numeric format as MM/DD |

---

## 18. Getting Started (Developer Quickstart)

```bash
# 1. Clone and install dependencies
flutter pub get

# 2. Add your Gemini API key
#    Edit lib/providers/ai_provider.dart → _kGeminiKey

# 3. Firebase is already configured for fitverse-6513c.
#    To use your own project:
flutterfire configure

# 4. Deploy Firestore security rules
firebase deploy --only firestore:rules

# 5. Run on Android device / emulator (minSdk 26+)
flutter run

# 6. Build release APK
flutter clean
flutter build apk --release
```

> Health Connect features require a physical Android device running Android 9+ with Health Connect installed. The adaptive accelerometer fallback works on any Android device (minSdk 26+) and in emulators (though emulator accelerometer data is synthetic).

---

## 19. Firebase Project Details

| Setting | Value |
|---|---|
| Project ID | `fitverse-6513c` |
| Android namespace | `com.fitverse.app` |
| Android application ID | `com.ma.fitverse` |
| Auth providers | Google Sign-In |
| Firestore mode | Production (rules-enforced) |
| Offline persistence | Enabled, cache size unlimited |

---

## 20. Project Documentation

| File | Purpose | Update when... |
|---|---|---|
| `README.md` | User/developer-facing docs — features, screenshots, tech stack, build-from-source steps, permissions, troubleshooting | A feature ships, a dependency version changes, or setup steps change |
| `CHANGELOG.md` | Version history in [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format, [SemVer](https://semver.org/) | Every release — add an `[Unreleased]` section as you work, cut a dated version section on release |
| `LICENSE` | MIT license text | Rarely — only if the license type changes |
| `CLAUDE.md` (this file) | Internal architecture/convention reference for AI agents and contributors | Architecture, conventions, or major features change (see banner at top) |

**Current release:** `1.0.0` (see `CHANGELOG.md` for the full list of what shipped).

> **⚠️ Placeholder to resolve before any public release:** `LICENSE` and the README's License section both use `[Your Name or Organization]` as the copyright holder — replace with the actual author/org name. This is independent of the `_kGeminiKey` hardcoded-secret issue tracked in §16.

---

*Last updated: June 2026 — reflects codebase as of fitverse_v13, plus root-level README.md rewrite, CHANGELOG.md (v1.0.0), and LICENSE (MIT) added.*