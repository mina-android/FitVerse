import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/workout_data.dart';
import '../../models/workout_model.dart';
import '../../providers/workout_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/ai_provider.dart';
import 'live_tracking_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PresetWorkoutScreen
//
// Manages the full multi-exercise flow for a WorkoutPreset:
//   1. Shows all exercises in order with a progress indicator.
//   2. Launches LiveTrackingScreen for each exercise in "preset mode".
//   3. LiveTrackingScreen in preset mode returns the SessionModel to this
//      screen instead of saving it and exiting — the preset screen collects all
//      per-exercise sessions.
//   4. After the last exercise, builds one combined SessionModel, generates the
//      AI post-workout report, saves to Firestore, and shows a summary dialog.
// ═══════════════════════════════════════════════════════════════════════════════

class PresetWorkoutScreen extends StatefulWidget {
  final WorkoutPreset preset;
  const PresetWorkoutScreen({super.key, required this.preset});

  @override
  State<PresetWorkoutScreen> createState() => _PresetWorkoutScreenState();
}

class _PresetWorkoutScreenState extends State<PresetWorkoutScreen>
    with SingleTickerProviderStateMixin {
  late final List<Exercise> _exercises;
  int _currentIndex = 0;

  // Sessions collected from each completed exercise.
  final List<SessionModel> _completed = [];

  // Whether we're on the inter-exercise rest card (between exercises).
  bool _showingRest = false;

  // Whether we're building the final combined session & AI report.
  bool _finishing = false;

  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _exercises = WorkoutData.exercisesForPreset(widget.preset);

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    // Register the preset with WorkoutProvider so TTS cues are keyed correctly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkoutProvider>().setActivePreset(widget.preset);
    });
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  // ── Getters ─────────────────────────────────────────────────────────────────

  Exercise get _currentExercise => _exercises[_currentIndex];
  bool     get _isLastExercise  => _currentIndex == _exercises.length - 1;
  int      get _totalExercises  => _exercises.length;

  // ── Called by LiveTrackingScreen when an exercise is completed ─────────────

  void _onExerciseDone(SessionModel session) {
    _completed.add(session);

    if (_isLastExercise) {
      // All exercises done → generate combined report and save.
      _buildAndSaveCombinedSession();
    } else {
      // Show the rest / transition card before the next exercise.
      setState(() {
        _showingRest = true;
        _currentIndex++;
      });
      _slideCtrl.forward(from: 0);
    }
  }

  void _continueToNext() {
    setState(() => _showingRest = false);
  }

  // ── Launch LiveTrackingScreen for the current exercise ─────────────────────

  void _startCurrentExercise() {
    final exercise = _currentExercise;
    context.read<WorkoutProvider>().setActiveExercise(exercise);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveTrackingScreen(
          exercise:          exercise,
          preset:            widget.preset,
          exerciseIndex:     _currentIndex,
          totalExercises:    _totalExercises,
          onExerciseComplete: _onExerciseDone,
        ),
      ),
    );
  }

  // ── Build one combined session from all per-exercise sessions ───────────────

  Future<void> _buildAndSaveCombinedSession() async {
    if (_completed.isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() => _finishing = true);

    // Aggregate stats across all exercises.
    final totalDuration = _completed.fold<int>(
        0, (s, m) => s + m.durationMinutes);
    final totalCals = _completed.fold<double>(
        0, (s, m) => s + m.caloriesBurned);
    final avgAccuracy = _completed.fold<double>(
            0, (s, m) => s + m.accuracyScore) /
        _completed.length;
    final allMuscles = _completed
        .expand((m) => m.musclesWorked)
        .toSet()
        .toList();
    final allExerciseNames = _exercises.map((e) => e.name).toList();

    // Derive intensity from the preset level.
    final intensity = widget.preset.level == 'Beginner'
        ? 'Low'
        : widget.preset.level == 'Advanced'
            ? 'High'
            : 'Moderate';

    // Primary muscle: most common across completed sessions.
    final muscleFreq = <String, int>{};
    for (final s in _completed) {
      muscleFreq[s.muscleGroup] = (muscleFreq[s.muscleGroup] ?? 0) + 1;
    }
    final primaryMuscle = muscleFreq.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    final combined = SessionModel(
      id:             DateTime.now().millisecondsSinceEpoch.toString(),
      workoutName:    widget.preset.name,
      muscleGroup:    primaryMuscle,
      date:           DateTime.now(),
      durationMinutes: totalDuration,
      caloriesBurned: totalCals,
      accuracyScore:  avgAccuracy,
      musclesWorked:  allMuscles,
      intensity:      intensity,
      exerciseNames:  allExerciseNames,
    );

    final user      = context.read<UserProvider>().user!;
    final aiProvider = context.read<AIProvider>();

    final aiReport = await aiProvider.generatePostWorkoutReport(
      user:          user,
      session:       combined,
      exerciseNames: allExerciseNames,
    );
    final wasRealAI = aiProvider.lastReportWasAI;

    await context.read<UserProvider>().addSession(combined);

    // Refresh AI coach context with the new session (fire-and-forget — void).
    final recentSessions = context.read<UserProvider>().recentSessions;
    aiProvider.refreshContext(user: user, recentSessions: recentSessions);

    if (!mounted) return;
    setState(() => _finishing = false);

    _showCompletionDialog(combined, aiReport, wasRealAI);
  }

  // ── Completion dialog ───────────────────────────────────────────────────────

  void _showCompletionDialog(
      SessionModel session, String report, bool wasRealAI) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Trophy icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.seedColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: AppTheme.seedColor, size: 34),
              ),
              const SizedBox(height: 12),
              Text(
                widget.preset.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Preset Complete · ${_totalExercises} exercises',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.45), fontSize: 12),
              ),
              const SizedBox(height: 18),

              // Aggregate stats
              Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ResultStat(
                        '${session.durationMinutes}m', 'Total Time'),
                    _vDiv(),
                    _ResultStat(
                        '${session.caloriesBurned.round()}', 'kcal Burned'),
                    _vDiv(),
                    _ResultStat(
                        '${session.accuracyScore.round()}%', 'Avg Accuracy'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // AI report
              _AiReportCard(report: report, isRealAI: wasRealAI),
              const SizedBox(height: 20),

              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Pop dialog, then pop PresetWorkoutScreen entirely.
                    Navigator.of(context).pop(); // dialog
                    Navigator.of(context).pop(); // preset screen
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Back to Workouts',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_finishing) return _FinishingOverlay(presetName: widget.preset.name);

    return Scaffold(
      backgroundColor: AppTheme.surfaceDark,
      body: CustomScrollView(
        slivers: [
          // ── Collapsing header ────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor: AppTheme.surfaceDark,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _confirmAbandon(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(widget.preset.color).withOpacity(0.40),
                      AppTheme.surfaceDark,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 48, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.preset.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.preset.level} · ${widget.preset.duration}',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Progress bar ────────────────────────────────────────
                const SizedBox(height: 16),
                _ProgressHeader(
                  completed: _completed.length,
                  total:     _totalExercises,
                  color:     Color(widget.preset.color),
                ),
                const SizedBox(height: 20),

                // ── Rest card (between exercises) ───────────────────────
                if (_showingRest)
                  SlideTransition(
                    position: _slideAnim,
                    child: _RestCard(
                      completedExercise: _exercises[_currentIndex - 1],
                      nextExercise: _currentExercise,
                      completedCount: _completed.length,
                      total: _totalExercises,
                      color: Color(widget.preset.color),
                      onContinue: _continueToNext,
                    ),
                  )
                else ...[

                  // ── Current exercise card ───────────────────────────
                  _CurrentExerciseCard(
                    exercise:      _currentExercise,
                    index:         _currentIndex,
                    total:         _totalExercises,
                    presetColor:   Color(widget.preset.color),
                    onStart:       _startCurrentExercise,
                  ),
                  const SizedBox(height: 24),

                  // ── Upcoming exercises list ─────────────────────────
                  if (_currentIndex + 1 < _totalExercises) ...[
                    Text(
                      'Up Next',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._exercises
                        .sublist(_currentIndex + 1)
                        .asMap()
                        .entries
                        .map((e) => _UpcomingExerciseTile(
                              exercise: e.value,
                              queueIndex:
                                  _currentIndex + 1 + e.key,
                            )),
                  ],
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAbandon(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('Abandon Preset?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          _completed.isEmpty
              ? 'This preset has not been started yet.'
              : '${_completed.length} of $_totalExercises exercises completed. '
                  'Progress will not be saved.',
          style: TextStyle(color: Colors.white.withOpacity(0.65)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Going'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Abandon',
                style: TextStyle(color: Color(0xFFEF5350))),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) Navigator.pop(context);
  }

  Widget _vDiv() =>
      Container(width: 1, height: 32, color: Colors.white.withOpacity(0.08));
}

// ═══════════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ═══════════════════════════════════════════════════════════════════════════════

// ── Progress header ────────────────────────────────────────────────────────────
class _ProgressHeader extends StatelessWidget {
  final int   completed;
  final int   total;
  final Color color;
  const _ProgressHeader(
      {required this.completed, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : completed / total;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Exercise ${completed + 1} of $total',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
          Text('$completed done',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.45), fontSize: 12)),
        ],
      ),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value:           progress,
          minHeight:       8,
          backgroundColor: Colors.white.withOpacity(0.08),
          valueColor:      AlwaysStoppedAnimation(color),
        ),
      ),
    ]);
  }
}

