import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/workout_model.dart';
import '../core/constants/workout_data.dart';

enum FormStatus { good, warning, error }

// ─────────────────────────────────────────────────────────────────────────────
// WorkoutProvider
//
// Rep-counting pipeline (four-stage adaptive, mirrors HealthProvider step algo)
// ─────────────────────────────────────────────────────────────────────────────
//
// Raw accelerometer (20 Hz)
//   │
//   ▼ Stage 1 — Gravity removal
//   LP IIR on each axis:  lp = α·lp + (1−α)·raw   (α = 0.85)
//   HP = raw − lp         isolates body dynamics, rejects DC gravity vector
//   │
//   ▼ Stage 2 — Dynamic magnitude
//   mag = √(hpX² + hpY² + hpZ²)
//   │
//   ▼ Stage 3 — Magnitude smoothing
//   smooth = βmag·mag + (1−βmag)·smooth_prev        (βmag = 0.30)
//   Kills single-sample noise spikes without introducing too much lag.
//   │
//   ▼ Stage 4 — Adaptive peak detection
//   runningMax = max(smooth, runningMax · _maxDecay)  decay when idle
//   threshold  = clamp(_threshFactor · runningMax, _minThresh, _maxThresh)
//   valley     = _valleyFactor · threshold
//
//   State machine:
//     smooth ≥ threshold AND NOT inPeak AND elapsed ≥ _minRepMs  → COUNT REP
//     smooth <  valley                                            → inPeak=false
//     gap   >  _maxRepGapMs since last rep                       → force reset
//
// Constants are tuned for resistance-exercise rep motions
// (larger amplitude, slower cadence than walking steps).
// ─────────────────────────────────────────────────────────────────────────────

class WorkoutProvider extends ChangeNotifier {
  // ── Active workout state ────────────────────────────────────────────────────
  Exercise?     _activeExercise;
  WorkoutPreset? _activePreset;
  bool          _isTracking    = false;
  int           _currentReps   = 0;   // reps in current set
  int           _currentSet    = 1;
  int           _totalReps     = 0;   // cumulative reps across all sets
  double        _accuracyScore = 100.0;
  FormStatus    _formStatus    = FormStatus.good;
  String        _formMessage   = 'Form looks great! Keep it up.';
  int           _elapsedSeconds = 0;

  // ── Sensor streams ──────────────────────────────────────────────────────────
  StreamSubscription<AccelerometerEvent>? _accelSub;
  Timer?   _sessionTimer;
  final FlutterTts _tts = FlutterTts();
  final Random     _rng = Random();

  // ── Rep-detection pipeline state ─────────────────────────────────────────────
  // Stage 1 — gravity LP filter state
  static const double _gravAlpha  = 0.85;
  double _lpX = 0, _lpY = 9.8, _lpZ = 0;  // initialised to phone-at-rest gravity

  // Stage 3 — smoothing LP filter state
  static const double _magAlpha   = 0.30;
  double _smoothMag = 0.0;

  // Stage 4 — adaptive peak detector state
  static const double _maxDecay        = 0.990;   // per-sample decay
  static const double _threshFactor    = 0.55;    // threshold = 55% of runningMax
  static const double _valleyFactor    = 0.30;    // valley = 30% of threshold
  static const double _minThresh       = 1.5;     // m/s²  — floor to avoid false reps at rest
  static const double _maxThresh       = 8.0;     // m/s²  — ceiling to prevent threshold runaway
  static const int    _minRepMs        = 450;     // minimum ms between reps (~130 rpm max cadence)
  static const int    _maxRepGapMs     = 5000;    // auto-release peak-lock after 5 s idle

  double _runningMax    = 0.0;
  bool   _inPeak        = false;
  int    _lastRepTime   = 0;            // millisecondsSinceEpoch of the last counted rep

  // ── Form-alert state ────────────────────────────────────────────────────────
  int _formAlertCooldown = 0;           // samples remaining before next alert is eligible

  // ── Calibration / warm-up ───────────────────────────────────────────────────
  static const int _warmupSamples = 40; // ignore first 40 samples (~2 s at 20 Hz)
  int _sampleCount = 0;

