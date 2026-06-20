import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/workout_model.dart';
import 'package:intl/intl.dart';

class WorkoutHistoryCard extends StatelessWidget {
  final SessionModel session;
  const WorkoutHistoryCard({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final intensityColor = session.intensity == 'High'
        ? const Color(0xFFEF5350)
        : session.intensity == 'Moderate'
            ? const Color(0xFFFFA726)
            : const Color(0xFF66BB6A);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.seedColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.fitness_center,
                color: AppTheme.seedColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.workoutName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  '${session.durationMinutes} min · ${session.caloriesBurned.round()} kcal · ${session.muscleGroup}',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: intensityColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  session.intensity,
                  style: TextStyle(
                      color: intensityColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      color: Color(0xFFFFC107), size: 13),
                  const SizedBox(width: 2),
                  Text(
                    '${session.accuracyScore.round()}%',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              Text(
                _formatDate(session.date),
                style: TextStyle(
                    color: Colors.white.withOpacity(0.35), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    if (d.day == now.day) return 'Today';
    if (d.day == now.day - 1) return 'Yesterday';
    return DateFormat('MMM d').format(d);
  }
}
