import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Central service for syncing mobile data to the FitVerse web backend.
/// All methods are fire-and-forget — they never throw or affect mobile UX.
class WebSyncService {
  // ── Change this to your deployed backend URL when you go to production ──
  static const String _baseUrl = 'https://fitverse-backend-production.up.railway.app/api';
  // Note: 10.0.2.2 is how Android emulator reaches your PC's localhost.
  // On a real device use your PC's local IP e.g. 'http://192.168.1.100:8000/api'

  /// Returns the Firebase ID token for the current user, or null if not signed in.
  static Future<String?> _getToken() async {
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (_) {
      return null;
    }
  }

  /// Shared POST helper.
  static Future<void> _post(String path, Map<String, dynamic> body) async {
    final token = await _getToken();
    if (token == null) return;
    try {
      await http.post(
        Uri.parse('$_baseUrl$path'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      // Silent fail — never affect mobile UX
      debugPrint('[WebSync] $path failed: $e');
    }
  }

  // ─────────────────────────────────────────────
  // 1. Push user profile (called after login / profile update)
  // ─────────────────────────────────────────────
  static Future<void> pushProfile({
    required String displayName,
    required String email,
    required String photoUrl,
    required int age,
    required double weightKg,
    required double heightCm,
    required String gender,
    required List<String> healthConditions,
    required String fitnessGoal,
    required int totalWorkouts,
    required double totalCalories,
  }) async {
    await _post('/profile/', {
      'display_name': displayName,
      'email': email,
      'photo_url': photoUrl,
      'age': age,
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'gender': gender,
      'health_conditions': healthConditions,
      'fitness_goal': fitnessGoal,
      'total_workouts': totalWorkouts,
      'total_calories': totalCalories,
    });
  }

  // ─────────────────────────────────────────────
  // 2. Push today's steps + calories (called after each health fetch)
  // ─────────────────────────────────────────────
  static Future<void> pushDailySteps({
    required int steps,
    required double calories,
  }) async {
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await _post('/steps/', {
      'date': dateStr,
      'steps': steps,
      'calories': calories,
    });
  }

  // ─────────────────────────────────────────────
  // 3. Push a completed workout session
  // ─────────────────────────────────────────────
  static Future<void> pushSession({
    required String sessionId,
    required String workoutName,
    required String muscleGroup,
    required DateTime date,
    required int durationMinutes,
    required double caloriesBurned,
    required double accuracyScore,
    required List<String> musclesWorked,
    required String intensity,
    required String aiSuggestion,
  }) async {
    await _post('/sessions/', {
      'session_id': sessionId,
      'workout_name': workoutName,
      'muscle_group': muscleGroup,
      'date': date.toUtc().toIso8601String(),
      'duration_minutes': durationMinutes,
      'calories_burned': caloriesBurned,
      'accuracy_score': accuracyScore,
      'muscles_worked': musclesWorked,
      'intensity': intensity,
      'ai_suggestion': aiSuggestion,
    });
  }

  // ─────────────────────────────────────────────
  // 4. Push a chat message (called after every send + every AI reply)
  // ─────────────────────────────────────────────
  static Future<void> pushChatMessage({
    required String role,   // 'user' or 'model'
    required String content,
  }) async {
    await _post('/chat/send-mobile/', {
      'role': role,
      'content': content,
    });
  }
}