  // ── Getters ─────────────────────────────────────────────────────────────────
  Exercise?     get activeExercise => _activeExercise;
  WorkoutPreset? get activePreset  => _activePreset;
  bool          get isTracking     => _isTracking;
  int           get currentReps    => _currentReps;
  int           get currentSet     => _currentSet;
  int           get totalReps      => _totalReps;
  double        get accuracyScore  => _accuracyScore;
  FormStatus    get formStatus     => _formStatus;
  String        get formMessage    => _formMessage;
  int           get elapsedSeconds => _elapsedSeconds;

  WorkoutProvider() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  void setActiveExercise(Exercise exercise) {
    _activeExercise = exercise;
    _activePreset   = null;
    _resetSession();
    notifyListeners();
  }

  void setActivePreset(WorkoutPreset preset) {
    _activePreset = preset;
    final exercises = WorkoutData.exercisesForPreset(preset);
    if (exercises.isNotEmpty) {
      _activeExercise = exercises.first;
    }
    _resetSession();
    notifyListeners();
  }

  void _resetSession() {
    _currentReps   = 0;
    _currentSet    = 1;
    _totalReps     = 0;
    _accuracyScore = 100.0;
    _formStatus    = FormStatus.good;
    _formMessage   = 'Start your workout when ready.';
    _elapsedSeconds = 0;
    _resetPipelineState();
  }

  /// Resets the accelerometer pipeline so a fresh start / exercise change
  /// doesn't carry over stale filter state.
  void _resetPipelineState() {
    _lpX         = 0;
    _lpY         = 9.8;
    _lpZ         = 0;
    _smoothMag   = 0.0;
    _runningMax  = 0.0;
    _inPeak      = false;
    _lastRepTime = 0;
    _sampleCount = 0;
    _formAlertCooldown = 0;
  }

  // ── Tracking lifecycle ──────────────────────────────────────────────────────

