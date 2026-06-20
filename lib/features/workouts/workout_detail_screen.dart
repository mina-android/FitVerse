import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/workout_data.dart';
import '../../models/workout_model.dart';
import '../../providers/workout_provider.dart';
import 'live_tracking_screen.dart';

class WorkoutDetailScreen extends StatelessWidget {
  final Exercise exercise;
  final WorkoutPreset? preset;

  const WorkoutDetailScreen({
    super.key,
    required this.exercise,
    this.preset,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceDark,
      body: CustomScrollView(
        slivers: [
          // Hero header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppTheme.surfaceDark,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF004D40), Color(0xFF00695C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 44),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          exercise.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          exercise.muscleGroup,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Exercise Animation / Demo ─────────────────────────────
                _ExerciseAnimationWidget(exercise: exercise),
                const SizedBox(height: 20),

                // ── Quick stats chips ─────────────────────────────────────
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatChip(Icons.fitness_center, exercise.muscleGroup),
                    _StatChip(Icons.bar_chart, exercise.difficulty),
                    _StatChip(Icons.build_outlined, exercise.equipment),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Sets / Reps / kcal ────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _WorkoutStat('${exercise.sets}', 'Sets'),
                      _vDivider(),
                      _WorkoutStat(exercise.reps, 'Reps'),
                      _vDivider(),
                      _WorkoutStat(
                          '~${exercise.kalories * exercise.sets}', 'kcal'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── About ─────────────────────────────────────────────────
                _SectionTitle('About'),
                const SizedBox(height: 8),
                Text(
                  exercise.description,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 14,
                      height: 1.6),
                ),
                const SizedBox(height: 20),

                // ── Muscles worked ────────────────────────────────────────
                _SectionTitle('Muscles Worked'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: exercise.muscles
                      .map((m) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppTheme.seedColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppTheme.seedColor.withOpacity(0.3)),
                            ),
                            child: Text(m,
                                style: const TextStyle(
                                    color: AppTheme.seedColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 20),

                // ── How to perform ────────────────────────────────────────
                _SectionTitle('How To Perform'),
                const SizedBox(height: 12),
                ...exercise.steps.asMap().entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: AppTheme.seedColor,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${e.key + 1}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  e.value,
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 14,
                                      height: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: 20),

                // ── Form cues ─────────────────────────────────────────────
                _SectionTitle('Form Cues'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2E31),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: AppTheme.seedColor.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: exercise.formCues
                        .map(
                          (cue) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('⚡', style: TextStyle(fontSize: 14)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    cue,
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 13,
                                        height: 1.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Start button ──────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context
                          .read<WorkoutProvider>()
                          .setActiveExercise(exercise);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              LiveTrackingScreen(exercise: exercise),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start Live Tracking'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vDivider() =>
      Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1));
}

// ─────────────────────────────────────────────────────────────────────────────
// EXERCISE ANIMATION WIDGET
// Alternates between frame 0 and frame 1 from the free-exercise-db GitHub repo
// with a smooth cross-fade transition. Falls back to an emoji display if
// the gifUrl is empty or the network images fail to load.
// ─────────────────────────────────────────────────────────────────────────────

class _ExerciseAnimationWidget extends StatefulWidget {
  final Exercise exercise;
  const _ExerciseAnimationWidget({required this.exercise});

  @override
  State<_ExerciseAnimationWidget> createState() =>
      _ExerciseAnimationWidgetState();
}

class _ExerciseAnimationWidgetState extends State<_ExerciseAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  Timer? _frameTimer;
  bool _showFrame1 = false;
  bool _frame0Failed = false;
  bool _frame1Failed = false;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);

    if (widget.exercise.gifUrl.isNotEmpty) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    _frameTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (!mounted) return;
      setState(() => _showFrame1 = !_showFrame1);
      if (_showFrame1) {
        _fadeCtrl.forward(from: 0);
      } else {
        _fadeCtrl.reverse(from: 1);
      }
    });
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  String get _frame0Url =>
      WorkoutData.frame0(widget.exercise.gifUrl);
  String get _frame1Url =>
      WorkoutData.frame1(widget.exercise.gifUrl);

  @override
  Widget build(BuildContext context) {
    final hasAnimation =
        widget.exercise.gifUrl.isNotEmpty && !(_frame0Failed && _frame1Failed);

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF0D2226),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.seedColor.withOpacity(0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // ── Background gradient ──────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [
                  AppTheme.seedColor.withOpacity(0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // ── Animation frames or icon fallback ─────────────────────
          if (!hasAnimation)
            // No gifUrl — show icon with exercise name
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: AppTheme.seedColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppTheme.seedColor.withOpacity(0.30), width: 2),
                    ),
                    child: const Icon(Icons.fitness_center,
                        color: AppTheme.seedColor, size: 52),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.exercise.name,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.65), fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Exercise preview not available',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.35), fontSize: 11),
                  ),
                ],
              ),
            )
          else
            // Frame 0 (always visible beneath frame 1)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: _frame0Url,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) {
                  if (!_frame0Failed) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _frame0Failed = true);
                    });
                  }
                  return _buildEmojiFallback();
                },
                placeholder: (_, __) => _buildLoadingPlaceholder(),
              ),
            ),

          // Frame 1 (fades in/out on top of frame 0)
          if (hasAnimation)
            Positioned.fill(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: CachedNetworkImage(
                  imageUrl: _frame1Url,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) {
                    if (!_frame1Failed) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _frame1Failed = true);
                      });
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),

          // ── Label bar at bottom ──────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.seedColor.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppTheme.seedColor.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.seedColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text('Demo',
                            style: TextStyle(
                                color: AppTheme.seedColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.exercise.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),

          // ── Frame indicator dots ──────────────────────────────────────
          if (hasAnimation)
            Positioned(
              top: 10,
              right: 10,
              child: Row(
                children: [
                  _FrameDot(active: !_showFrame1),
                  const SizedBox(width: 4),
                  _FrameDot(active: _showFrame1),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      color: const Color(0xFF0D2226),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.seedColor.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading demo...',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiFallback() {
    return Container(
      color: const Color(0xFF0D2226),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppTheme.seedColor.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppTheme.seedColor.withOpacity(0.25), width: 1.5),
              ),
              child: const Icon(Icons.fitness_center,
                  color: AppTheme.seedColor, size: 42),
            ),
            const SizedBox(height: 8),
            Text(
              widget.exercise.name,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrameDot extends StatelessWidget {
  final bool active;
  const _FrameDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: active ? 16 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: active
            ? AppTheme.seedColor
            : Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

// ─── Supporting widgets ───────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
          color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip(this.icon, this.label);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.seedColor, size: 13),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

class _WorkoutStat extends StatelessWidget {
  final String value;
  final String label;
  const _WorkoutStat(this.value, this.label);
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.5), fontSize: 12)),
      ],
    );
  }
}
