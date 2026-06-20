import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _heightCtrl;
  String? _selectedGender;
  String? _selectedGoal;
  List<String> _selectedConditions = [];
  bool _isEditing = false;
  bool _isSaving = false;

  final _genders = ['Male', 'Female'];
  final _goals = [
    'Lose Weight',
    'Build Muscle',
    'Improve Endurance',
    'Stay Active',
    'Rehabilitation',
  ];
  final _conditions = [
    'Asthma',
    'Diabetes',
    'Hypertension',
    'Knee Pain',
    'Back Pain',
    'Heart Condition',
    'Obesity',
    'Arthritis',
  ];

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().user;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _ageCtrl = TextEditingController(text: user == null ? '' : user.age.toString());
    _weightCtrl = TextEditingController(text: user == null ? '' : user.weightKg.toString());
    _heightCtrl = TextEditingController(text: user == null ? '' : user.heightCm.toString());
    _selectedGender = user?.gender;
    _selectedGoal = user?.fitnessGoal;
    _selectedConditions = List.from(user?.healthConditions ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final userProvider = context.read<UserProvider>();
    await userProvider.updateProfile(
      name: _nameCtrl.text.trim(),
      age: int.tryParse(_ageCtrl.text),
      weightKg: double.tryParse(_weightCtrl.text),
      heightCm: double.tryParse(_heightCtrl.text),
      gender: _selectedGender,
      fitnessGoal: _selectedGoal,
      healthConditions: _selectedConditions,
    );
    setState(() {
      _isSaving = false;
      _isEditing = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated!',
              style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: const Color(0xFF00897B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _cancelEdit() {
    final user = context.read<UserProvider>().user;
    setState(() {
      _nameCtrl.text = user?.name ?? '';
      _ageCtrl.text = user == null ? '' : user.age.toString();
      _weightCtrl.text = user == null ? '' : user.weightKg.toString();
      _heightCtrl.text = user == null ? '' : user.heightCm.toString();
      _selectedGender = user?.gender;
      _selectedGoal = user?.fitnessGoal;
      _selectedConditions = List.from(user?.healthConditions ?? []);
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1C1E),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          final user = userProvider.user;
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return CustomScrollView(
            slivers: [
              _buildAppBar(user),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatsRow(user),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Personal Info'),
                        const SizedBox(height: 12),
                        _buildPersonalInfoCard(),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Fitness Goal'),
                        const SizedBox(height: 12),
                        _buildGoalSelector(),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Health Conditions'),
                        const SizedBox(height: 12),
                        _buildConditionsGrid(),
                        const SizedBox(height: 24),
                        if (_isEditing) _buildSaveButton(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar(UserModel user) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: const Color(0xFF0F1C1E),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (!_isEditing)
          TextButton.icon(
            onPressed: () => setState(() => _isEditing = true),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: Text('Edit', style: GoogleFonts.inter(fontSize: 14)),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF00897B)),
          )
        else
          TextButton(
            onPressed: _cancelEdit,
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: Colors.red.shade300, fontSize: 14)),
          ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF00695C), Color(0xFF0F1C1E)],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                CircleAvatar(
                  radius: 45,
                  backgroundImage: user.photoUrl != null
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  backgroundColor: const Color(0xFF00897B),
                  child: user.photoUrl == null
                      ? Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.inter(
                              fontSize: 36, color: Colors.white),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  user.name,
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                Text(
                  user.email,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: Colors.white60),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(UserModel user) {
    final sessions = context.read<UserProvider>().sessions;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E31),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _statItem(
              '${user.totalWorkouts}', 'Workouts', Icons.fitness_center_rounded),
          _divider(),
          _statItem('${user.totalCalories.toStringAsFixed(0)}', 'Calories',
              Icons.local_fire_department_rounded),
          _divider(),
          _statItem(
              user.bmiCategory, 'BMI', Icons.monitor_weight_rounded),
          _divider(),
          _statItem('${sessions.length}', 'Sessions',
              Icons.calendar_today_rounded),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF00897B), size: 20),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          Text(label,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1, height: 40, color: Colors.white12,
      );

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white70),
    );
  }

  Widget _buildPersonalInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E31),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildField(
            controller: _nameCtrl,
            label: 'Full Name',
            icon: Icons.person_rounded,
            enabled: _isEditing,
            validator: (v) =>
                v == null || v.isEmpty ? 'Name is required' : null,
          ),
          const Divider(color: Colors.white12, height: 24),
          Row(
            children: [
              Expanded(
                child: _buildField(
                  controller: _ageCtrl,
                  label: 'Age',
                  icon: Icons.cake_rounded,
                  enabled: _isEditing,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGenderDropdown(),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 24),
          Row(
            children: [
              Expanded(
                child: _buildField(
                  controller: _weightCtrl,
                  label: 'Weight (kg)',
                  icon: Icons.monitor_weight_rounded,
                  enabled: _isEditing,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildField(
                  controller: _heightCtrl,
                  label: 'Height (cm)',
                  icon: Icons.height_rounded,
                  enabled: _isEditing,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: GoogleFonts.inter(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF00897B), size: 20),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF00897B)),
        ),
        disabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.transparent),
        ),
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedGender,
      onChanged: _isEditing
          ? (v) => setState(() => _selectedGender = v)
          : null,
      dropdownColor: const Color(0xFF1A2E31),
      style: GoogleFonts.inter(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Gender',
        labelStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
        prefixIcon: const Icon(Icons.wc_rounded,
            color: Color(0xFF00897B), size: 20),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        disabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.transparent),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
      items: _genders
          .map((g) => DropdownMenuItem(
              value: g,
              child: Text(g, style: GoogleFonts.inter(fontSize: 13))))
          .toList(),
    );
  }

  Widget _buildGoalSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _goals.map((goal) {
        final selected = _selectedGoal == goal;
        return GestureDetector(
          onTap: _isEditing
              ? () => setState(() => _selectedGoal = goal)
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF00897B)
                  : const Color(0xFF1A2E31),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: selected
                    ? const Color(0xFF00897B)
                    : Colors.white24,
              ),
            ),
            child: Text(
              goal,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: selected ? Colors.white : Colors.white60,
                fontWeight: selected
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildConditionsGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _conditions.map((cond) {
        final selected = _selectedConditions.contains(cond);
        return GestureDetector(
          onTap: _isEditing
              ? () {
                  setState(() {
                    if (selected) {
                      _selectedConditions.remove(cond);
                    } else {
                      _selectedConditions.add(cond);
                    }
                  });
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF00897B).withOpacity(0.2)
                  : const Color(0xFF1A2E31),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: selected
                    ? const Color(0xFF00897B)
                    : Colors.white12,
              ),
            ),
            child: Text(
              cond,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: selected ? Colors.white : Colors.white54,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00897B),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isSaving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text('Save Changes',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
      ),
    );
  }
}