  Future<void> startTracking() async {
    _isTracking = true;
    _resetPipelineState();
    notifyListeners();

    // 1-second session timer
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      notifyListeners();
    });

    // 20 Hz accelerometer — matches the HealthProvider step-counter cadence
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen(_processAccelerometer);
  }

  // ── Four-stage rep-detection pipeline ────────────────────────────────────────

  void _processAccelerometer(AccelerometerEvent event) {
    _sampleCount++;

    // ── Stage 1: Gravity removal (LP IIR + high-pass) ──────────────────────
    _lpX = _gravAlpha * _lpX + (1 - _gravAlpha) * event.x;
    _lpY = _gravAlpha * _lpY + (1 - _gravAlpha) * event.y;
    _lpZ = _gravAlpha * _lpZ + (1 - _gravAlpha) * event.z;

    final hpX = event.x - _lpX;
    final hpY = event.y - _lpY;
    final hpZ = event.z - _lpZ;

    // ── Stage 2: Dynamic magnitude ─────────────────────────────────────────
    final mag = sqrt(hpX * hpX + hpY * hpY + hpZ * hpZ);

    // ── Stage 3: Magnitude smoothing ───────────────────────────────────────
    _smoothMag = _magAlpha * mag + (1 - _magAlpha) * _smoothMag;

    // Discard warm-up samples so the filter can settle before counting
    if (_sampleCount < _warmupSamples) return;

    // ── Stage 4: Adaptive peak detection ───────────────────────────────────
    _runningMax = max(_smoothMag, _runningMax * _maxDecay);

    final threshold = (_threshFactor * _runningMax).clamp(_minThresh, _maxThresh);
    final valley    = _valleyFactor  * threshold;

    final now         = DateTime.now().millisecondsSinceEpoch;
    final msSinceLast = now - _lastRepTime;

    // Auto-release peak-lock after a long idle gap
    if (_inPeak && msSinceLast > _maxRepGapMs) {
      _inPeak = false;
    }

    if (!_inPeak && _smoothMag >= threshold && msSinceLast >= _minRepMs) {
      // ── Rep detected ─────────────────────────────────────────────────────
      _inPeak      = true;
      _lastRepTime = now;
      _onRepDetected();
    } else if (_inPeak && _smoothMag < valley) {
      // Signal fell to valley — ready for next peak
      _inPeak = false;
    }

    // ── Form quality heuristic ────────────────────────────────────────────
    // Penalise excessive jerk (mag spike well above the adaptive threshold),
    // which usually indicates an uncontrolled / momentum-driven rep.
    if (_smoothMag > threshold * 2.5 && _formAlertCooldown <= 0) {
      _triggerFormAlert();
    } else if (_formAlertCooldown > 0) {
      _formAlertCooldown--;
    }
  }

  void _onRepDetected() {
    _currentReps++;
    _totalReps++;

    final targetReps = _repTarget();

    if (targetReps > 0 && _currentReps >= targetReps) {
      // Set complete — advance set counter and reset rep count
      _currentReps = 0;
      _currentSet++;
      _tts.speak('Set complete. Rest and go again.');
    } else {
      // Optionally announce every 5th rep so the user gets audio feedback
      if (_currentReps % 5 == 0 && _currentReps > 0) {
        _tts.speak('$_currentReps reps');
      }
    }

    // Maintain form status as "good" while counting properly
    if (_formStatus != FormStatus.good && _formAlertCooldown <= 0) {
      _formStatus  = FormStatus.good;
      _formMessage = 'Form looks great! Keep it up.';
    }

    notifyListeners();
  }

  /// Parses the first number out of the exercise reps field (e.g. "8-12" → 8).
  /// Returns 0 if the value cannot be determined (no auto-advance on unknown target).
  int _repTarget() {
    final repsStr = _activeExercise?.reps ?? '';
    if (repsStr.isEmpty) return 0;
    final part = repsStr.split(RegExp(r'[-–—]')).first.trim();
    return int.tryParse(part) ?? 0;
  }

  // ── Form alert ────────────────────────────────────────────────────────────

  void _triggerFormAlert() {
    // 60-sample cooldown (3 s at 20 Hz) before the next alert
    _formAlertCooldown = 60;

    final exercise = _activeExercise;
    if (exercise == null) return;

    final alertMessages = _getAlertMessages(exercise.id);
    final msg = alertMessages[_rng.nextInt(alertMessages.length)];

    _formStatus   = FormStatus.warning;
    _formMessage  = msg;
    _accuracyScore = (_accuracyScore - _rng.nextDouble() * 5).clamp(60.0, 100.0);
    notifyListeners();

    _tts.speak(msg);

    Future.delayed(const Duration(seconds: 4), () {
      if (_formStatus == FormStatus.warning) {
        _formStatus  = FormStatus.good;
        _formMessage = 'Form looks great! Keep it up.';
        notifyListeners();
      }
    });
  }

  List<String> _getAlertMessages(String exerciseId) {
    const Map<String, List<String>> cues = {
      'bench_press': [
        'Tuck your elbows in to protect your shoulders.',
        'Keep the bar controlled — slow and steady.',
        'Maintain your arch and drive through your feet.',
      ],
      'squat': [
        'Keep your chest up and your spine neutral.',
        'Drive your knees out — don\'t let them cave in.',
        'Breathe and brace your core before descending.',
      ],
      'pull_up': [
        'Avoid swinging. Control the movement.',
        'Lead with your chest, not your chin.',
        'Full range of motion — hang completely at the bottom.',
      ],
      'deadlift': [
        'Keep your back flat — no rounding.',
        'Engage your lats before you pull.',
        'Push the floor away, don\'t just yank the bar.',
      ],
      'overhead_press': [
        'Brace your core — avoid back arching.',
        'Bar should move in a straight vertical line.',
        'Keep your wrists stacked over your elbows.',
      ],
      // ── Chest ──────────────────────────────────────────────────────────
      'incline_db_press': [
        'Keep elbows at 60 degrees, not flared out.',
        'Touch the dumbbells at the top — full contraction.',
        'Control the descent. Do not let gravity do the work.',
      ],
      'cable_crossover': [
        'Keep a slight bend in your elbows throughout.',
        'Lead with your pinkies and squeeze at the centre.',
        'Do not lean too far forward — maintain posture.',
      ],
      'chest_dip': [
        'Lean forward to shift load to the chest.',
        'Lower until shoulders are below elbows.',
        'Full lockout at the top to engage the lower chest.',
      ],
      'push_up': [
        'Keep your body in a straight line from head to heel.',
        'Elbows at 45 degrees — not fully flared.',
        'Lower your chest to the floor for full range.',
      ],
      'pec_deck': [
        'Keep a slight bend in your elbows throughout.',
        'Squeeze at the centre — pause for 1 second.',
        'Control the eccentric — 3 seconds back.',
      ],
      // ── Back ───────────────────────────────────────────────────────────
      'barbell_row': [
        'Hinge at the hips — back parallel to the floor.',
        'Lead with your elbows, not your hands.',
        'Squeeze your shoulder blades at the top.',
      ],
      'lat_pulldown': [
        'Lean back slightly — chest to the bar.',
        'Depress your shoulders before you pull.',
        'Control the bar on the way up — don\'t let it fly.',
      ],
      'seated_cable_row': [
        'Keep your torso upright — don\'t lean back excessively.',
        'Full stretch at the front — let your shoulder blades spread.',
        'Squeeze your back, not just your arms.',
      ],
      'dumbbell_row': [
        'Keep your elbow tracking close to your body.',
        'Rotate your wrist at the top for full lat engagement.',
        'Don\'t round your lower back.',
      ],
      // ── Shoulders ──────────────────────────────────────────────────────
      'lateral_raise': [
        'Lead with your elbows, not your wrists.',
        'Slight forward tilt at the top — better delt angle.',
        'Control the descent — no dropping.',
      ],
      'front_raise': [
        'Keep a slight bend in your elbows.',
        'Don\'t swing — isolate the shoulder.',
        'Stop at shoulder height for peak tension.',
      ],
      'face_pull': [
        'Pull to your face — elbows high.',
        'External rotate at the end — hands behind your head.',
        'Slow tempo — this is for shoulder health.',
      ],
      // ── Arms ───────────────────────────────────────────────────────────
      'bicep_curl': [
        'Keep your elbows pinned at your sides.',
        'Supinate at the top — turn your palms toward the ceiling.',
        'Full extension at the bottom — don\'t cut the range.',
      ],
      'hammer_curl': [
        'Keep your upper arm vertical throughout.',
        'Neutral grip throughout — thumbs up.',
        'Control the negative — 2 seconds down.',
      ],
      'tricep_pushdown': [
        'Keep your elbows tucked at your sides — don\'t let them flare.',
        'Full lockout at the bottom.',
        'Slow eccentric — 3 seconds on the way up.',
      ],
      'skull_crusher': [
        'Keep your upper arms perpendicular to the floor.',
        'Lower to your forehead — not your neck.',
        'Slow and controlled — do not let gravity win.',
      ],
      // ── Core ───────────────────────────────────────────────────────────
      'crunch': [
        'Curl your ribs to your pelvis — not your head to your knees.',
        'Keep your lower back on the floor.',
        'Exhale fully at the top — maximum contraction.',
      ],
      'plank': [
        'Neutral spine — no sagging hips or raised butt.',
        'Squeeze your glutes and brace your core.',
        'Breathe steadily — do not hold your breath.',
      ],
      'leg_raise': [
        'Lower back stays pressed to the floor.',
        'Control the descent — don\'t drop your legs.',
        'At the top, tilt your pelvis to fully engage the lower abs.',
      ],
      'russian_twist': [
        'Lean back slightly — this increases the range of motion.',
        'Rotate from the obliques — not the shoulders.',
        'Keep your feet off the floor for greater difficulty.',
      ],
      // ── Legs ───────────────────────────────────────────────────────────
      'lunge': [
        'Keep your front knee above your ankle — not past your toes.',
        'Torso stays upright — don\'t lean forward.',
        'Drive through your front heel to stand.',
      ],
      'leg_press': [
        'Feet shoulder-width apart — don\'t let your knees cave.',
        'Full range — lower until knees hit 90 degrees.',
        'Do not lock your knees at the top.',
      ],
      'leg_curl': [
        'Keep your hips flat on the pad.',
        'Full range — curl all the way up.',
        'Slow eccentric — 3 seconds on the descent.',
      ],
      'calf_raise': [
        'Full plantar flexion at the top — stand on your toes.',
        'Full stretch at the bottom.',
        'Slow and controlled — no bouncing.',
      ],
      'romanian_deadlift': [
        'Push your hips back — this is a hip hinge, not a squat.',
        'Keep the bar close to your legs throughout.',
        'Feel the stretch in your hamstrings at the bottom.',
      ],
      'bulgarian_split_squat': [
        'Torso stays upright — this keeps load on the quad not the hip flexor.',
        'Drive your front heel into the floor on the ascent.',
        'Front foot far enough forward that your knee tracks safely.',
      ],
      'hack_squat': [
        'Keep your lower back pressed against the pad throughout.',
        'Full depth — parallel or below for maximum quad stimulus.',
        'Do not lock your knees at the top under heavy load.',
      ],
      'front_squat': [
        'Elbows UP — if they drop, the bar rolls forward.',
        'Upright torso is non-negotiable — this is a quad exercise.',
        'Brace hard — the front rack demands significant core strength.',
      ],
      'wall_sit': [
        '90-degree angle at the knees — this maximizes quad tension.',
        'Do not let your knees cave inward — push them outward.',
        'Breathe steadily. Do not hold your breath during the isometric.',
      ],
      // ── Hip Flexors ────────────────────────────────────────────────────
      'hanging_knee_raise': [
        'Control the swing — no kipping or momentum.',
        'At the top, slightly tilt your pelvis for deeper engagement.',
        'Pause for 1 second at peak contraction.',
      ],
      'standing_hip_flexion': [
        'Keep your torso upright — if you lean back, the psoas is too weak.',
        'Drive the knee UP — do not swing from the ankle.',
        'Slow controlled lowering builds eccentric hip flexor strength.',
      ],
      'cable_hip_flexion': [
        'The cable maintains tension at the top — do not rush through it.',
        'Keep your core braced — do not arch your lower back as compensation.',
        'Complete all reps on one side before switching.',
      ],
      'psoas_march': [
        'Lower back stays flat — if it arches, your core gave out.',
        'Breathe out as you lower the leg.',
        'Slow and deliberate — this is activation training, not conditioning.',
      ],
      'dragon_flag': [
        'Your body must remain straight as a board — no piking at the hips.',
        'The lowering phase IS the exercise. Never rush it.',
        'Grip the bench firmly — it is your only anchor.',
      ],
      // ── Adductors ──────────────────────────────────────────────────────
      'cable_hip_adduction': [
        'Keep your torso upright — do not lean away from the cable.',
        'Full range — cross your leg well past your midline.',
        'Control the return — eccentrics build the most adductor strength.',
      ],
      'lateral_lunge': [
        'Keep the straight leg truly straight — the stretched adductor is the goal.',
        'Chest up — do not round the spine.',
        'Foot of the bent leg stays flat. Do not let the heel rise.',
      ],
      'copenhagen_plank': [
        'The adductor of the top leg is doing the work — feel it squeeze.',
        'Keep your torso rigid — no rotation.',
        'Lift the bottom foot to meet the top for an advanced progression.',
      ],
      'inner_thigh_squeeze': [
        'Progressive squeeze — build to maximum force over 2 seconds.',
        'Breathe normally during the hold.',
        'Good for post-injury rehabilitation or daily activation work.',
      ],
      'curtsy_lunge': [
        'Keep your front knee tracking over your toes.',
        'Torso tall — do not lean to the side.',
        'Control the descent — do not just step and drop.',
      ],
      // ── Abductors ──────────────────────────────────────────────────────
      'clamshell': [
        'Hips must stay stacked vertically — rolling back cheats the movement.',
        'Feel the contraction in your outer glute, not your hip flexor.',
        'Slow tempo — this is activation work.',
      ],
      'side_lying_abduction': [
        'Do not let your pelvis rotate back — keep it neutral.',
        'Toe points slightly down for increased glute medius activation.',
        'Full range — do not stop at 45 degrees.',
      ],
      'cable_hip_abduction': [
        'Keep your pelvis level — do not hike the opposite hip up.',
        'Straight leg throughout — no bending at the knee.',
        'Slow eccentric return builds the most strength.',
      ],
      'lateral_band_walk': [
        'Stay in the athletic hinge position — do not stand upright.',
        'Maintain band tension at all times — feet never fully together.',
        'Short, deliberate steps — not wide hops.',
      ],
      'monster_walk': [
        'Stay low — hip hinge throughout.',
        'Keep your toes pointing forward or slightly out.',
        'Slow, controlled steps — this is not a sprint.',
      ],
      // ── Serratus Anterior ───────────────────────────────────────────────
      'serratus_punch': [
        'Keep your elbow locked — this is all scapular movement.',
        'Think "reach for the ceiling" — not "press the dumbbell up."',
        'Start with a very light weight — the movement is small.',
      ],
      'push_up_plus': [
        'The plus is a small extra push — about 3 cm further.',
        'Feel your shoulder blades separate on your back.',
        'Keep your core tight — maintain a rigid plank throughout.',
      ],
      'dumbbell_pullover': [
        'Hips remain low — this increases the lat and serratus stretch.',
        'Keep elbows slightly bent — never locked or too bent.',
        'Inhale on the way down to expand the rib cage.',
      ],
      'cable_serratus_crunch': [
        'This is a protraction exercise — shoulder blades move around the rib cage.',
        'Think "trying to touch your elbows together in front of you."',
        'Light weight — the serratus is a small but important muscle.',
      ],
      'landmine_press': [
        'Protract the scapula at the top — that is the serratus activation.',
        'Keep your core braced throughout.',
        'Single-arm version trains anti-rotation core simultaneously.',
      ],
      // ── Obliques ───────────────────────────────────────────────────────
      'side_plank': [
        'Keep your body in one plane — do not rotate forward or back.',
        'Squeeze your glutes — this prevents hip dropping.',
        'Raise the top leg for an advanced progression.',
      ],
      'woodchop': [
        'The rotation comes from your core — not your arms.',
        'Pivot your back foot to enable full rotation.',
        'Keep your arms straight — they are levers for the torso.',
      ],
      'pallof_press': [
        'The key is RESISTANCE — your body should not rotate at all.',
        'If you are rotating, the weight is too heavy.',
        'A narrower stance increases the anti-rotation challenge.',
      ],
      'oblique_crunch': [
        'Rotate from your obliques — do not pull with your neck.',
        'Full range — aim to bring elbow and knee to meet.',
        'Slow and controlled — 2 seconds up, 2 seconds down.',
      ],
      'hanging_oblique_raise': [
        'No swinging — use core control throughout.',
        'At the top, your hip should point toward the ceiling on the working side.',
        'The rotation is what makes this an oblique exercise — maximize it.',
      ],
    };

    return cues[exerciseId] ??
        [
          'Check your form and stay controlled.',
          'Slow down and focus on your technique.',
          'Remember to breathe throughout the movement.',
        ];
  }

  // ── Stop tracking ─────────────────────────────────────────────────────────

  SessionModel stopTracking() {
    _isTracking = false;
    _accelSub?.cancel();
    _sessionTimer?.cancel();
    _tts.stop();

    final exercise      = _activeExercise;
    final preset        = _activePreset;
    final name          = preset?.name ?? exercise?.name ?? 'Workout';
    final muscle        = exercise?.muscleGroup ?? 'Full Body';
    final muscles       = exercise?.muscles     ?? ['Full Body'];
    final elapsedMinutes = _elapsedSeconds / 60.0;

    final double calories;
    if (exercise != null && exercise.kalories > 0) {
      calories = (exercise.kalories * elapsedMinutes).clamp(1.0, double.infinity);
    } else {
      calories = (elapsedMinutes * 5).clamp(1.0, double.infinity);
    }

    final intensity =
        _elapsedSeconds > 2700 ? 'High' : _elapsedSeconds > 1200 ? 'Moderate' : 'Low';

    final session = SessionModel(
      id:              DateTime.now().millisecondsSinceEpoch.toString(),
      workoutName:     name,
      muscleGroup:     muscle,
      date:            DateTime.now(),
      durationMinutes: (_elapsedSeconds / 60).round(),
      caloriesBurned:  calories,
      accuracyScore:   _accuracyScore,
      musclesWorked:   muscles,
      intensity:       intensity,
    );

    _resetSession();
    notifyListeners();
    return session;
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _sessionTimer?.cancel();
    _tts.stop();
    super.dispose();
  }
}
