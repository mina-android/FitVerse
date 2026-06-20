import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/user_provider.dart';
import '../../providers/health_provider.dart';
import '../../models/workout_model.dart';
import 'widgets/metric_card.dart';
import 'widgets/ai_suggestion_banner.dart';
import 'widgets/workout_history_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user         = userProvider.user;
    final healthP      = context.watch<HealthProvider>();
    final health       = healthP.metrics;
    final sessions     = userProvider.recentSessions;
    final allSessions  = userProvider.sessions;
    final firstName    = user?.name.split(' ').first ?? 'Athlete';

    final hour     = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning'
        : hour < 17  ? 'Good Afternoon'
        : 'Good Evening';

    final syncedLabel = _formatSyncedAgo(healthP.lastSyncedAt);

    return Scaffold(
      backgroundColor: AppTheme.surfaceDark,
      body: RefreshIndicator(
        color: AppTheme.seedColor,
        onRefresh: () async {
          await context
              .read<HealthProvider>()
              .requestHealthConnectPermissions();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              Text(
                '$greeting, $firstName!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getMotivationalQuote(),
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 13),
              ),
              const SizedBox(height: 20),

              // ── Live Biometrics ────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Live Biometrics',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600),
                  ),
                  if (health.isAccelSteps)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA726).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFFFA726).withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone_android,
                              color: Color(0xFFFFA726), size: 11),
                          SizedBox(width: 4),
                          Text('Phone Pedometer',
                              style: TextStyle(
                                  color: Color(0xFFFFA726),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  MetricCard(
                    label: 'Heart Rate',
                    value: health.heartRate == 0
                        ? '--'
                        : '${health.heartRate.round()}',
                    unit: health.heartRate == 0 ? '' : 'bpm',
                    icon: Icons.favorite_rounded,
                    iconColor: const Color(0xFFEF5350),
                    gradient: const [Color(0xFF2D1B1B), Color(0xFF3D2020)],
                    isLive: health.isLive,
                    isCached: health.isHrCached,
                    cachedLabel: syncedLabel,
                    unavailable: health.heartRate == 0 && !health.isLive && !health.isHrCached,
                  ),
                  MetricCard(
                    label: 'Blood Oxygen',
                    value: health.spo2 == 0
                        ? '--'
                        : health.spo2.toStringAsFixed(1),
                    unit: health.spo2 == 0 ? '' : '%',
                    icon: Icons.water_drop_rounded,
                    iconColor: const Color(0xFF42A5F5),
                    gradient: const [Color(0xFF1B2438), Color(0xFF1E2D4A)],
                    isLive: health.isLive,
                    isCached: health.isSpO2Cached,
                    cachedLabel: syncedLabel,
                    unavailable: health.spo2 == 0 && !health.isLive && !health.isSpO2Cached,
                  ),
                  MetricCard(
                    label: health.isAccelSteps ? 'Steps (Phone)' : 'Steps Today',
                    value: _formatSteps(health.steps),
                    unit: 'steps',
                    icon: Icons.directions_walk_rounded,
                    iconColor: const Color(0xFF66BB6A),
                    gradient: const [Color(0xFF1B2D1E), Color(0xFF1E3522)],
                    isLive: health.isLive || health.isAccelSteps,
                  ),
                  MetricCard(
                    label: 'Calories',
                    value: '${health.caloriesBurned.round()}',
                    unit: 'kcal',
                    icon: Icons.local_fire_department_rounded,
                    iconColor: const Color(0xFFFFA726),
                    gradient: const [Color(0xFF2D2218), Color(0xFF3D2E1B)],
                    isLive: health.isLive || health.isAccelSteps,
                  ),
                ],
              ),

              // ── Accel info strip ────────────────────────────────────────
              if (health.isAccelSteps) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2E31),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFFFA726).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Color(0xFFFFA726), size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Heart rate & SpO2 require Google Health Connect. '
                          'Steps & calories are estimated from your phone\'s motion sensor.',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Activity chart
              if (sessions.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Weekly Activity',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _WeeklyChart(sessions: sessions),
              ],

              // AI Nutrition Suggestion
              if (sessions.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'AI Nutrition Suggestion',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                AISuggestionBanner(
                    user: user, latestSession: sessions.first),
              ],

              // Recent Workouts
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Workouts',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600),
                  ),
                  if (allSessions.isNotEmpty)
                    Text(
                      '${allSessions.length} total',
                      style: const TextStyle(
                          color: AppTheme.seedColor, fontSize: 13),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (sessions.isEmpty)
                _EmptyWorkoutsCard()
              else
                ...sessions.map((s) => WorkoutHistoryCard(session: s)),

              // ── Stats summary — derived from live sessions list ─────────
              if (user != null) ...[
                const SizedBox(height: 24),
                _StatsRow(
                  user: user,
                  // Compute directly from the sessions list so the numbers
                  // are always accurate regardless of the stored counters.
                  totalWorkouts: allSessions.length,
                  totalCalories: allSessions.fold(
                      0.0, (sum, s) => sum + s.caloriesBurned),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSteps(int steps) {
    if (steps >= 1000) return '${(steps / 1000).toStringAsFixed(1)}k';
    return steps.toString();
  }

  static String? _formatSyncedAgo(DateTime? dt) {
    if (dt == null) return null;
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return null;
    if (diff.inMinutes < 60)  return '${diff.inMinutes} min ago';
    if (diff.inHours   < 24)  return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }

  String _getMotivationalQuote() {
    final quotes = [
      'Every rep counts. Every set matters.',
      'Progress, not perfection.',
      'Your only competition is yesterday\'s you.',
      'Strong body, strong mind.',
      'Consistency is the key to transformation.',
    ];
    return quotes[DateTime.now().day % quotes.length];
  }
}

// ─── Weekly chart ─────────────────────────────────────────────────────────────

class _WeeklyChart extends StatelessWidget {
  final List<SessionModel> sessions;
  const _WeeklyChart({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekData = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final s = sessions.where((s) =>
          s.date.day == day.day &&
          s.date.month == day.month &&
          s.date.year == day.year);
      return s.fold(0.0, (sum, session) => sum + session.caloriesBurned);
    });

    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final todayIndex = now.weekday - 1;

    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (weekData.reduce((a, b) => a > b ? a : b) + 100)
              .clamp(100, double.infinity),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, meta) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= days.length) return const SizedBox();
                  final dayIdx = (now.weekday - 1 - (6 - idx) + 7) % 7;
                  return Text(
                    days[dayIdx],
                    style: TextStyle(
                      color:
                          idx == 6 ? AppTheme.seedColor : Colors.white38,
                      fontSize: 12,
                      fontWeight: idx == 6
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: weekData.asMap().entries.map((e) {
            final isToday = e.key == todayIndex;
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value > 0 ? e.value : 0,
                  color: isToday
                      ? AppTheme.seedColor
                      : AppTheme.seedColor.withOpacity(0.3),
                  width: 16,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _EmptyWorkoutsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.seedColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.fitness_center,
              color: AppTheme.seedColor.withOpacity(0.4), size: 40),
          const SizedBox(height: 12),
          const Text('No workouts yet',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'Head to the Workouts tab to start your first session!',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withOpacity(0.5), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Stats row ────────────────────────────────────────────────────────────────
// Values are passed in as computed-from-sessions so they are always accurate.

class _StatsRow extends StatelessWidget {
  final dynamic user;
  final int    totalWorkouts;
  final double totalCalories;

  const _StatsRow({
    required this.user,
    required this.totalWorkouts,
    required this.totalCalories,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.seedColor.withOpacity(0.2),
            AppTheme.tealAccent.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.seedColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat('$totalWorkouts', 'Workouts'),
          _divider(),
          _Stat('${totalCalories.round()}', 'Total kcal'),
          _divider(),
          _Stat(user.bmi.toStringAsFixed(1), 'BMI'),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 36, color: Colors.white.withOpacity(0.1));
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat(this.value, this.label);

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
