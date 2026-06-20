import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'sign_in_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _page = 0;
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  final List<_OnboardPage> _pages = const [
    _OnboardPage(
      emoji: '🏋️',
      title: 'Train Smarter',
      subtitle:
          'Access a complete library of exercises with real-time form detection using your phone sensors and smartwatch.',
      gradient: [Color(0xFF004D40), Color(0xFF00695C)],
    ),
    _OnboardPage(
      emoji: '🤖',
      title: 'AI Nutrition Coach',
      subtitle:
          'Get hyper-personalized post-workout nutrition plans tailored to your health conditions and fitness goals.',
      gradient: [Color(0xFF1A237E), Color(0xFF283593)],
    ),
    _OnboardPage(
      emoji: '❤️',
      title: 'Live Biometrics',
      subtitle:
          'Sync with Google Health Connect to track heart rate, blood oxygen, steps, and calories in real time.',
      gradient: [Color(0xFF4A148C), Color(0xFF6A1B9A)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      _goToSignIn(isNewUser: true);
    }
  }

  void _goToSignIn({bool isNewUser = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => SignInScreen(isNewUser: isNewUser)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: _pages.length,
            itemBuilder: (_, i) => _PageView(page: _pages[i]),
          ),
          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _page ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? Colors.white
                              : Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.seedColor,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        _page == _pages.length - 1 ? 'Get Started' : 'Next',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => _goToSignIn(isNewUser: false),
                    child: const Text(
                      'Already have an account? Sign In',
                      style: TextStyle(
                          color: Colors.white70, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),   // Scaffold
    );   // FadeTransition
  }
}

class _PageView extends StatelessWidget {
  final _OnboardPage page;
  const _PageView({required this.page});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: page.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 60),
            Text(page.emoji, style: const TextStyle(fontSize: 100)),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                page.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Text(
                page.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 16,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage {
  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  const _OnboardPage(
      {required this.emoji,
      required this.title,
      required this.subtitle,
      required this.gradient});
}