// ── Current exercise card ──────────────────────────────────────────────────────
class _CurrentExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final int      index;
  final int      total;
  final Color    presetColor;
  final VoidCallback onStart;

  const _CurrentExerciseCard({
    required this.exercise,
    required this.index,
    required this.total,
    required this.presetColor,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            presetColor.withOpacity(0.20),
            presetColor.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: presetColor.withOpacity(0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Label
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:        presetColor.withOpacity(0.20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Current — #${index + 1}',
                style: TextStyle(
                    color:      presetColor,
                    fontSize:   11,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 16),

        // Exercise identity
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color:        presetColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.fitness_center, color: presetColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(exercise.name,
                  style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text(exercise.muscleGroup,
                  style: TextStyle(
                      color:   Colors.white.withOpacity(0.50),
                      fontSize: 13)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),

        // Quick stats
        Row(children: [
          _QuickStat(Icons.repeat_rounded, '${exercise.sets} sets'),
          const SizedBox(width: 10),
          _QuickStat(Icons.fitness_center_outlined, exercise.reps),
          const SizedBox(width: 10),
          _QuickStat(Icons.local_fire_department_outlined,
              '~${exercise.kalories * exercise.sets} kcal'),
          const SizedBox(width: 10),
          _QuickStat(Icons.build_outlined, exercise.equipment),
        ]),
        const SizedBox(height: 18),

        // First 2 form cues
        if (exercise.formCues.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:        Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: exercise.formCues.take(2).map((cue) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Icon(Icons.bolt, color: presetColor, size: 13),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(cue,
                        style: TextStyle(
                            color:    Colors.white.withOpacity(0.65),
                            fontSize: 12,
                            height:   1.4)),
                  ),
                ]),
              )).toList(),
            ),
          ),
        const SizedBox(height: 18),

        // Start button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onStart,
            icon:  const Icon(Icons.play_arrow_rounded),
            label: const Text('Start Exercise',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: presetColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _QuickStat(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color:        Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white54, size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ]),
      );
}

