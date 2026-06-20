# Changelog

All notable changes to FitVerse are documented in this file.

---

## [1.0.0] — 2026-06-20

Initial release.

### Added

**Authentication & Onboarding**
- Google Sign-In bridged to Firebase Auth, so `request.auth.uid` is populated for every Firestore operation
- 4-state auth machine (`unknown → unauthenticated → newUser → authenticated`) with silent session restore on cold start
- Onboarding flow: intro carousel → profile setup → optional health conditions screen
- Profile setup capturing name, age, gender, height, weight, and fitness goal (Build Muscle, Lose Weight, Improve Endurance, General Fitness, Athletic Performance)
- Optional health conditions checklist (8 presets) feeding directly into AI Coach context

**Home Dashboard**
- Live metric cards for heart rate, blood oxygen (SpO2), steps, and calories burned
- 7-day activity bar chart
- Recent workout history cards
- AI-generated nutrition/recovery suggestion banner
- Stats row (Workouts / Total kcal / BMI) computed live from the session list

**Workout Library**
- 20 muscle groups and 93 exercises, each with difficulty, equipment, sets/reps, step-by-step instructions, form cues, calorie estimate, and muscles worked
- 18 curated multi-exercise workout presets across beginner, intermediate, and advanced levels
- Interactive anatomical body map (custom-painted, front/back toggle) for browsing by muscle group
- Animated exercise previews sourced from the free-exercise-db GitHub repository, with emoji fallback

**Live Form Tracking**
- Accelerometer-based rep counting and form-quality scoring during live workouts
- Four-stage adaptive signal pipeline (gravity removal → dynamic magnitude → smoothing → adaptive peak detection) tuned for resistance-exercise cadence
- Spoken form-correction cues via text-to-speech with a cooldown to prevent alert spam
- Solo workout mode (saves on exit) and preset mode (aggregates exercise sub-sessions into one combined record)
- Automatic AI-generated workout report on session completion

**AI Coach (Gemini)**
- Gemini 2.5 Flash-powered chat assistant aware of the user's profile, BMI, health conditions, and last 5 workout sessions
- Quick-prompt chips for workout analysis, post-workout nutrition, muscle-building tips, rest recommendations, and recovery routines
- Context auto-refresh on new sessions without resetting the active conversation
- Persistent per-user chat history stored in Firestore
- In-app management of a personal Gemini API key (add, update, reset to built-in default) with validation and masked display

**Health & Activity Tracking**
- Google Health Connect pipeline for live heart rate, SpO2, steps, and active calories
- Adaptive accelerometer pedometer fallback for devices without Health Connect or denied permissions
- Foreground service to keep step counting alive while the app is backgrounded
- Daily health snapshots synced to Firestore for cross-device history

**Cloud Sync (Firestore)**
- Two-layer persistence: instant local cache (SharedPreferences) plus authoritative Firestore storage
- Cloud-first reconciliation on login — profile and last 50 sessions are fetched and merged with local data by session ID
- Automatic detection and silent correction of counter drift between cached totals and the real session list
- Full offline support with automatic retry once connectivity is restored
- Firestore security rules enforcing per-user ownership and rejecting documents containing credential-like fields

**Profile & Settings**
- Profile screen with BMI and BMI category display
- Voice alert (TTS) toggle
- Health Connect connect/disconnect controls
- Workout history clearing with confirmation
- Sign-out flow that resets all provider state

**Branding & Platform**
- Adaptive Android app icon (legacy, round, and adaptive-foreground variants) across all densities
- Dark teal splash screen
- Android configuration: minSdk 26, target/compileSdk 36, Kotlin 2.1.21, AGP 8.7.3, Gradle 8.10.2

### Fixed
- Accelerometer-based rep counting in live workouts now uses the same four-stage adaptive pipeline as the step counter, replacing an earlier simplified threshold approach that produced inconsistent rep counts

