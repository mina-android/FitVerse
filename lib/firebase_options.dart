// File generated from google-services.json following the FlutterFire CLI
// convention (flutterfire configure).  Explicit FirebaseOptions avoids
// dependency on the Google Services Gradle plugin generating a values.xml at
// build time, which is the root cause of the
// "Failed to load FirebaseOptions from resource" error.
//
// Source: android/app/google-services.json
// Project: fitverse-6513c

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'FitVerse is an Android-only app. '
        'Web is not supported.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'FitVerse only targets Android. '
          'Platform $defaultTargetPlatform is not supported.',
        );
      default:
        throw UnsupportedError(
          'Unknown platform: $defaultTargetPlatform',
        );
    }
  }

  // Values sourced directly from android/app/google-services.json:
  //   client[0].client_info.mobilesdk_app_id  → appId
  //   client[0].api_key[0].current_key         → apiKey
  //   project_info.project_number              → messagingSenderId
  //   project_info.project_id                  → projectId
  //   project_info.storage_bucket              → storageBucket
  //   client[0].oauth_client[type=1].client_id → androidClientId
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyByl43D9_G5BrJ1tAygaa2Ni-VmsPicSMM',
    appId: '1:769133616537:android:0fd65461e4ba1a8d33c708',
    messagingSenderId: '769133616537',
    projectId: 'fitverse-6513c',
    storageBucket: 'fitverse-6513c.firebasestorage.app',
    androidClientId:
        '769133616537-39bj3rspphf15vqqbfql9eoevqhvp33u.apps.googleusercontent.com',
  );
}
