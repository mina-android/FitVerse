import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/workout_model.dart';
import '../../../models/user_model.dart';

class AISuggestionBanner extends StatefulWidget {
  final UserModel? user;
  final SessionModel latestSession;

  const AISuggestionBanner({
    super.key,
    required this.user,
    required this.latestSession,
  });

  @override
  State<AISuggestionBanner> createState() => _AISuggestionBannerState();
}

class _AISuggestionBannerState extends State<AISuggestionBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final session = widget.latestSession;
    final hasAsthma = user?.healthConditions
            .any((c) => c.toLowerCase().contains('asthma')) ??
        false;
    final proteinG = ((user?.weightKg ?? 75) * 0.35).round();
    final carbG = ((user?.weightKg ?? 75) * 0.6).round();
    final name = user?.name.split(' ').first ?? 'Athlete';

    final healthNote = hasAsthma
        ? 'Great intensity, $name! Since you have asthma, please spend 5 minutes doing controlled breathing cool-down exercises.'
        : 'Nice work, $name! Your ${session.workoutName} session was ${session.intensity.toLowerCase()} intensity. Keep it up!';

    final nutrition =
        'Suggested recovery meal: ${proteinG}g protein + ${carbG}g carbs. Try whey protein with a banana, or a tuna sandwich on whole wheat. Drink 500ml of water now.';

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1A237E).withOpacity(0.8),
              AppTheme.seedColor.withOpacity(0.4),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.seedColor.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('🤖', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'AI Post-Workout Suggestion',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.white60,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              healthNote,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, height: 1.4),
            ),
            if (_expanded) ...[
              const SizedBox(height: 10),
              Container(
                height: 1,
                color: Colors.white.withOpacity(0.1),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🥗', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      nutrition,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('😴', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rest this muscle group for 48 hours. Prioritize 7-9 hours of sleep — that\'s when real muscle building happens.',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
