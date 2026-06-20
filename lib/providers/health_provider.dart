import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── HealthMetrics ─────────────────────────────────────────────────────────────

class HealthMetrics {
  final double heartRate;
  final double spo2;
  final int    steps;
  final double caloriesBurned;
  final bool   isLive;
  final bool   isAccelSteps;
  final bool   isHrCached;
  final bool   isSpO2Cached;

  const HealthMetrics({
    this.heartRate      = 0,
    this.spo2           = 0,
    this.steps          = 0,
    this.caloriesBurned = 0,
    this.isLive         = false,
    this.isAccelSteps   = false,
    this.isHrCached     = false,
    this.isSpO2Cached   = false,
  });
}

// ─── _DailySnapshot ───────────────────────────────────────────────────────────

class _DailySnapshot {
  final double    heartRate;
  final double    spo2;
  final int       steps;
  final double    caloriesBurned;
  final DateTime? updatedAt;
  final String    source;

  const _DailySnapshot({
    this.heartRate      = 0,
    this.spo2           = 0,
    this.steps          = 0,
    this.caloriesBurned = 0,
    this.updatedAt,
    this.source         = 'accelerometer',
  });

  factory _DailySnapshot.fromFirestore(Map<String, dynamic> data) =>
      _DailySnapshot(
        heartRate:      (data['heartRate']      as num?)?.toDouble() ?? 0,
        spo2:           (data['spo2']           as num?)?.toDouble() ?? 0,
        steps:          (data['steps']          as num?)?.toInt()    ?? 0,
        caloriesBurned: (data['caloriesBurned'] as num?)?.toDouble() ?? 0,
        updatedAt: data['updatedAt'] is Timestamp
            ? (data['updatedAt'] as Timestamp).toDate()
            : null,
        source: data['source'] as String? ?? 'accelerometer',
      );

  Map<String, dynamic> toMap(String date, String source) => {
    'date':           date,
    'heartRate':      heartRate,
    'spo2':           spo2,
    'steps':          steps,
    'caloriesBurned': caloriesBurned,
    'updatedAt':      FieldValue.serverTimestamp(),
    'source':         source,
  };
}

// ─── Pipeline mode ────────────────────────────────────────────────────────────

enum _Mode { idle, live, accel }

// ═══════════════════════════════════════════════════════════════════════════════
// HealthProvider
// ═══════════════════════════════════════════════════════════════════════════════

class HealthProvider extends ChangeNotifier {

  // ── Public state ─────────────────────────────────────────────────────────
  HealthMetrics _metrics      = const HealthMetrics();
  _Mode         _mode         = _Mode.idle;
  bool          _isConnected  = false;
  bool          _isRequesting = false;
  String?       _error;
  DateTime?     _lastSyncedAt;
  _DailySnapshot? _cachedSnapshot;

  static const Duration _accelSyncInterval = Duration(minutes: 5);
  int _lastSyncedAccelSteps = -1;

  HealthMetrics get metrics       => _metrics;
  bool          get isConnected   => _isConnected;
  bool          get isRequesting  => _isRequesting;
  String?       get error         => _error;
  bool          get isAccelMode   => _mode == _Mode.accel;
  DateTime?     get lastSyncedAt  => _lastSyncedAt;

  // ── Health Connect ────────────────────────────────────────────────────────
  Timer? _refreshTimer;
  Timer? _accelSyncTimer;
  final Health _health = Health();

  static const List<HealthDataType> _types = [
    HealthDataType.HEART_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];
  static final List<HealthDataAccess> _readOnly =
      List.filled(_types.length, HealthDataAccess.READ);

  // ══════════════════════════════════════════════════════════════════════════
  // ACCELEROMETER PEDOMETER — Improved Algorithm
  //
  // Pipeline:
  //   Raw accel → gravity removal (LP IIR) → dynamic magnitude →
  //   magnitude smoothing (LP IIR) → adaptive-threshold peak detector →
  //   cadence gate → step count
  //
  // Adaptive threshold:
  //   We maintain an exponentially-decaying running maximum of the smoothed
  //   magnitude.  The step threshold is set to _thresholdFactor × runningMax,
  //   clamped to [_minThreshold, _maxThreshold].  This means:
  //   • A gentle walker → lower threshold → steps not missed.
  //   • A vehicle vibration (low, sustained) → threshold rises to match → not
  //     misread as steps.
  //   • The user sits still → runningMax decays quickly → threshold drifts to
  //     _minThreshold so the first step after a pause is still detected.
  // ══════════════════════════════════════════════════════════════════════════