// ── Upcoming exercises list tile ───────────────────────────────────────────────
class _UpcomingExerciseTile extends StatelessWidget {
  final Exercise exercise;
  final int      queueIndex;
  const _UpcomingExerciseTile(
      {required this.exercise, required this.queueIndex});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:        AppTheme.cardDark,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Container(
            width:  32,
            height: 32,
            decoration: BoxDecoration(
              color:  Colors.white.withOpacity(0.06),
              shape:  BoxShape.circle,
            ),
            child: Center(
              child: Text('${queueIndex + 1}',
                  style: const TextStyle(
                      color:      Colors.white38,
                      fontSize:   13,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(exercise.name,
                  style: TextStyle(
                      color:      Colors.white.withOpacity(0.75),
                      fontSize:   13,
                      fontWeight: FontWeight.w600)),
              Text('${exercise.sets} sets · ${exercise.reps}',
                  style: TextStyle(
                      color:   Colors.white.withOpacity(0.35),
                      fontSize: 11)),
            ]),
          ),
          Text(exercise.muscleGroup,
              style: TextStyle(
                  color:   Colors.white.withOpacity(0.30),
                  fontSize: 11)),
        ]),
      );
}

// ── Rest / transition card between exercises ───────────────────────────────────
class _RestCard extends StatelessWidget {
  final Exercise  completedExercise;
  final Exercise  nextExercise;
  final int       completedCount;
  final int       total;
  final Color     color;
  final VoidCallback onContinue;

