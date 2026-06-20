import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/workout_model.dart';

// ─── Firestore collection / document helpers ──────────────────────────────────
//
//  Structure:
//    /users/{uid}                 ← UserModel fields
//    /users/{uid}/sessions/{id}   ← SessionModel fields
//
// The UID is ALWAYS taken from FirebaseAuth.instance.currentUser.uid at the
// moment of each operation — never stored as a field or passed as a parameter.

DocumentReference<Map<String, dynamic>> _userDoc() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw StateError('Firebase Auth not signed in');
  return FirebaseFirestore.instance.collection('users').doc(uid);
}

CollectionReference<Map<String, dynamic>> _sessionsColl() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw StateError('Firebase Auth not signed in');
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('sessions');
}

// ─── Provider ────────────────────────────────────────────────────────────────

class UserProvider extends ChangeNotifier {
  // Firebase / Firestore is always available (initialised with explicit options
  // in main.dart).  The firestoreEnabled constructor parameter has been removed.
  UserProvider();

  UserModel?         _user;
  List<SessionModel> _sessions  = [];
  bool               _isLoading = false;
  String?            _syncStatus;

  UserModel?         get user        => _user;
  List<SessionModel> get sessions    => _sessions;
  bool               get isLoading   => _isLoading;
  bool               get hasProfile  => _user != null;
  String?            get syncStatus  => _syncStatus;

  List<SessionModel> get recentSessions => (List<SessionModel>.from(_sessions)
        ..sort((a, b) => b.date.compareTo(a.date)))
      .take(5)
      .toList();

  // ── Cache key helpers ─────────────────────────────────────────────────────

  String? get _cacheUid => FirebaseAuth.instance.currentUser?.uid;

  String _profileKey(String uid)  => 'fitverse_profile_$uid';
  String _sessionsKey(String uid) => 'fitverse_sessions_$uid';

  // ── RESET (call on sign-out to prevent data bleeding into the next session) ─

  void reset() {
    _user       = null;
    _sessions   = [];
    _isLoading  = false;
    _syncStatus = null;
    notifyListeners();
    debugPrint('[UserProvider] State reset');
  }

  // ── SYNC (called once after authentication is confirmed) ─────────────────

