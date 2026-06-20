import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/workout_model.dart';
import 'workout_detail_screen.dart';

IconData _muscleIcon(String groupId) {
  switch (groupId) {
    case 'chest': return Icons.fitness_center;
    case 'back': return Icons.airline_seat_flat;
    case 'shoulders': return Icons.sports_gymnastics;
    case 'legs': return Icons.directions_walk;
    case 'arms': return Icons.fitness_center;
    case 'core': return Icons.radio_button_checked;
    case 'calves': return Icons.directions_run;
    case 'glutes': return Icons.sports_handball;
    case 'forearms': return Icons.back_hand;
    case 'cardio': return Icons.favorite;
    case 'trapezius': return Icons.keyboard_double_arrow_up;
    case 'neck': return Icons.self_improvement;
    case 'lower_back': return Icons.architecture;
    case 'hamstrings': return Icons.directions_walk;
    case 'quadriceps': return Icons.directions_run;
    case 'hip_flexors': return Icons.accessibility_new;
    case 'adductors': return Icons.compress;
    case 'abductors': return Icons.expand;
    case 'serratus': return Icons.waves;
    case 'obliques': return Icons.rotate_right;
    default: return Icons.sports_gymnastics;
  }
}

IconData _exerciseIcon(String difficulty) {
  switch (difficulty) {
    case 'Beginner': return Icons.play_circle_outline;
    case 'Intermediate': return Icons.fitness_center;
    case 'Advanced': return Icons.local_fire_department;
    default: return Icons.fitness_center;
  }
}

class MuscleExercisesScreen extends StatelessWidget {
  final MuscleGroup group;
  const MuscleExercisesScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final color = Color(group.color);

    return Scaffold(
      backgroundColor: AppTheme.surfaceDark,
      body: CustomScrollView(
        slivers: [
          // ── Hero header ────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppTheme.surfaceDark,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 16),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withOpacity(0.4),
                      color.withOpacity(0.1),
                      AppTheme.surfaceDark,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 90, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: color.withOpacity(0.4), width: 1.5),
                            ),
                            child: Center(
                              child: Icon(
                                _muscleIcon(group.id),
                                color: color,
                                size: 26,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${group.exercises.length} exercises',
                                    style: TextStyle(
                                        color: color,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Description ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                group.description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ),
          ),

          // ── Difficulty legend ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  _legendDot(const Color(0xFF66BB6A), 'Beginner'),
                  const SizedBox(width: 14),
                  _legendDot(const Color(0xFFFFA726), 'Intermediate'),
                  const SizedBox(width: 14),
                  _legendDot(const Color(0xFFEF5350), 'Advanced'),
                ],
              ),
            ),
          ),

          // ── Exercise list ──────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) =>
                    _ExerciseCard(exercise: group.exercises[i], color: color),
                childCount: group.exercises.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) => Row(
        children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 11)),
        ],
      );
}

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final Color color;
  const _ExerciseCard({required this.exercise, required this.color});

  Color get _diffColor => exercise.difficulty == 'Beginner'
      ? const Color(0xFF66BB6A)
      : exercise.difficulty == 'Intermediate'
          ? const Color(0xFFFFA726)
          : const Color(0xFFEF5350);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => WorkoutDetailScreen(exercise: exercise)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            // Colored icon instead of emoji
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                child: Icon(
                  _exerciseIcon(exercise.difficulty),
                  color: color,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 13),
            // Name + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${exercise.sets} sets · ${exercise.reps} reps · ${exercise.equipment}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.45), fontSize: 11),
                  ),
                ],
              ),
            ),
            // Difficulty badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _diffColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                exercise.difficulty,
                style: TextStyle(
                    color: _diffColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right,
                color: Colors.white.withOpacity(0.25), size: 18),
          ],
        ),
      ),
    );
  }
}