  StreamSubscription<AccelerometerEvent>? _accelSub;

  // Gravity estimate (LP-filtered raw axes, init to rest position)
  double _lpX = 0, _lpY = 9.8, _lpZ = 0;

  // Smoothed dynamic-acceleration magnitude
  double _smoothMag = 0;

  // Adaptive peak-detection state
  double    _runningMax = 0;
  bool      _inPeak     = false;
  DateTime? _lastStepTime;

  int    _accelSteps = 0;
  double _accelCals  = 0.0;

  // ── Tuning constants ──────────────────────────────────────────────────────
  //
  // Gravity LP:  alpha=0.85 → time constant ≈ 0.30 s at 20 Hz.
  //              Gravity is DC; this keeps it out of the HP signal.
  //
  // Magnitude LP: alpha=0.35 → time constant ≈ 0.035 s at 20 Hz.
  //               Light smoothing removes sensor noise spikes while keeping
  //               the walking envelope intact (~2 Hz).
  //
  // RunningMax decay: 0.994 per sample → halves in ~115 samples (~5.75 s at
  //               20 Hz).  Enough to adapt to gait changes without forgetting
  //               the last burst too fast.
  //
  // Threshold factor 0.52: step peak sits roughly at 80-90 % of runningMax;
  //               threshold at 52 % is safely below any real peak but well
  //               above noise.
  //
  // Valley factor 0.28: must drop to 28 % of the threshold before the next
  //               peak is eligible — ensures each stride cycle is complete.
  //
  // Min interval 250 ms (4 steps/s) → max realistic sprint cadence.
  // Max interval 2 500 ms → if the gap is longer, reset _inPeak so we don't
  //               accidentally require a valley after a very long pause.

  static const double   _gravAlpha        = 0.85;   // gravity LP filter
  static const double   _magAlpha         = 0.35;   // magnitude smoothing LP
  static const double   _maxDecay         = 0.994;  // running-max decay per sample
  static const double   _thresholdFactor  = 0.52;   // threshold = factor × runningMax
  static const double   _valleyFactor     = 0.28;   // valley = factor × threshold
  static const double   _minThreshold     = 0.9;    // absolute floor (m/s²)
  static const double   _maxThreshold     = 5.0;    // absolute ceiling
  static const Duration _minStepInterval  = Duration(milliseconds: 250);
  static const Duration _maxStepInterval  = Duration(milliseconds: 2500);

  // Calorie estimate: 0.045 kcal/step ≈ 450 kcal / 10 000 steps for a
  // ~70 kg adult walking at moderate pace — within 10 % of published tables.
  static const double _calsPerStep = 0.045;

