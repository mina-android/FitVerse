import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/health_provider.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/auth/profile_setup_screen.dart';
import 'features/main/main_shell.dart';

class FitVerseApp extends StatelessWidget {
  const FitVerseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return MaterialApp(
          title: 'FitVerse',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.dark,
          home: switch (auth.authState) {
            AuthState.unknown        => const _SplashScreen(),
            AuthState.unauthenticated => const OnboardingScreen(),
            AuthState.newUser        => const ProfileSetupScreen(),
            AuthState.authenticated  => const _AuthenticatedRoot(),
          },
        );
      },
    );
  }
}

// ─── Authenticated root ───────────────────────────────────────────────────────
//
// Runs exactly once per authentication session.
// Waits for Firebase Auth to be ready, then syncs Firestore → shows shell.

class _AuthenticatedRoot extends StatefulWidget {
  const _AuthenticatedRoot();
  @override
  State<_AuthenticatedRoot> createState() => _AuthenticatedRootState();
}

class _AuthenticatedRootState extends State<_AuthenticatedRoot> {
  bool    _ready   = false;
  String  _message = 'Starting up…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    setState(() => _message = 'Signing you in…');

    // Firebase is always initialised.  Wait up to 8 s for the Firebase Auth
    // session to be restored (signInSilently + credential bridge can take a
    // moment on first launch or after a token refresh).
    for (int i = 0; i < 16; i++) {
      if (FirebaseAuth.instance.currentUser != null) break;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (!mounted) return;
    setState(() => _message = 'Restoring your profile…');

    await context.read<UserProvider>().syncFromCloud().catchError((e) {
      debugPrint('[App] syncFromCloud error: $e');
    });

    if (!mounted) return;
    context.read<HealthProvider>().startAccelMode();
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return _SplashScreen(message: _message);

    final hasProfile = context.watch<UserProvider>().hasProfile;
    return hasProfile ? const MainShell() : const ProfileSetupScreen();
  }
}

// ─── Splash ───────────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  final String message;
  const _SplashScreen({this.message = 'Loading…'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.seedColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.fitness_center,
                  color: Colors.white, size: 44),
            ),
            const SizedBox(height: 20),
            const Text('FitVerse',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
                color: AppTheme.seedColor, strokeWidth: 2),
            const SizedBox(height: 16),
            Text(message,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.45), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
