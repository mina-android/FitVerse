import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import 'health_conditions_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _ageCtrl    = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  String _gender = 'Male';
  String _goal   = 'Build Muscle';
  bool   _loading = false;
  String? _errorMsg;

  final List<String> _genders = ['Male', 'Female'];
  final List<String> _goals = [
    'Build Muscle', 'Lose Weight', 'Improve Endurance',
    'General Fitness', 'Athletic Performance',
  ];

  @override
  void initState() {
    super.initState();
    final google = context.read<AuthProvider>().googleUser;
    if (google != null) _nameCtrl.text = google.displayName ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _ageCtrl.dispose();
    _weightCtrl.dispose(); _heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _errorMsg = null; });

    final auth   = context.read<AuthProvider>();
    final userP  = context.read<UserProvider>();
    final google = auth.googleUser!;

    // Use Firebase Auth UID — this is what Firestore security rules check.
    // FirebaseAuth.instance.currentUser is guaranteed non-null here because
    // _AuthenticatedRoot waited for it before showing this screen.
    final uid = FirebaseAuth.instance.currentUser?.uid ?? auth.uid!;

    final ok = await userP.createUser(
      uid:              uid,
      name:             _nameCtrl.text.trim(),
      email:            google.email,
      photoUrl:         google.photoUrl,
      age:              int.parse(_ageCtrl.text),
      weightKg:         double.parse(_weightCtrl.text),
      heightCm:         double.parse(_heightCtrl.text),
      gender:           _gender,
      healthConditions: [],
      fitnessGoal:      _goal,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!ok) {
      // Write failed — still continue locally, just warn the user
      debugPrint('[ProfileSetup] ⚠️  Firestore write failed — saved locally only');
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HealthConditionsScreen()),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.seedColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Step 1 of 2',
                          style: TextStyle(
                              color: AppTheme.seedColor,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  const Text('Your Profile',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'Tell us about yourself to personalise your experience.',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6), fontSize: 15),
                  ),
                  if (_errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_errorMsg!,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 13)),
                    ),
                  ],
                  const SizedBox(height: 32),

                  _label('Full Name'),
                  _field(
                    controller: _nameCtrl,
                    hint: 'e.g. Alex Ahmed',
                    icon: Icons.person_outline,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  Row(children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Age'),
                        _field(
                          controller: _ageCtrl,
                          hint: '28',
                          icon: Icons.cake_outlined,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            return (n == null || n < 10 || n > 100)
                                ? 'Invalid' : null;
                          },
                        ),
                      ],
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Weight (kg)'),
                        _field(
                          controller: _weightCtrl,
                          hint: '75',
                          icon: Icons.monitor_weight_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (v) {
                            final n = double.tryParse(v ?? '');
                            return (n == null || n < 20 || n > 300)
                                ? 'Invalid' : null;
                          },
                        ),
                      ],
                    )),
                  ]),
                  const SizedBox(height: 16),

                  Row(children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Height (cm)'),
                        _field(
                          controller: _heightCtrl,
                          hint: '180',
                          icon: Icons.height,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final n = double.tryParse(v ?? '');
                            return (n == null || n < 100 || n > 250)
                                ? 'Invalid' : null;
                          },
                        ),
                      ],
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Gender'),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.cardDark,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _gender,
                              dropdownColor: AppTheme.cardDark,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                              isExpanded: true,
                              items: _genders
                                  .map((g) => DropdownMenuItem(
                                      value: g, child: Text(g)))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _gender = v!),
                            ),
                          ),
                        ),
                      ],
                    )),
                  ]),
                  const SizedBox(height: 20),

                  _label('Fitness Goal'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _goals.map((g) => GestureDetector(
                      onTap: () => setState(() => _goal = g),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: _goal == g
                              ? AppTheme.seedColor
                              : AppTheme.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _goal == g
                                ? AppTheme.seedColor
                                : Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Text(g,
                            style: TextStyle(
                              color:
                                  _goal == g ? Colors.white : Colors.white60,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            )),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.seedColor))
                        : ElevatedButton(
                            onPressed: _next,
                            child: const Text('Continue →'),
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        validator: validator,
        decoration: InputDecoration(
            hintText: hint, prefixIcon: Icon(icon)),
      );
}