  /// Loads data from local cache immediately, then pulls fresh data from
  /// Firestore in the background.  [fallbackUid] is ignored — kept for
  /// call-site compatibility only (Firebase Auth UID is always used).
  Future<void> syncFromCloud({String? fallbackUid}) async {
    _user       = null;
    _sessions   = [];
    _isLoading  = true;
    _syncStatus = 'Syncing…';
    notifyListeners();

    final uid = _cacheUid;
    if (uid == null) {
      debugPrint('[UserProvider] ⚠️  No UID — skipping sync');
      _isLoading  = false;
      _syncStatus = 'Not signed in';
      notifyListeners();
      return;
    }

    // 1. Local cache first — instant UI paint
    await _loadCache(uid);
    notifyListeners();

    // 2. Firestore pull — always enabled
    try {
      await _pullProfile();
      await _pullSessions();
      _syncStatus = 'Synced ✓';
      debugPrint('[UserProvider] ✅ Sync complete for $uid');
    } on FirebaseException catch (e) {
      _syncStatus = 'Sync failed (${e.code})';
      debugPrint('[UserProvider] ❌ Firestore [${e.code}]: ${e.message}');
    } catch (e) {
      _syncStatus = 'Sync failed';
      debugPrint('[UserProvider] ❌ Sync error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── READS ─────────────────────────────────────────────────────────────────

  Future<void> _pullProfile() async {
    final snap = await _userDoc().get();
    if (!snap.exists || snap.data() == null) {
      debugPrint('[UserProvider] No Firestore profile — new user');
      return;
    }
    _user = UserModel.fromJson(snap.data()!);
    final uid = _cacheUid!;
    await _saveCache(uid);
    debugPrint('[UserProvider] ✅ Profile loaded from Firestore: ${_user!.name}');
  }

  Future<void> _pullSessions() async {
    final snap = await _sessionsColl()
        .orderBy('date', descending: true)
        .limit(50)
        .get();

    final remote = snap.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      if (data['date'] is Timestamp) {
        data['date'] = (data['date'] as Timestamp).toDate().toIso8601String();
      }
      return SessionModel.fromJson(data);
    }).toList();

    final merged = <String, SessionModel>{
      for (final s in _sessions) s.id: s,
      for (final s in remote)   s.id: s,
    };
    _sessions = (merged.values.toList()
          ..sort((a, b) => b.date.compareTo(a.date)));

    // ── Reconcile stored counters with the actual session list ─────────────
    // The user document counters (totalWorkouts / totalCalories) may be stale
    // if sessions were added before this logic existed. Recompute and patch.
    if (_user != null) {
      final correctWorkouts = _sessions.length;
      final correctCalories = _sessions.fold(
          0.0, (sum, s) => sum + s.caloriesBurned);
      if (_user!.totalWorkouts != correctWorkouts ||
          (_user!.totalCalories - correctCalories).abs() > 0.5) {
        _user = _user!.copyWith(
          totalWorkouts: correctWorkouts,
          totalCalories: correctCalories,
        );
        // Push corrected counters back to Firestore silently
        _userDoc().set(
          {
            'totalWorkouts': correctWorkouts,
            'totalCalories': correctCalories,
            'lastSyncedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        ).catchError((e) {
          debugPrint('[UserProvider] ⚠️ Counter repair write failed: $e');
          return null;
        });
        debugPrint('[UserProvider] 🔧 Corrected counters → '
            '$correctWorkouts workouts, ${correctCalories.round()} kcal');
      }
    }

    final uid = _cacheUid!;
    await _saveCacheSessions(uid);
    if (_user != null) await _saveCache(uid);
    debugPrint('[UserProvider] ✅ ${remote.length} sessions from Firestore');
  }

  // ── WRITES ────────────────────────────────────────────────────────────────

  Future<bool> saveUser(UserModel user) async {
    _user = user;
    notifyListeners();

    final uid = _cacheUid;
    if (uid != null) await _saveCache(uid);

    try {
      await _userDoc().set(
        {
          ...user.toJson(),
          'lastSyncedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      debugPrint('[UserProvider] ✅ Profile written to Firestore');
      return true;
    } on FirebaseException catch (e) {
      debugPrint('[UserProvider] ❌ Profile write [${e.code}]: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[UserProvider] ❌ Profile write error: $e');
      return false;
    }
  }

  Future<void> addSession(SessionModel session) async {
    // Avoid duplicate entries (e.g. preset flow calling twice)
    if (!_sessions.any((s) => s.id == session.id)) {
      _sessions.add(session);
    }

    if (_user != null) {
      // Always recompute from the full sessions list — never rely on the
      // previously stored counter which may be stale or zero.
      final totalWorkouts = _sessions.length;
      final totalCalories = _sessions.fold(
          0.0, (sum, s) => sum + s.caloriesBurned);
      _user = _user!.copyWith(
        totalWorkouts: totalWorkouts,
        totalCalories: totalCalories,
      );
    }

    notifyListeners();

    final uid = _cacheUid;
    if (uid != null) {
      await _saveCache(uid);
      await _saveCacheSessions(uid);
    }

    if (_user != null) {
      try {
        await _userDoc().set(
          {
            ...(_user!.toJson()),
            'lastSyncedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } on FirebaseException catch (e) {
        debugPrint('[UserProvider] ❌ Profile update [${e.code}]: ${e.message}');
      }
    }

    try {
      final data = <String, dynamic>{
        ...session.toJson(),
        'date': Timestamp.fromDate(session.date),
      };
      await _sessionsColl().doc(session.id).set(data);
      debugPrint('[UserProvider] ✅ Session written to Firestore');
    } on FirebaseException catch (e) {
      debugPrint('[UserProvider] ❌ Session write [${e.code}]: ${e.message}');
    } catch (e) {
      debugPrint('[UserProvider] ❌ Session write error: $e');
    }
  }

  Future<bool> createUser({
    required String uid,
    required String name,
    required String email,
    String?         photoUrl,
    required int    age,
    required double weightKg,
    required double heightCm,
    required String gender,
    required List<String> healthConditions,
    required String fitnessGoal,
  }) {
    return saveUser(UserModel(
      uid:              uid,
      name:             name,
      email:            email,
      photoUrl:         photoUrl,
      age:              age,
      weightKg:         weightKg,
      heightCm:         heightCm,
      gender:           gender,
      healthConditions: healthConditions,
      fitnessGoal:      fitnessGoal,
    ));
  }

  Future<void> updateProfile({
    String? name,
    int?    age,
    double? weightKg,
    double? heightCm,
    String? gender,
    List<String>? healthConditions,
    String? fitnessGoal,
  }) async {
    if (_user == null) return;
    await saveUser(_user!.copyWith(
      name:             name,
      age:              age,
      weightKg:         weightKg,
      heightCm:         heightCm,
      gender:           gender,
      healthConditions: healthConditions,
      fitnessGoal:      fitnessGoal,
    ));
  }

  Future<void> clearSessions() async {
    if (_user == null) return;
    _sessions = [];
    _user = _user!.copyWith(totalWorkouts: 0, totalCalories: 0);
    notifyListeners();

    final uid = _cacheUid;
    if (uid != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionsKey(uid));
      await _saveCache(uid);
    }

    try {
      await _userDoc().set(
        {..._user!.toJson(), 'lastSyncedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      final snap = await _sessionsColl().get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) batch.delete(doc.reference);
      await batch.commit();
      debugPrint('[UserProvider] ✅ Sessions cleared in Firestore');
    } catch (e) {
      debugPrint('[UserProvider] ❌ clearSessions error: $e');
    }
  }

  // ── Local cache ───────────────────────────────────────────────────────────

  Future<void> _loadCache(String uid) async {
    final prefs = await SharedPreferences.getInstance();

    final pJson = prefs.getString(_profileKey(uid));
    if (pJson != null) {
      try {
        _user = UserModel.fromJson(jsonDecode(pJson) as Map<String, dynamic>);
        debugPrint('[UserProvider] Profile from local cache');
      } catch (e) {
        debugPrint('[UserProvider] Cache parse error: $e');
        _user = null;
      }
    }

    final sJson = prefs.getString(_sessionsKey(uid));
    if (sJson != null) {
      try {
        _sessions = (jsonDecode(sJson) as List)
            .map((e) => SessionModel.fromJson(e as Map<String, dynamic>))
            .toList();
        debugPrint('[UserProvider] ${_sessions.length} sessions from cache');
      } catch (e) {
        debugPrint('[UserProvider] Sessions cache error: $e');
        _sessions = [];
      }
    }
  }

  Future<void> _saveCache(String uid) async {
    if (_user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey(uid), jsonEncode(_user!.toJson()));
  }

  Future<void> _saveCacheSessions(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sessionsKey(uid),
      jsonEncode(_sessions.map((s) => s.toJson()).toList()),
    );
  }

  // ── Compat shim ───────────────────────────────────────────────────────────
  Future<void> loadFromPrefs(String uid) => syncFromCloud();
}
