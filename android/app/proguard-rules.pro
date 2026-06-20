# FitVerse ProGuard / R8 rules
# minifyEnabled is false for both debug and release right now, so these rules
# are not active. They are here so the build.gradle reference resolves cleanly.

# Flutter engine
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Health Connect
-keep class androidx.health.connect.** { *; }

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }
