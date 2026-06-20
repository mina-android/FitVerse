import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AuthState { unknown, unauthenticated, newUser, authenticated }

class AuthProvider extends ChangeNotifier {
  // Firebase is always initialised (via DefaultFirebaseOptions in main.dart).
  // The firebaseReady constructor parameter has been removed — Firestore and
  // Firebase Auth are unconditionally enabled.
  AuthProvider() {
    _restoreSession();
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  AuthState            _state      = AuthState.unknown;
  GoogleSignInAccount? _googleUser;
  String?              _firebaseUid;
  String?              _error;

  AuthState            get authState   => _state;
  GoogleSignInAccount? get googleUser  => _googleUser;
  String?              get error       => _error;

  /// UID used for every Firestore path — always the Firebase Auth UID.
  String? get uid => _firebaseUid;

  bool get isSignedIn =>
      _state == AuthState.authenticated || _state == AuthState.newUser;

  // ── Session restore (cold start) ─────────────────────────────────────────

  Future<void> _restoreSession() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) {
        _state = AuthState.unauthenticated;
        notifyListeners();
        return;
      }
      _googleUser = account;
      await _bridgeToFirebaseAuth(account);
      _state = AuthState.authenticated;
    } catch (e) {
      debugPrint('[Auth] Restore session error: $e');
      _state = _googleUser != null
          ? AuthState.authenticated
          : AuthState.unauthenticated;
    }
    notifyListeners();
  }

  // ── Interactive sign-in ───────────────────────────────────────────────────

  Future<bool> signInWithGoogle({bool isNewUser = false}) async {
    _error = null;
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        _error = 'Sign-in cancelled.';
        notifyListeners();
        return false;
      }
      _googleUser = account;
      await _bridgeToFirebaseAuth(account);
      _state = isNewUser ? AuthState.newUser : AuthState.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _state  = AuthState.unauthenticated;
      debugPrint('[Auth] signInWithGoogle failed: $e');
      notifyListeners();
      return false;
    }
  }

  // ── Firebase Auth bridge ──────────────────────────────────────────────────
  //
  // Exchanges the Google credential for a Firebase Auth session so that
  // request.auth.uid is populated in Firestore security rules.
  // Errors are logged but not rethrown — the user remains signed in to Google
  // even if the bridge fails (e.g. no network), and Firestore will use its
  // offline cache.

  Future<void> _bridgeToFirebaseAuth(GoogleSignInAccount account) async {
    try {
      final existing = FirebaseAuth.instance.currentUser;
      if (existing != null) {
        _firebaseUid = existing.uid;
        debugPrint('[Auth] ✅ Firebase Auth already active: $_firebaseUid');
        return;
      }

      final googleAuth = await account.authentication;
      final credential  = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );
      final result = await FirebaseAuth.instance.signInWithCredential(credential);
      _firebaseUid = result.user?.uid;
      debugPrint('[Auth] ✅ Firebase Auth signed in: $_firebaseUid');
    } catch (e) {
      _firebaseUid = null;
      debugPrint('[Auth] ⚠️  Firebase Auth bridge failed: $e');
    }
  }

  // ── Profile complete ──────────────────────────────────────────────────────

  void markProfileComplete() {
    _state = AuthState.authenticated;
    notifyListeners();
  }

  // ── Sign-out ─────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    try { await _googleSignIn.signOut(); } catch (_) {}
    try { await FirebaseAuth.instance.signOut(); } catch (_) {}
    _googleUser  = null;
    _firebaseUid = null;
    _state       = AuthState.unauthenticated;
    notifyListeners();
  }
}
