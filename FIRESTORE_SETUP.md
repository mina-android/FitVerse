# FitVerse — Firestore Setup Guide

## 1. Enable Firestore in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com) → `fitverse-6513c`
2. Left sidebar → **Build** → **Firestore Database**
3. Click **Create database**
4. Choose **Production mode** (rules are deployed separately)
5. Select your preferred region (e.g. `europe-west1` or `us-central1`)
6. Click **Done**

---

## 2. Deploy Security Rules

Install Firebase CLI if not already installed:
```bash
npm install -g firebase-tools
firebase login
```

From the project root (where `firestore.rules` lives):
```bash
firebase init firestore    # select existing project: fitverse-6513c
firebase deploy --only firestore:rules
```

---

## 3. Firestore Data Structure

```
Firestore
└── users/                          ← collection
    └── {uid}/                      ← document (one per user)
        ├── name: "Alex"
        ├── email: "alex@gmail.com"
        ├── photoUrl: "https://..."
        ├── age: 28
        ├── weightKg: 85.0
        ├── heightCm: 180.0
        ├── gender: "Male"
        ├── healthConditions: ["Mild Asthma"]
        ├── fitnessGoal: "Muscle Gain"
        ├── totalWorkouts: 12
        ├── totalCalories: 4200.0
        ├── lastSyncedAt: Timestamp
        └── sessions/               ← subcollection
            └── {sessionId}/        ← document (one per workout)
                ├── id: "1717364400000"
                ├── workoutName: "Advanced Chest & Triceps"
                ├── muscleGroup: "Chest"
                ├── date: Timestamp
                ├── durationMinutes: 45
                ├── caloriesBurned: 350.0
                ├── accuracyScore: 87.5
                ├── musclesWorked: ["Pectorals", "Triceps"]
                ├── intensity: "High"
                ├── aiSuggestion: "Great intensity, Alex..."
                └── exerciseNames: ["Bench Press", "Cable Crossover"]
```

---

## 4. Sync Behaviour

| Event | Local (SharedPreferences) | Firestore |
|---|---|---|
| App launch | Read immediately | Fetch in background, reconcile |
| Profile setup | Write instantly | Push async |
| Finish workout | Write instantly | Push async |
| Edit profile | Write instantly | Push async |
| Clear sessions | Delete locally | Batch delete via Firestore |
| Offline | Works from cache | Queued by Firebase SDK, auto-retries |
| New device / re-login | Empty local | Full profile + last 50 sessions fetched |

---

## 5. What the login now does

**Before (v8):** Google Sign-In authenticated the user, but all data
lived only on the device. Logging in on a new phone showed an empty profile.

**After (v9):** On every login the app calls `UserProvider.syncFromCloud(uid)`:

1. Local cache is read first (instant UI, no blank screen)
2. Firestore `/users/{uid}` is fetched — if it exists, the cloud profile
   overwrites the local cache (cloud is authoritative)
3. The last 50 sessions are fetched from the `/sessions` subcollection
   and merged with any locally-only sessions (union, deduplicated by ID)
4. If the device is offline, step 1 alone is used — the app works fully
   in cached mode and syncs automatically when connectivity resumes

---

## 6. Chinese Wall preservation

The Firestore rules explicitly **reject** documents containing any of:
`passwordHash`, `token`, `refreshToken`, `credential`, `secret`

The `UserModel` class contains none of these fields by design.
Firebase Auth handles all credentials separately and never passes them
to `UserProvider` or `AIProvider`.

---

## 7. Indexes (auto-created)

The only query that requires a composite index is:
```
Collection: sessions
Fields: date DESC
```
Firestore creates this automatically on first query. If you add more
filtered queries later, the Firebase Console will show a link to create
the required index.