  const _RestCard({
    required this.completedExercise,
    required this.nextExercise,
    required this.completedCount,
    required this.total,
    required this.color,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1B5E20).withOpacity(0.30),
            AppTheme.cardDark,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF66BB6A).withOpacity(0.35)),
      ),
      child: Column(children: [
        // Done badge
        Container(
          padding:    const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color:  Color(0xFF1B5E20),
            shape:  BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded,
              color: Color(0xFF81C784), size: 30),
        ),
        const SizedBox(height: 12),
        Text('${completedExercise.name} Done!',
            style: const TextStyle(
                color:      Colors.white,
                fontSize:   18,
                fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        Text('$completedCount of $total exercises complete',
            style: TextStyle(
                color:   Colors.white.withOpacity(0.45), fontSize: 12)),
        const SizedBox(height: 20),

        // Next exercise preview
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:        color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
            border:       Border.all(color: color.withOpacity(0.25)),
          ),
          child: Row(children: [
            Container(
              width:  42,
              height: 42,
              decoration: BoxDecoration(
                color:        color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.fitness_center, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Up Next',
                    style: TextStyle(
                        color:   color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(nextExercise.name,
                    style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   15,
                        fontWeight: FontWeight.w700)),
                Text(
                    '${nextExercise.sets} sets · ${nextExercise.reps} · ${nextExercise.muscleGroup}',
                    style: TextStyle(
                        color:   Colors.white.withOpacity(0.45),
                        fontSize: 11)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 18),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onContinue,
            icon:  const Icon(Icons.arrow_forward_rounded),
            label: Text('Continue to ${nextExercise.name}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Finishing overlay ──────────────────────────────────────────────────────────
class _FinishingOverlay extends StatelessWidget {
  final String presetName;
  const _FinishingOverlay({required this.presetName});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.surfaceDark,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: AppTheme.seedColor),
            const SizedBox(height: 20),
            Text('Wrapping up $presetName...',
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Generating your AI report',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.45), fontSize: 13)),
          ]),
        ),
      );
}

// ── AI report card (reused from live_tracking_screen pattern) ─────────────────
class _AiReportCard extends StatelessWidget {
  final String report;
  final bool   isRealAI;
  const _AiReportCard({required this.report, required this.isRealAI});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        AppTheme.seedColor.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: AppTheme.seedColor.withOpacity(0.20)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.smart_toy_outlined,
                color: AppTheme.seedColor, size: 16),
            const SizedBox(width: 6),
            const Text('AI Coach Report',
                style: TextStyle(
                    color:      AppTheme.seedColor,
                    fontWeight: FontWeight.bold,
                    fontSize:   13)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
                      color:   Colors.white.withOpacity(0.80),
                      fontSize: 12,
                      height:  1.5)),
            ),
          ),
        ]),
      );
}

class _ResultStat extends StatelessWidget {
  final String value;
  final String label;
  const _ResultStat(this.value, this.label);

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: const TextStyle(
                color:      Colors.white,
                fontSize:   18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color:   Colors.white.withOpacity(0.45), fontSize: 10)),
      ]);
}