  // ── Firestore helpers ─────────────────────────────────────────────────────

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  DocumentReference<Map<String, dynamic>>? _healthDailyDoc(String date) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('health_daily')
        .doc(date);
  }

  Future<void> _loadTodaySnapshot() async {
    final ref = _healthDailyDoc(_todayKey());
    if (ref == null) return;
    try {
      final snap = await ref.get();
      if (!snap.exists || snap.data() == null) return;
      _cachedSnapshot = _DailySnapshot.fromFirestore(snap.data()!);
      debugPrint('[Health] ✅ Snapshot loaded — '
          'HR=${_cachedSnapshot!.heartRate} '
          'SpO2=${_cachedSnapshot!.spo2} '
          'Steps=${_cachedSnapshot!.steps}');
    } catch (e) {
      debugPrint('[Health] ⚠️  Snapshot load failed: $e');
    }
  }

  Future<void> _syncToFirestore() async {
    final today = _todayKey();
    final ref   = _healthDailyDoc(today);
    if (ref == null) return;
    try {
      final m      = _metrics;
      final source = _mode == _Mode.live ? 'health_connect' : 'accelerometer';
      final Map<String, dynamic> data = {
        'date':      today,
        'updatedAt': FieldValue.serverTimestamp(),
        'source':    source,
      };
      if (_mode == _Mode.live) {
        if (m.heartRate      > 0) data['heartRate']      = m.heartRate;
        if (m.spo2           > 0) data['spo2']           = m.spo2;
        if (m.steps          > 0) data['steps']          = m.steps;
        if (m.caloriesBurned > 0) data['caloriesBurned'] = m.caloriesBurned;
      } else {
        if (m.steps          > 0) data['steps']          = m.steps;
        if (m.caloriesBurned > 0) data['caloriesBurned'] = m.caloriesBurned;
      }
      await ref.set(data, SetOptions(merge: true));
      _lastSyncedAt = DateTime.now();
      debugPrint('[Health] ✅ Synced — '
          'Steps=${m.steps} Cals=${m.caloriesBurned.round()} source=$source');
      notifyListeners();
    } catch (e) {
      debugPrint('[Health] ❌ Firestore sync failed: $e');
    }
  }

  // ── Background foreground-service channel ─────────────────────────────────
  static const _bgChannel    = MethodChannel('com.fitverse.app/step_service');
  static const _prefsChannel = MethodChannel('com.fitverse.app/shared_prefs');

  Future<void> _startBackgroundService() async {
    try { await _bgChannel.invokeMethod('startService'); } catch (_) {}
  }

  Future<void> _stopBackgroundService() async {
    try { await _bgChannel.invokeMethod('stopService'); } catch (_) {}
  }

  Future<void> _syncBackgroundSteps() async {
    try {
      final result = await _prefsChannel.invokeMethod<Map>('getStepData');
      if (result != null) {
        final bgSteps = (result['steps'] as int?)    ?? 0;
        final bgCals  = (result['cals']  as double?) ?? 0.0;
        if (bgSteps > _accelSteps) {
          _accelSteps = bgSteps;
          _accelCals  = bgCals;
        }
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCELEROMETER PEDOMETER
  // ═══════════════════════════════════════════════════════════════════════════

  void _startPedometer() {
    if (_accelSub != null) return;
    _syncBackgroundSteps();
    _startBackgroundService();
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 50), // 20 Hz
    ).listen(_processStepData, onError: (_) {});
  }

  void _stopPedometer() {
    _accelSub?.cancel();
    _accelSub = null;
    _stopBackgroundService();
  }

  // ── Core step-detection algorithm ─────────────────────────────────────────

  void _processStepData(AccelerometerEvent event) {
    // ── 1. Gravity removal via low-pass IIR ──────────────────────────────
    _lpX = _gravAlpha * _lpX + (1 - _gravAlpha) * event.x;
    _lpY = _gravAlpha * _lpY + (1 - _gravAlpha) * event.y;
    _lpZ = _gravAlpha * _lpZ + (1 - _gravAlpha) * event.z;

    // High-pass = raw − gravity estimate
    final hpX = event.x - _lpX;
    final hpY = event.y - _lpY;
    final hpZ = event.z - _lpZ;

    // ── 2. Dynamic-acceleration magnitude ────────────────────────────────
    final rawMag = sqrt(hpX * hpX + hpY * hpY + hpZ * hpZ);

    // ── 3. Magnitude smoothing (light LP) — kills single-sample spikes ───
    _smoothMag = _magAlpha * rawMag + (1 - _magAlpha) * _smoothMag;

    // ── 4. Adaptive running maximum (exponential decay) ──────────────────
    _runningMax = max(_smoothMag, _runningMax * _maxDecay);

    // Derive adaptive threshold, clamped to sane bounds
    final threshold = (_thresholdFactor * _runningMax)
        .clamp(_minThreshold, _maxThreshold);
    final valley = _valleyFactor * threshold;

    // ── 5. Peak / valley state machine ────────────────────────────────────
    final now = DateTime.now();

    // If the gap since last step is very long, release the peak-lock so the
    // next stride isn't blocked waiting for a valley that already passed.
    if (_inPeak &&
        _lastStepTime != null &&
        now.difference(_lastStepTime!) > _maxStepInterval) {
      _inPeak = false;
    }

    if (_smoothMag >= threshold && !_inPeak) {
      // ── Entering a peak ──────────────────────────────────────────────
      _inPeak = true;

      // Cadence gate: reject if too soon after the previous step
      final elapsed = _lastStepTime == null
          ? _minStepInterval + const Duration(milliseconds: 1)
          : now.difference(_lastStepTime!);

      if (elapsed >= _minStepInterval) {
        _lastStepTime = now;
        _accelSteps++;
        _accelCals = _accelSteps * _calsPerStep;
        _updateAccelMetrics();
      }
    } else if (_smoothMag < valley) {
      // ── Valley confirmed — ready for next peak ───────────────────────
      _inPeak = false;
    }
  }

  void _updateAccelMetrics() {
    final cached   = _cachedSnapshot;
    final cachedHr = cached != null && cached.heartRate > 0 && cached.source == 'health_connect';
    final cachedSp = cached != null && cached.spo2      > 0 && cached.source == 'health_connect';

    _metrics = HealthMetrics(
      heartRate:      cachedHr ? cached.heartRate : 0,
      spo2:           cachedSp ? cached.spo2      : 0,
      steps:          _accelSteps,
      caloriesBurned: _accelCals,
      isLive:         false,
      isAccelSteps:   true,
      isHrCached:     cachedHr,
      isSpO2Cached:   cachedSp,
    );
    notifyListeners();
  }

  // ── Accel-mode periodic Firestore sync ─────────────────────────────────────

  void _startAccelSyncTimer() {
    _accelSyncTimer?.cancel();
    _accelSyncTimer = Timer.periodic(_accelSyncInterval, (_) {
      if (_accelSteps != _lastSyncedAccelSteps) {
        _lastSyncedAccelSteps = _accelSteps;
        _syncToFirestore();
      }
    });
  }

  void _stopAccelSyncTimer() {
    _accelSyncTimer?.cancel();
    _accelSyncTimer = null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCEL MODE entry point
  // ═══════════════════════════════════════════════════════════════════════════

  void startAccelMode() => _enterAccelMode('Using phone pedometer for steps.');

  void _enterAccelMode(String reason) {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _stopAccelSyncTimer();

    _isConnected = false;
    _mode        = _Mode.accel;
    _error       = reason;

    _startPedometer();
    _startAccelSyncTimer();
    _updateAccelMetrics();

    _loadTodaySnapshot().then((_) => _updateAccelMetrics());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEALTH CONNECT permissions
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> requestHealthConnectPermissions() async {
    _isRequesting = true;
    _error        = null;
    notifyListeners();

    try {
      await Permission.activityRecognition.request();
      await Permission.sensors.request();
      await _health.configure();

      final available = await _health.isHealthConnectAvailable();
      if (!available) {
        _enterAccelMode(
          'Health Connect is not installed. '
          'Install it from the Play Store, then try again. '
          'Steps are being counted via your phone\'s accelerometer.',
        );
        _isRequesting = false;
        notifyListeners();
        return false;
      }

      final alreadyGranted =
          await _health.hasPermissions(_types, permissions: _readOnly);
      if (alreadyGranted == true) {
        await _enterLive();
        _isRequesting = false;
        notifyListeners();
        return _isConnected;
      }

      final granted = await _health.requestAuthorization(
        _types,
        permissions: _readOnly,
      );

      if (granted) {
        await _enterLive();
      } else {
        _enterAccelMode(
          'Health Connect permissions denied. '
          'Open Health Connect → App permissions → FitVerse to grant access. '
          'Steps are being counted via your phone\'s accelerometer.',
        );
      }
    } catch (e) {
      _enterAccelMode(
        'Could not connect to Health Connect. '
        'Steps are being counted via your phone\'s accelerometer.',
      );
    }

    _isRequesting = false;
    notifyListeners();
    return _isConnected;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LIVE MODE (Health Connect)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _enterLive() async {
    _stopPedometer();
    _stopAccelSyncTimer();

    _isConnected = true;
    _mode        = _Mode.live;
    _error       = null;

    await _loadTodaySnapshot();
    await _fetchHealthData();
  }

  Future<void> _fetchHealthData() async {
    if (_mode != _Mode.live) return;

    try {
      final now = DateTime.now();

      final hrData = await _health.getHealthDataFromTypes(
        startTime: now.subtract(const Duration(hours: 2)),
        endTime:   now,
        types:     [HealthDataType.HEART_RATE],
      );

      final spo2Data = await _health.getHealthDataFromTypes(
        startTime: now.subtract(const Duration(hours: 4)),
        endTime:   now,
        types:     [HealthDataType.BLOOD_OXYGEN],
      );

      final startOfDay = DateTime(now.year, now.month, now.day);
      final stepsToday = await _health.getTotalStepsInInterval(startOfDay, now) ?? 0;

      final calData  = await _health.getHealthDataFromTypes(
        startTime: startOfDay,
        endTime:   now,
        types:     [HealthDataType.ACTIVE_ENERGY_BURNED],
      );
      final uniqueCal = _deduplicatePoints(calData);
      final cals      = uniqueCal.fold<double>(0, (s, d) => s + _extractNumeric(d));

      final prev = _metrics;
      final hr   = hrData.isNotEmpty   ? _extractNumeric(hrData.last)   : prev.heartRate;
      final spo2 = spo2Data.isNotEmpty ? _extractNumeric(spo2Data.last) : prev.spo2;

      _metrics = HealthMetrics(
        heartRate:      hr   > 0 ? hr   : prev.heartRate,
        spo2:           spo2 > 0 ? spo2 : prev.spo2,
        steps:          stepsToday > 0 ? stepsToday : prev.steps,
        caloriesBurned: cals       > 0 ? cals       : prev.caloriesBurned,
        isLive:         true,
        isAccelSteps:   false,
        isHrCached:     false,
        isSpO2Cached:   false,
      );
      notifyListeners();

      final now2 = DateTime.now();
      if (_lastSyncedAt == null ||
          now2.difference(_lastSyncedAt!).inSeconds >= 30) {
        await _syncToFirestore();
      } else {
        notifyListeners();
      }

      _refreshTimer?.cancel();
      _refreshTimer = Timer(const Duration(seconds: 5), _fetchHealthData);
    } catch (e) {
      _refreshTimer?.cancel();
      _refreshTimer = Timer(const Duration(seconds: 60), _fetchHealthData);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<HealthDataPoint> _deduplicatePoints(List<HealthDataPoint> points) {
    final seen   = <String>{};
    final result = <HealthDataPoint>[];
    for (final p in points) {
      final key = '${p.dateFrom.millisecondsSinceEpoch}_${p.value}';
      if (seen.add(key)) result.add(p);
    }
    return result;
  }

  double _extractNumeric(HealthDataPoint? point) {
    if (point == null) return 0;
    final v = point.value;
    if (v is NumericHealthValue) return v.numericValue.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  void refreshNow() {
    if (_mode == _Mode.live) {
      _refreshTimer?.cancel();
      _fetchHealthData();
    } else if (_mode == _Mode.accel) {
      _syncBackgroundSteps().then((_) => _updateAccelMetrics());
    }
  }

  void disconnect() {
    _stopPedometer();
    _stopAccelSyncTimer();
    _refreshTimer?.cancel();
    _refreshTimer   = null;
    _isConnected    = false;
    _mode           = _Mode.idle;
    _metrics        = const HealthMetrics();
    _cachedSnapshot = null;
    _lastSyncedAt   = null;
    notifyListeners();
  }

  void resetAccelSteps() {
    _accelSteps = 0;
    _accelCals  = 0;
    _runningMax = 0;
    _smoothMag  = 0;
    _inPeak     = false;
    if (_mode == _Mode.accel) _updateAccelMetrics();
  }

  @override
  void dispose() {
    _stopPedometer();
    _stopAccelSyncTimer();
    _refreshTimer?.cancel();
    super.dispose();
  }
}
