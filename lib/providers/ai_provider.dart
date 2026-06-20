import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/workout_model.dart';
import '../models/user_model.dart';

// ⚠️  Default / compile-time fallback key.
//     Users can override this at runtime via Settings → AI Configuration.
//     Move to --dart-define before production.
const _kGeminiKeyDefault = 'AIzaSyB5tTU58CPR-IdCU4-axhBsHopB9RmCm9g';

const _kChatModel   = 'gemini-2.5-flash';
const _kReportModel = 'gemini-2.5-flash';

// SharedPreferences key for the user-supplied API key.
const _kApiKeyPref = 'fitverse_gemini_api_key';

// ── Persistence limits ────────────────────────────────────────────────────────
// How many messages we keep in local cache / Firestore (older ones are dropped).
const _kMaxStoredMessages = 200;
// How many prior turns we re-seed into the Gemini ChatSession on load
// (Gemini has a finite context window; 40 turns ≈ 80 messages is plenty).
const _kReseedTurns = 40;

class AIProvider extends ChangeNotifier {
  List<ChatMessage> _messages      = [];
  bool              _isThinking    = false;
  bool              _isLoadingHistory = false;
  String?           _error;
  bool              _lastReportWasAI = false;

  GenerativeModel? _model;
  ChatSession?     _chat;

  // uid is stored so persistence helpers can access it without a BuildContext.
  String? _uid;

  // Runtime API key (null means fall back to the compile-time default).
  String? _runtimeKey;

  // Whether we are in the middle of validating a new key.
  bool _isValidatingKey = false;

  List<ChatMessage> get messages          => _messages;
  bool              get isThinking        => _isThinking;
  bool              get isLoadingHistory  => _isLoadingHistory;
  String?           get error             => _error;
  bool              get lastReportWasAI   => _lastReportWasAI;
  bool              get isValidatingKey   => _isValidatingKey;

  /// The key currently in use (runtime override wins over compile-time default).
  String get activeKey => _runtimeKey ?? _kGeminiKeyDefault;

  /// Whether a user-supplied key is stored (overriding the default).
  bool get hasCustomKey => _runtimeKey != null && _runtimeKey!.isNotEmpty;

  /// Obfuscated display of the active key, e.g. "AIzaSy••••••••CmKg".
  String get maskedKey {
    final k = activeKey;
    if (k.length <= 10) return '••••••••';
    return '${k.substring(0, 7)}${'•' * (k.length - 10)}${k.substring(k.length - 3)}';
  }

  bool get _keyOk =>
      activeKey != 'YOUR_GEMINI_API_KEY' && activeKey.length >= 20;

  // ── Key persistence ────────────────────────────────────────────────────────

