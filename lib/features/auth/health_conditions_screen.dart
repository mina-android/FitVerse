import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../main/main_shell.dart';

class HealthConditionsScreen extends StatefulWidget {
  const HealthConditionsScreen({super.key});
  @override
  State<HealthConditionsScreen> createState() => _HealthConditionsScreenState();
}

class _HealthConditionsScreenState extends State<HealthConditionsScreen> {
  final Set<String> _selected = {};
  bool _loading = false;

  final List<_Condition> _conditions = const [
    _Condition('Mild Asthma', '', 'Breathing difficulty during exercise'),
    _Condition('Type 2 Diabetes', '', 'Blood sugar management needed'),
    _Condition('Hypertension', '', 'High blood pressure'),
    _Condition('Knee Pain', '', 'Joint stress sensitivity'),
    _Condition('Lower Back Pain', '', 'Spinal loading caution'),
    _Condition('Heart Condition', '', 'Cardiac monitoring required'),
    _Condition('Obesity', '', 'High BMI, low-impact preferred'),
    _Condition('Arthritis', '', 'Joint inflammation sensitivity'),
  ];

  Future<void> _complete() async {
    setState(() => _loading = true);
    await context
        .read<UserProvider>()
        .updateProfile(healthConditions: _selected.toList());

    context.read<AuthProvider>().markProfileComplete();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F1C1E), AppTheme.surfaceDark],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.seedColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Step 2 of 2',
                          style: TextStyle(
                              color: AppTheme.seedColor,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 20),
                    const Text('Health Profile',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      'Select any conditions to let our AI tailor advice specifically for you. This is optional.',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 15),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _conditions.length,
                  itemBuilder: (_, i) {
                    final c = _conditions[i];
                    final selected = _selected.contains(c.name);
                    return GestureDetector(
                      onTap: () => setState(() => selected
                          ? _selected.remove(c.name)
                          : _selected.add(c.name)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.seedColor.withOpacity(0.15)
                              : AppTheme.cardDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? AppTheme.seedColor
                                : Colors.white.withOpacity(0.08),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(c.emoji, style: const TextStyle(fontSize: 28)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.name,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15)),
                                  Text(c.description,
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? AppTheme.seedColor
                                    : Colors.transparent,
                                border: Border.all(
                                  color: selected
                                      ? AppTheme.seedColor
                                      : Colors.white30,
                                  width: 2,
                                ),
                              ),
                              child: selected
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 14)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  children: [
                    if (_selected.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '${_selected.length} condition(s) selected — AI will adapt accordingly.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppTheme.tealAccent, fontSize: 13),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: _loading
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: AppTheme.seedColor))
                          : ElevatedButton(
                              onPressed: _complete,
                              child: Text(
                                _selected.isEmpty
                                    ? 'Skip & Complete Setup'
                                    : 'Complete Setup',
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Condition {
  final String name;
  final String emoji;
  final String description;
  const _Condition(this.name, this.emoji, this.description);
}
