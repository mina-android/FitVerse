import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/health_provider.dart';
import 'providers/workout_provider.dart';
import 'providers/ai_provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Firebase with explicit options sourced from google-services.json.
  // Using DefaultFirebaseOptions.currentPlatform bypasses the Gradle
  // google-services plugin's values.xml generation, which is the root cause of
  // the "Failed to load FirebaseOptions from resource" runtime error.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Firestore offline persistence is enabled by default on Android.
  // Setting it explicitly here ensures consistent behaviour and unlimited
  // local cache size for offline workout history.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  debugPrint('[FitVerse] ✅ Firebase initialised');

  // Load any user-saved Gemini API key from SharedPreferences before the UI
  // starts, so AIProvider.activeKey is correct from the very first frame.
  final aiProvider = AIProvider();
  await aiProvider.loadSavedApiKey();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => HealthProvider()),
        ChangeNotifierProvider(create: (_) => WorkoutProvider()),
        ChangeNotifierProvider(create: (_) => aiProvider),
      ],
      child: const FitVerseApp(),
    ),
  );
}
