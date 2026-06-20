import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/user_provider.dart';
import '../home/home_screen.dart';
import '../workouts/workouts_screen.dart';
import '../ai_coach/ai_coach_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const List<_TabConfig> _tabs = [
    _TabConfig(
        icon: Icons.home_rounded,
        activeIcon: Icons.home,
        label: 'Home'),
    _TabConfig(
        icon: Icons.fitness_center_outlined,
        activeIcon: Icons.fitness_center,
        label: 'Workouts'),
    _TabConfig(
        icon: Icons.smart_toy_outlined,
        activeIcon: Icons.smart_toy,
        label: 'AI Coach'),
  ];

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final screenTitles = ['Dashboard', 'Workouts', 'AI Coach'];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.seedColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.fitness_center,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              screenTitles[_index],
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          // Settings icon (top-right)
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          // Profile icon (top-right, next to settings)
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: Container(
              margin: const EdgeInsets.only(right: 16, left: 4),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.cardDark2,
                backgroundImage: user?.photoUrl != null
                    ? NetworkImage(user!.photoUrl!)
                    : null,
                child: user?.photoUrl == null
                    ? Text(
                        (user?.name.isNotEmpty == true)
                            ? user!.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          WorkoutsScreen(),
          AICoachScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border:
              Border(top: BorderSide(color: Color(0xFF1E3538), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          items: _tabs
              .map((t) => BottomNavigationBarItem(
                    icon: Icon(t.icon),
                    activeIcon: Icon(t.activeIcon),
                    label: t.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _TabConfig {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabConfig(
      {required this.icon, required this.activeIcon, required this.label});
}
