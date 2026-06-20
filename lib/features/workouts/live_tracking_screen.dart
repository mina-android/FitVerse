import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/workout_model.dart';
import '../../providers/workout_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/ai_provider.dart';
import '../../providers/health_provider.dart';

class LiveTrackingScreen extends StatefulWidget {
  final Exercise exercise;

  // ── Preset mode ─────────────────────────────────────────────────────────
  // When [onExerciseComplete] is non-null the screen is running as part of a
  // preset.  In this mode:
  //   • The result dialog shows "Next Exercise →" (or "Finish Preset" for the
  //     last exercise) instead of "Back to Workouts".
  //   • The session is NOT saved to Firestore here — PresetWorkoutScreen
  //     collects all per-exercise sessions and saves one combined record.
  //   • [exerciseIndex] and [totalExercises] drive the progress label.
  final WorkoutPreset?               preset;
  final int?                         exerciseIndex;
  final int?                         totalExercises;
  final void Function(SessionModel)? onExerciseComplete;

  const LiveTrackingScreen({
    super.key,
    required this.exercise,
    this.preset,
    this.exerciseIndex,
    this.totalExercises,
    this.onExerciseComplete,
  });

  bool get isPresetMode => onExerciseComplete != null;
  bool get isLastInPreset =>
      isPresetMode &&
      exerciseIndex != null &&
      totalExercises != null &&
      exerciseIndex! == totalExercises! - 1;

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  bool _started = false;
  bool _finishing = false;
  Timer? _hrRefreshTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 1.0, end: 1.08)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    // Start periodic heart-rate refresh every 5 seconds.
    // This triggers a Health Connect fetch so the displayed bpm stays current.
    _hrRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        final hp = context.read<HealthProvider>();
        if (hp.isConnected) {
          // Re-trigger the health fetch pipeline without blocking the UI.
          hp.refreshNow();
        }
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _hrRefreshTimer?.cancel();
    super.dispose();
  }

  void _startWorkout() {
    setState(() => _started = true);
    context.read<WorkoutProvider>().startTracking();
  }

  Future<void> _finishWorkout() async {
    setState(() => _finishing = true);
    final session = context.read<WorkoutProvider>().stopTracking();

    // ── Preset mode ─────────────────────────────────────────────────────────
    // Hand the raw session back to PresetWorkoutScreen, which collects all
    // per-exercise sessions and saves one combined Firestore record at the end.
    // No AI report is generated here — the preset screen handles that too.
    if (widget.isPresetMode) {
      setState(() => _finishing = false);
      _showResultDialog(context, session, '', false);
      return;
    }

    // ── Single-exercise mode ─────────────────────────────────────────────────
    final user       = context.read<UserProvider>().user!;
    final aiProvider = context.read<AIProvider>();
    final aiReport   = await aiProvider.generatePostWorkoutReport(
      user:          user,
      session:       session,
      exerciseNames: [widget.exercise.name],
    );
    final wasRealAI = aiProvider.lastReportWasAI;

    await context.read<UserProvider>().addSession(session);

    if (!mounted) return;
    setState(() => _finishing = false);
    _showResultDialog(context, session, aiReport, wasRealAI);
  }

  void _showResultDialog(BuildContext ctx, SessionModel session, String report,
      [bool isRealAI = false]) {
    final isPreset    = widget.isPresetMode;
    final isLast      = widget.isLastInPreset;
    final idx         = widget.exerciseIndex ?? 0;
    final total       = widget.totalExercises ?? 1;

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header icon
              Container(
                width:  56,
                height: 56,
                decoration: const BoxDecoration(
                    color: Color(0xFF1B5E20), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    color: Color(0xFF81C784), size: 30),
              ),
              const SizedBox(height: 12),
              Text(
                isPreset
                    ? 'Exercise ${idx + 1} of $total Done!'
                    : 'Workout Complete!',
                style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   20,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(widget.exercise.name,
                  style: TextStyle(
                      color:   Colors.white.withOpacity(0.45), fontSize: 13)),
              const SizedBox(height: 16),

              // Per-exercise stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ResultStat('${session.durationMinutes}m', 'Time'),
                  _ResultStat('${session.caloriesBurned.round()}', 'kcal'),
                  _ResultStat('${session.accuracyScore.round()}%', 'Accuracy'),
                ],
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: Colors.white.withOpacity(0.08)),
              const SizedBox(height: 16),

              // AI report (only in single-exercise mode)
              if (!isPreset && report.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:        AppTheme.seedColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                    border:       Border.all(
                        color: AppTheme.seedColor.withOpacity(0.20)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.smart_toy_outlined,
                            color: AppTheme.seedColor, size: 14),
                        const SizedBox(width: 6),
                        const Text('AI Coach Report',
                            style: TextStyle(
                                color:      AppTheme.seedColor,
                                fontWeight: FontWeight.bold,
                                fontSize:   13)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: isRealAI
                                ? const Color(0xFF1B5E20).withOpacity(0.8)
                                : Colors.white.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isRealAI ? '✨ Live AI' : '📋 Template',
                            style: TextStyle(
                                color:      isRealAI
                                    ? const Color(0xFF81C784)
                                    : Colors.white38,
                                fontSize:   10,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: SingleChildScrollView(
                          child: Text(report,
                              style: TextStyle(
                                  color:   Colors.white.withOpacity(0.85),
                                  fontSize: 12,
                                  height:  1.5)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Preset-mode: show next exercise hint
              if (isPreset && !isLast) ...[
                Text('Keep going — more exercises ahead!',
                    style: TextStyle(
                        color:   Colors.white.withOpacity(0.45),
                        fontSize: 12),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
              ],

              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();    // close dialog
                    Navigator.of(context).pop(); // pop LiveTrackingScreen
                    // In preset mode, trigger the callback AFTER popping so
                    // PresetWorkoutScreen is visible when the rest card slides in.
                    if (isPreset) widget.onExerciseComplete!(session);
                  },
                  icon: Icon(isPreset && !isLast
                      ? Icons.arrow_forward_rounded
                      : Icons.check_rounded),
                  label: Text(
                    isPreset
                        ? (isLast ? 'Finish Preset' : 'Next Exercise →')
                        : 'Back to Workouts',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();
    final health = context.watch<HealthProvider>().metrics;
    final formColor = wp.formStatus == FormStatus.good
        ? AppTheme.seedColor
        : wp.formStatus == FormStatus.warning
            ? const Color(0xFFFFA726)
            : const Color(0xFFEF5350);

    return Scaffold(
      backgroundColor: AppTheme.surfaceDark,
      appBar: AppBar(
        title: widget.isPresetMode
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.exercise.name,
                      style: const TextStyle(fontSize: 15)),
                  Text(
                    'Exercise ${(widget.exerciseIndex ?? 0) + 1} of ${widget.totalExercises ?? 1}',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.55)),
                  ),
                ],
              )
            : Text(widget.exercise.name),
        backgroundColor: AppTheme.surfaceDark,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (_started) {
              context.read<WorkoutProvider>().stopTracking();
            }
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Exercise emoji
            ScaleTransition(
              scale: _pulse,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: RadialGradient(colors: [
                    formColor.withOpacity(0.3),
                    formColor.withOpacity(0.05),
                  ]),
                  shape: BoxShape.circle,
                  border: Border.all(color: formColor, width: 2),
                ),
                child: Center(
                  child: Icon(Icons.fitness_center,
                      color: formColor, size: 52),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Form status
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: formColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: formColor.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(
                    wp.formStatus == FormStatus.good
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_rounded,
                    color: formColor,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      wp.formMessage,
                      style: TextStyle(
                          color: formColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Stats grid
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.2,
              children: [
                _TrackStat(
                  label: 'Set',
                  value:
                      '${wp.currentSet}/${widget.exercise.sets}',
                  icon: Icons.repeat,
                  color: AppTheme.seedColor,
                ),
                _TrackStat(
                  label: 'Time',
                  value: _formatTime(wp.elapsedSeconds),
                  icon: Icons.timer_outlined,
                  color: const Color(0xFF42A5F5),
                ),
                _TrackStat(
                  label: 'Accuracy',
                  value: '${wp.accuracyScore.round()}%',
                  icon: Icons.star_outline_rounded,
                  color: const Color(0xFFFFA726),
                ),
                _TrackStat(
                  label: 'Heart Rate',
                  value: '${health.heartRate.round()} bpm',
                  icon: Icons.favorite_outline_rounded,
                  color: const Color(0xFFEF5350),
                ),
                // Reps this set vs. target (e.g. "4 / 10")
                _TrackStat(
                  label: 'Reps (set)',
                  value: '${wp.currentReps} / ${widget.exercise.reps}',
                  icon: Icons.fitness_center_outlined,
                  color: const Color(0xFF66BB6A),
                ),
                // Cumulative reps across all sets in this session
                _TrackStat(
                  label: 'Total Reps',
                  value: '${wp.totalReps}',
                  icon: Icons.bar_chart_rounded,
                  color: const Color(0xFFAB47BC),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Accuracy bar
            if (_started) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Form Accuracy',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  Text('${wp.accuracyScore.round()}%',
                      style: TextStyle(
                          color: formColor, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: wp.accuracyScore / 100,
                  minHeight: 10,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(formColor),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Form cues quick reference
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Form Reminders',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const SizedBox(height: 10),
                  ...widget.exercise.formCues.take(3).map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Text('•', style: TextStyle(color: AppTheme.seedColor)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(c,
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 12,
                                        height: 1.4)),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Start / Finish button
            SizedBox(
              width: double.infinity,
              child: _finishing
                  ? const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: AppTheme.seedColor),
                          SizedBox(height: 12),
                          Text('Generating AI report...',
                              style: TextStyle(color: Colors.white60)),
                        ],
                      ),
                    )
                  : _started
                      ? ElevatedButton.icon(
                          onPressed: _finishWorkout,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('Finish Workout'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF5350),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: _startWorkout,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Start Workout'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _TrackStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _TrackStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.45), fontSize: 10)),
        ],
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String value;
  final String label;
  const _ResultStat(this.value, this.label);
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.5), fontSize: 11)),
      ],
    );
  }
}