  /// Loads any user-saved key from SharedPreferences on startup.
  Future<void> loadSavedApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kApiKeyPref);
    if (saved != null && saved.isNotEmpty) {
      _runtimeKey = saved;
      debugPrint('[AIProvider] ✅ Loaded saved Gemini API key from prefs');
    }
    notifyListeners();
  }

  /// Validates and saves a new API key.
  /// Returns null on success, or an error string on failure.
  Future<String?> updateApiKey(String newKey) async {
    final trimmed = newKey.trim();

    if (trimmed.isEmpty) {
      return 'API key cannot be empty.';
    }
    if (trimmed.length < 20) {
      return 'Key looks too short. Copy it from ai.google.dev.';
    }

    _isValidatingKey = true;
    notifyListeners();

    // Quick validation: attempt a minimal content generation call.
    try {
      final testModel = GenerativeModel(
        model: _kChatModel,
        apiKey: trimmed,
        generationConfig: GenerationConfig(maxOutputTokens: 5),
      );
      await testModel
          .generateContent([Content.text('Hi')])
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      _isValidatingKey = false;
      notifyListeners();
      final msg = e.toString().toLowerCase();
      if (msg.contains('api_key_invalid') || msg.contains('api key not valid')) {
        return 'API key is invalid. Check it at ai.google.dev.';
      }
      if (msg.contains('quota') || msg.contains('429')) {
        // Quota error means the key IS valid — just quota-limited.
        // Fall through to save.
      } else if (msg.contains('timeout')) {
        return 'Validation timed out — check your connection and try again.';
      } else if (!msg.contains('quota') && !msg.contains('429')) {
        return 'Validation failed: ${e.toString()}';
      }
    }

    // Persist
    _runtimeKey = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiKeyPref, trimmed);

    _isValidatingKey = false;
    debugPrint('[AIProvider] ✅ Gemini API key updated and saved');
    notifyListeners();
    return null; // success
  }

  /// Removes the user-supplied key, reverting to the compile-time default.
  Future<void> clearCustomApiKey() async {
    _runtimeKey = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kApiKeyPref);
    debugPrint('[AIProvider] 🔧 Custom Gemini API key cleared — using default');
    notifyListeners();
  }

  // ── Persistence helpers ────────────────────────────────────────────────────

  static String _prefKey(String uid) => 'fitverse_chat_$uid';

  /// Firestore subcollection path: /users/{uid}/chat_messages
  CollectionReference<Map<String, dynamic>> _chatCol(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chat_messages');

  // ── Load history (SharedPreferences → Firestore merge) ────────────────────

  Future<List<ChatMessage>> _loadHistory(String uid) async {
    // ── Step 1: Local cache ─────────────────────────────────────────────────
    final prefs     = await SharedPreferences.getInstance();
    final raw       = prefs.getString(_prefKey(uid));
    final localList = <ChatMessage>[];
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        localList.addAll(decoded
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList());
      } catch (e) {
        debugPrint('[AIProvider] ⚠️ Failed to decode local chat cache: $e');
      }
    }
    debugPrint('[AIProvider] Loaded ${localList.length} messages from cache');

    // ── Step 2: Firestore merge (background) ────────────────────────────────
    try {
      final snap = await _chatCol(uid)
          .orderBy('timestamp', descending: false)
          .limitToLast(_kMaxStoredMessages)
          .get();

      if (snap.docs.isNotEmpty) {
        final remoteMessages = snap.docs
            .map((d) => ChatMessage.fromJson(d.data()))
            .toList();

        final byId = <String, ChatMessage>{
          for (final m in localList) m.id: m,
          for (final m in remoteMessages) m.id: m,
        };
        final merged = byId.values.toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

        final trimmed = merged.length > _kMaxStoredMessages
            ? merged.sublist(merged.length - _kMaxStoredMessages)
            : merged;

        await _saveToPrefs(uid, trimmed, prefs);
        debugPrint('[AIProvider] ✅ Merged Firestore (${remoteMessages.length}) '
            '+ local (${localList.length}) → ${trimmed.length} messages');
        return trimmed;
      }
    } catch (e) {
      debugPrint('[AIProvider] ⚠️ Firestore chat load failed, '
          'using local cache: $e');
    }

    return localList;
  }

  // ── Save a single new message ────────────────────────────────────────────

  Future<void> _persistMessage(ChatMessage msg) async {
    final uid = _uid;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_prefKey(uid));
    final list  = <ChatMessage>[];
    if (raw != null) {
      try {
        list.addAll((jsonDecode(raw) as List)
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
    list.add(msg);
    final trimmed = list.length > _kMaxStoredMessages
        ? list.sublist(list.length - _kMaxStoredMessages)
        : list;
    await _saveToPrefs(uid, trimmed, prefs);

    try {
      await _chatCol(uid).doc(msg.id).set(msg.toJson());
      _trimFirestore(uid);
    } catch (e) {
      debugPrint('[AIProvider] ⚠️ Firestore chat write failed: $e');
    }
  }

  Future<void> _saveToPrefs(
    String uid,
    List<ChatMessage> messages,
    SharedPreferences prefs,
  ) async {
    final payload = jsonEncode(messages.map((m) => m.toJson()).toList());
    await prefs.setString(_prefKey(uid), payload);
  }

  void _trimFirestore(String uid) async {
    try {
      final col  = _chatCol(uid);
      final snap = await col.orderBy('timestamp', descending: false).get();
      if (snap.docs.length > _kMaxStoredMessages) {
        final toDelete = snap.docs
            .take(snap.docs.length - _kMaxStoredMessages)
            .toList();
        final batch = FirebaseFirestore.instance.batch();
        for (final d in toDelete) {
          batch.delete(d.reference);
        }
        await batch.commit();
        debugPrint('[AIProvider] 🔧 Trimmed ${toDelete.length} old Firestore '
            'chat messages');
      }
    } catch (e) {
      debugPrint('[AIProvider] ⚠️ Firestore trim failed: $e');
    }
  }

  // ── Session init (with history restore) ───────────────────────────────────

  Future<void> initializeSession({
    required UserModel user,
    required List<SessionModel> recentSessions,
    required String uid,
  }) async {
    _uid   = uid;
    _error = null;
    _isLoadingHistory = true;
    notifyListeners();

    if (!_keyOk) {
      _error = 'Gemini API key not configured.';
      _messages = [_welcomeMessage(user, offline: true, hasHistory: false)];
      _isLoadingHistory = false;
      notifyListeners();
      return;
    }

    try {
      final history = await _loadHistory(uid);

      _model = GenerativeModel(
        model: _kChatModel,
        apiKey: activeKey,
        systemInstruction:
            Content.system(_buildSystemPrompt(user, recentSessions)),
        generationConfig: GenerationConfig(
          temperature: 0.8,
          maxOutputTokens: 2048,
        ),
      );

      final realHistory = history.where((m) => !m.isLoading).toList();
      final seedMessages = realHistory.length > _kReseedTurns
          ? realHistory.sublist(realHistory.length - _kReseedTurns)
          : realHistory;
      final geminiHistory = seedMessages
          .map((m) => Content(m.isUser ? 'user' : 'model',
              [TextPart(m.content)]))
          .toList();
      _chat = _model!.startChat(history: geminiHistory);

      if (history.isNotEmpty) {
        _messages = [
          _welcomeMessage(user, offline: false, hasHistory: true),
          ...history,
        ];
        debugPrint('[AIProvider] ✅ Restored ${history.length} messages, '
            're-seeded ${geminiHistory.length} turns into Gemini session');
      } else {
        _messages = [_welcomeMessage(user, offline: false, hasHistory: false)];
        debugPrint('[AIProvider] Session initialized (no prior history)');
      }
    } catch (e) {
      _error = 'Failed to initialize AI: $e';
      _messages = [_welcomeMessage(user, offline: false, hasHistory: false)];
      debugPrint('[AIProvider] ❌ initializeSession error: $e');
    }

    _isLoadingHistory = false;
    notifyListeners();
  }

  void refreshContext({
    required UserModel user,
    required List<SessionModel> recentSessions,
  }) {
    if (!_keyOk) return;

    try {
      _model = GenerativeModel(
        model: _kChatModel,
        apiKey: activeKey,
        systemInstruction:
            Content.system(_buildSystemPrompt(user, recentSessions)),
        generationConfig: GenerationConfig(
          temperature: 0.8,
          maxOutputTokens: 2048,
        ),
      );

      final realMessages = _messages.where((m) => !m.isLoading).toList();
      final seedMessages = realMessages.length > _kReseedTurns
          ? realMessages.sublist(realMessages.length - _kReseedTurns)
          : realMessages;
      final geminiHistory = seedMessages
          .map((m) => Content(m.isUser ? 'user' : 'model',
              [TextPart(m.content)]))
          .toList();

      _chat = _model!.startChat(history: geminiHistory);
      debugPrint('[AIProvider] Context refreshed — '
          '${recentSessions.length} sessions, '
          '${geminiHistory.length} turns re-seeded');
    } catch (e) {
      debugPrint('[AIProvider] ⚠️ refreshContext error: $e');
    }
  }

  // ── Welcome message ────────────────────────────────────────────────────────

  ChatMessage _welcomeMessage(
    UserModel user, {
    required bool offline,
    required bool hasHistory,
  }) {
    final firstName = user.name.split(' ').first;
    final String body;
    if (offline) {
      body = 'Hey $firstName! I\'m your FitVerse AI Coach.\n\n'
          'The AI key isn\'t configured — running in offline mode. '
          'Go to Settings → AI Configuration to add your Gemini API key '
          'and unlock real AI coaching.';
    } else if (hasHistory) {
      body = 'Welcome back, $firstName! Your conversation history has been '
          'restored. I still remember what we discussed — just keep going!';
    } else {
      body = 'Hey $firstName! I\'m your FitVerse AI Coach, powered by Gemini.\n\n'
          'I know your profile and workout history, so ask me anything — '
          'nutrition advice, recovery tips, exercise technique, or workout '
          'planning. How can I help you today?';
    }

    return ChatMessage(
      id: const Uuid().v4(),
      content: body,
      isUser: false,
      timestamp: DateTime.now(),
    );
  }

  // ── System prompt ─────────────────────────────────────────────────────────

  String _buildSystemPrompt(UserModel user, List<SessionModel> sessions) {
    final conditionStr = user.healthConditions.isEmpty
        ? 'None reported'
        : user.healthConditions.join(', ');

    final sessionSummary = sessions.isEmpty
        ? 'No workout sessions recorded yet.'
        : sessions.take(5).map((s) {
            return '- ${s.workoutName} on ${_fmt(s.date)}: '
                '${s.durationMinutes} min, ${s.caloriesBurned.round()} kcal, '
                'accuracy ${s.accuracyScore.round()}%, intensity: ${s.intensity}';
          }).join('\n');

    return '''
You are the FitVerse AI Coach — an expert personal trainer and sports nutritionist.

USER PROFILE:
• Name: ${user.name}
• Age: ${user.age} years
• Weight: ${user.weightKg} kg
• Height: ${user.heightCm} cm
• BMI: ${user.bmi.toStringAsFixed(1)} (${user.bmiCategory})
• Gender: ${user.gender}
• Fitness Goal: ${user.fitnessGoal}
• Health Conditions: $conditionStr
• Total Workouts: ${user.totalWorkouts}

RECENT WORKOUT HISTORY:
$sessionSummary

RULES:
1. Be warm, motivating, and concise. Use emojis sparingly.
2. Always consider the user's health conditions.
3. Give specific, actionable recommendations — not generic advice.
4. For nutrition: calculate based on actual weight and intensity.
5. Keep responses focused and clear. Use more detail only when a detailed plan is explicitly requested.
6. NEVER discuss authentication credentials — only use profile data above.
''';
  }

  // ── Send message ──────────────────────────────────────────────────────────

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _isThinking) return;

    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      content: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );
    _messages.add(userMsg);

    final thinking = ChatMessage(
      id: 'thinking',
      content: '...',
      isUser: false,
      timestamp: DateTime.now(),
      isLoading: true,
    );
    _messages.add(thinking);
    _isThinking = true;
    notifyListeners();

    await _persistMessage(userMsg);

    try {
      if (_chat == null) throw Exception('Chat not initialized');
      final response = await _chat!.sendMessage(Content.text(text));
      final reply    = response.text ??
          'I couldn\'t generate a response — please try again.';

      _messages.removeWhere((m) => m.id == 'thinking');
      final aiMsg = ChatMessage(
        id: const Uuid().v4(),
        content: reply,
        isUser: false,
        timestamp: DateTime.now(),
      );
      _messages.add(aiMsg);
      _error = null;

      await _persistMessage(aiMsg);
    } catch (e) {
      _messages.removeWhere((m) => m.id == 'thinking');
      final errText = !_keyOk
          ? 'Please add your Gemini API key in Settings → AI Configuration '
              'to enable the AI Coach. Get your key at ai.google.dev.'
          : 'Connection error: ${e.toString()}. Check your internet connection.';
      final errMsg = ChatMessage(
        id: const Uuid().v4(),
        content: errText,
        isUser: false,
        timestamp: DateTime.now(),
      );
      _messages.add(errMsg);
      _error = errText;
      debugPrint('[AIProvider] ❌ sendMessage error: $e');

      await _persistMessage(errMsg);
    }

    _isThinking = false;
    notifyListeners();
  }

  // ── Clear history ─────────────────────────────────────────────────────────

  void resetSession() {
    _messages      = [];
    _isThinking    = false;
    _isLoadingHistory = false;
    _error         = null;
    _model         = null;
    _chat          = null;
    _uid           = null;
    // NOTE: _runtimeKey is intentionally kept — the user's API key
    // setting should survive sign-out/sign-in cycles.
    notifyListeners();
  }

  Future<void> clearHistory(UserModel user, List<SessionModel> recentSessions) async {
    final uid = _uid;

    _messages = [];
    notifyListeners();

    if (uid != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey(uid));

      try {
        bool moreToDelete = true;
        while (moreToDelete) {
          final snap = await _chatCol(uid).limit(500).get();
          if (snap.docs.isEmpty) {
            moreToDelete = false;
          } else {
            final batch = FirebaseFirestore.instance.batch();
            for (final d in snap.docs) {
              batch.delete(d.reference);
            }
            await batch.commit();
          }
        }
        debugPrint('[AIProvider] ✅ Chat history cleared from Firestore');
      } catch (e) {
        debugPrint('[AIProvider] ⚠️ Firestore chat clear failed: $e');
      }
    }

    if (_keyOk) {
      _model = GenerativeModel(
        model: _kChatModel,
        apiKey: activeKey,
        systemInstruction:
            Content.system(_buildSystemPrompt(user, recentSessions)),
        generationConfig: GenerationConfig(
          temperature: 0.8,
          maxOutputTokens: 2048,
        ),
      );
      _chat = _model!.startChat();
    }

    _messages = [_welcomeMessage(user, offline: !_keyOk, hasHistory: false)];
    notifyListeners();
  }

  // ── Post-workout report ───────────────────────────────────────────────────

  Future<String> generatePostWorkoutReport({
    required UserModel user,
    required SessionModel session,
    List<String>? exerciseNames,
  }) async {
    _lastReportWasAI = false;

    if (!_keyOk) {
      notifyListeners();
      return _templateReport(user, session, exerciseNames);
    }

    try {
      final model = GenerativeModel(
        model: _kReportModel,
        apiKey: activeKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          maxOutputTokens: 1024,
        ),
      );

      final conditions = user.healthConditions.isEmpty
          ? 'none'
          : user.healthConditions.join(', ');

      final exerciseBlock =
          (exerciseNames != null && exerciseNames.isNotEmpty)
              ? 'Specific Exercises: ${exerciseNames.join(', ')}'
              : 'Specific Exercises: not listed';

      final prompt = '''
Generate a personalised post-workout report.

User: ${user.name}, ${user.age} yo, ${user.weightKg}kg, ${user.heightCm}cm
Health Conditions: $conditions
Workout: ${session.workoutName}
$exerciseBlock
Duration: ${session.durationMinutes} min
Intensity: ${session.intensity}
Calories: ${session.caloriesBurned.round()} kcal
Muscles: ${session.musclesWorked.join(', ')}
Form Accuracy: ${session.accuracyScore.round()}%

Write exactly 4 short paragraphs:
1. 🔥 Health note — mention the specific exercises and any condition considerations.
2. 🥗 Nutrition — exact protein grams (weight × 0.35 = ${(user.weightKg * 0.35).round()}g) and carbs (weight × 0.6 = ${(user.weightKg * 0.6).round()}g), plus 2 specific meal suggestions matching the muscles trained.
3. 💪 Recovery — one specific stretch or cool-down move by name for the muscles trained.
4. ⚡ Pro tip — one actionable cue for improving one of the listed exercises next session (name it).

Use emojis. Be specific — no generic advice. Complete all 4 paragraphs fully.
''';

      final response = await model
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 20));

      final text = response.text;
      if (text != null && text.trim().isNotEmpty) {
        _lastReportWasAI = true;
        notifyListeners();
        debugPrint('[AIProvider] ✅ Post-workout report generated by Gemini AI');
        return text.trim();
      }

      debugPrint('[AIProvider] ⚠️ Gemini returned empty response — using template');
    } catch (e) {
      debugPrint('[AIProvider] ⚠️ generatePostWorkoutReport error: $e');
    }

    notifyListeners();
    return _templateReport(user, session, exerciseNames);
  }

  // ── Rich template report (personalised fallback) ──────────────────────────

  String _templateReport(
    UserModel user,
    SessionModel session,
    List<String>? exerciseNames,
  ) {
    final name      = user.name.split(' ').first;
    final hasAsthma = user.healthConditions
        .any((c) => c.toLowerCase().contains('asthma'));
    final hasDiab   = user.healthConditions
        .any((c) => c.toLowerCase().contains('diabet'));
    final proteinG  = (user.weightKg * 0.35).round();
    final carbG     = (user.weightKg * 0.60).round();

    final exList = (exerciseNames != null && exerciseNames.isNotEmpty)
        ? exerciseNames.join(', ')
        : session.musclesWorked.join(' & ');

    final String p1;
    if (hasAsthma) {
      p1 = '💨 Solid work, $name! After completing $exList at '
          '${session.intensity.toLowerCase()} intensity, take 5 minutes of '
          'diaphragmatic breathing to normalise lung function and reduce the '
          'risk of exercise-induced bronchoconstriction.';
    } else {
      p1 = '🔥 Excellent effort, $name! You powered through $exList in a '
          '${session.durationMinutes}-minute ${session.intensity.toLowerCase()}-'
          'intensity session — your muscles are primed for adaptation.';
    }

    final meal = _mealForMuscles(session.musclesWorked);
    String p2 = '🥗 Within 30 minutes aim for ${proteinG}g of protein and '
        '${carbG}g of carbohydrates to replenish glycogen and start '
        'repairing your ${session.musclesWorked.join(', ').toLowerCase()} '
        'fibres. $meal';
    if (hasDiab) {
      p2 += ' Monitor blood glucose before eating — post-workout insulin '
          'sensitivity means carbs absorb faster; prefer complex sources.';
    }

    final stretch = _stretchForMuscles(session.musclesWorked);
    final p3 = '😴 $stretch Allow these muscles 48 hours before training '
        'them again, and target 7–9 hours of sleep tonight — that\'s when '
        'muscle protein synthesis peaks.';

    final p4 = _proTip(exerciseNames);
    return '$p1\n\n$p2\n\n$p3\n\n$p4';
  }

  String _mealForMuscles(List<String> muscles) {
    final m = muscles.map((e) => e.toLowerCase()).toSet();
    if (m.any((e) => e.contains('chest') || e.contains('tricep'))) {
      return 'Great options: grilled chicken breast with sweet potato, or '
          'cottage cheese on whole-grain toast.';
    }
    if (m.any((e) => e.contains('back') || e.contains('bicep'))) {
      return 'Great options: tuna wrap with brown rice, or Greek yoghurt '
          'with mixed berries and oats.';
    }
    if (m.any((e) => e.contains('leg') || e.contains('quad') || e.contains('glute'))) {
      return 'Great options: salmon with quinoa and roasted vegetables, or '
          'a banana–peanut-butter protein shake.';
    }
    if (m.any((e) => e.contains('shoulder'))) {
      return 'Great options: egg-white omelette with whole-grain toast, or '
          'a turkey and avocado sandwich.';
    }
    if (m.any((e) => e.contains('core'))) {
      return 'Great options: lentil soup with wholegrain bread, or a '
          'mixed-bean salad with grilled fish.';
    }
    return 'Great options: whey protein with a banana, or a tuna sandwich '
        'on whole wheat.';
  }

  String _stretchForMuscles(List<String> muscles) {
    final m = muscles.map((e) => e.toLowerCase()).toSet();
    if (m.any((e) => e.contains('chest'))) {
      return '💪 Do a doorway chest stretch (30 s each side) to release '
          'your pectorals and anterior deltoids.';
    }
    if (m.any((e) => e.contains('back'))) {
      return '💪 Try a child\'s pose (30–60 s) to gently decompress your '
          'spine and stretch the lats.';
    }
    if (m.any((e) => e.contains('leg') || e.contains('quad') || e.contains('glute'))) {
      return '💪 Perform a standing quad stretch and a lying piriformis '
          'stretch (30 s each side) to release your lower body.';
    }
    if (m.any((e) => e.contains('shoulder'))) {
      return '💪 Use a cross-body shoulder stretch and a doorway rear-delt '
          'stretch, 30 s each side, to cool down your deltoids.';
    }
    if (m.any((e) => e.contains('core'))) {
      return '💪 Hold a cobra pose for 30 s to gently stretch the abs and '
          'decompress your lumbar spine.';
    }
    return '💪 Spend 5 minutes on full-body foam rolling and light '
        'dynamic stretching.';
  }

  String _proTip(List<String>? names) {
    if (names == null || names.isEmpty) {
      return '⚡ Next session focus on the eccentric (lowering) phase — '
          'slow it to 3 seconds. Eccentric overload is the fastest driver '
          'of strength and hypertrophy gains.';
    }
    final ex = names.first;
    const tips = <String, String>{
      'Bench Press':
          '⚡ Next Bench Press: pause the bar 2 cm off your chest for 1 s '
          'before pressing — eliminates momentum and builds raw strength.',
      'Push-Up':
          '⚡ Next Push-Up session: slow the descent to 3 seconds and pause '
          'at the bottom for 1 s — this kills momentum and doubles the stimulus.',
      'Barbell Squat':
          '⚡ Next Squat session: widen your stance 2–3 cm and "spread the '
          'floor" with your feet to activate more glute and reduce knee stress.',
      'Pull-Up':
          '⚡ Next Pull-Up session: add a 2-second dead-hang at the bottom '
          'of each rep to build shoulder stability and lat stretch.',
      'Deadlift':
          '⚡ Before your next Deadlift set, practise the "lat spread" cue — '
          'imagine bending the bar around your legs. This locks your back.',
      'Overhead Press':
          '⚡ On your next Overhead Press: try a slight forward lean as the '
          'bar passes your face, then finish vertical — safer and stronger.',
      'Barbell Hip Thrust':
          '⚡ Next Hip Thrust: add a 2-second squeeze at the top of each rep '
          'to maximise glute activation and improve mind-muscle connection.',
      'Romanian Deadlift':
          '⚡ On your next RDL: push your hips *back* as far as possible '
          '(not down) keeping the bar dragging your shins — isolates hamstrings.',
      'Lateral Raise':
          '⚡ Next Lateral Raise: lead with pinkies slightly higher than '
          'thumbs ("pour a jug") to shift load from traps onto medial delts.',
      'Incline Dumbbell Press':
          '⚡ Keep elbows at 60° on the next Incline DB Press — reduces '
          'shoulder impingement and targets the upper pec more effectively.',
      'Burpees':
          '⚡ Next Burpees: land softly in a squat before jumping — protects '
          'knees and improves power transfer.',
      'Walking Lunges':
          '⚡ Next Lunges: take a longer stride so your front shin stays '
          'vertical — shifts load from the knee to the glute.',
      'Plank':
          '⚡ Next Plank: squeeze your glutes and push your elbows into the '
          'floor — activates serratus anterior and doubles core tension.',
    };
    return tips[ex] ??
        '⚡ Next $ex session: slow the eccentric phase to 3 seconds — '
            'increased time under tension accelerates strength gains.';
  }

  String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
