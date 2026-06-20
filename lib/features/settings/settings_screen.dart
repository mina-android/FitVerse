import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/health_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/ai_provider.dart';
import '../auth/onboarding_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _voiceAlertsEnabled = true;

  // ── API key dialog state ───────────────────────────────────────────────────
  final _keyController = TextEditingController();
  bool  _keyObscured   = true;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1C1E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Settings',
            style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        centerTitle: false,
        elevation: 0,
      ),
      body: Consumer2<HealthProvider, UserProvider>(
        builder: (context, health, userProvider, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // ── Health & Data ───────────────────────────────────────────
              _sectionHeader('Health & Data'),
              _buildHealthConnectCard(health),
              const SizedBox(height: 8),
              _buildTile(
                icon: Icons.delete_outline_rounded,
                iconColor: Colors.orange,
                title: 'Clear Workout History',
                subtitle: 'Remove all saved workout sessions',
                onTap: () => _confirmClearHistory(context, userProvider),
              ),

              const SizedBox(height: 24),

              // ── AI Configuration ────────────────────────────────────────
              _sectionHeader('AI Configuration'),
              _buildApiKeyCard(),

              const SizedBox(height: 24),

              // ── App Preferences ─────────────────────────────────────────
              _sectionHeader('App Preferences'),
              _buildSwitchTile(
                icon: Icons.record_voice_over_rounded,
                iconColor: Colors.blue,
                title: 'Voice Alerts',
                subtitle: 'TTS form correction during workouts',
                value: _voiceAlertsEnabled,
                onChanged: (v) => setState(() => _voiceAlertsEnabled = v),
              ),

              const SizedBox(height: 24),

              // ── Logout ──────────────────────────────────────────────────
              _buildLogoutButton(),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  // ── API Key Card ───────────────────────────────────────────────────────────

  Widget _buildApiKeyCard() {
    return Consumer<AIProvider>(
      builder: (context, ai, _) {
        final hasKey  = ai.hasCustomKey;
        final keyOk   = ai.activeKey.startsWith('AIza');
        final statusColor = keyOk ? const Color(0xFF00897B) : Colors.orange;
        final statusLabel = keyOk ? 'Active' : 'Not configured';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2E31),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: keyOk
                  ? const Color(0xFF00897B).withOpacity(0.5)
                  : Colors.orange.withOpacity(0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: keyOk
                            ? [const Color(0xFF00897B), const Color(0xFF26A69A)]
                            : [Colors.orange.shade700, Colors.orange.shade900],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.psychology_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Gemini API Key',
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                        Text(
                          hasKey
                              ? 'Custom key · ${ai.maskedKey}'
                              : 'Using built-in key',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Info text
              Text(
                'The AI Coach and post-workout reports are powered by Google '
                'Gemini. You can use the built-in key or supply your own from '
                'ai.google.dev for higher rate limits.',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showApiKeyDialog(context, ai),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: Text(
                        hasKey ? 'Update Key' : 'Add My Key',
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  if (hasKey) ...[
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => _confirmClearKey(context, ai),
                      icon: const Icon(Icons.restore_rounded, size: 16),
                      label: Text('Reset',
                          style: GoogleFonts.inter(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white54,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 16),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── API Key Dialog ─────────────────────────────────────────────────────────

  void _showApiKeyDialog(BuildContext context, AIProvider ai) {
    _keyController.text = '';
    _keyObscured = true;
    String? dialogError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A2E31),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.vpn_key_rounded,
                    color: Color(0xFF00897B), size: 22),
                const SizedBox(width: 10),
                Text(
                  ai.hasCustomKey ? 'Update API Key' : 'Add Gemini API Key',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 17),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paste your Gemini API key from ai.google.dev. '
                  'It will be validated and saved securely on this device.',
                  style:
                      GoogleFonts.inter(fontSize: 13, color: Colors.white60),
                ),
                const SizedBox(height: 16),

                // Key input
                TextField(
                  controller: _keyController,
                  obscureText: _keyObscured,
                  style: GoogleFonts.robotoMono(
                      fontSize: 13, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'AIzaSy...',
                    hintStyle:
                        GoogleFonts.robotoMono(color: Colors.white30, fontSize: 13),
                    filled: true,
                    fillColor: Colors.black26,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF00897B), width: 1.5),
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Toggle visibility
                        IconButton(
                          icon: Icon(
                            _keyObscured
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: Colors.white38,
                            size: 18,
                          ),
                          onPressed: () =>
                              setDialogState(() => _keyObscured = !_keyObscured),
                        ),
                        // Paste from clipboard
                        IconButton(
                          icon: const Icon(Icons.content_paste_rounded,
                              color: Colors.white38, size: 18),
                          tooltip: 'Paste',
                          onPressed: () async {
                            final data =
                                await Clipboard.getData('text/plain');
                            if (data?.text != null) {
                              _keyController.text = data!.text!.trim();
                              setDialogState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Error message
                if (dialogError != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Colors.redAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(dialogError!,
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  ),
                ],

                // Validating indicator
                if (ai.isValidatingKey) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF00897B),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('Validating key…',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF00897B))),
                    ],
                  ),
                ],

                const SizedBox(height: 4),
              ],
            ),
            actions: [
              TextButton(
                onPressed:
                    ai.isValidatingKey ? null : () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: GoogleFonts.inter(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: ai.isValidatingKey
                    ? null
                    : () async {
                        setDialogState(() => dialogError = null);
                        final err =
                            await ai.updateApiKey(_keyController.text);
                        if (err != null) {
                          setDialogState(() => dialogError = err);
                        } else {
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '✅ Gemini API key saved successfully!',
                                  style: GoogleFonts.inter(color: Colors.white),
                                ),
                                backgroundColor: const Color(0xFF00897B),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  disabledBackgroundColor: Colors.white12,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Save & Validate',
                    style: GoogleFonts.inter(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmClearKey(BuildContext context, AIProvider ai) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2E31),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reset API Key?',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.bold, color: Colors.white)),
        content: Text(
          'This will remove your custom key and revert to the built-in key.',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ai.clearCustomApiKey();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('API key reset to built-in default',
                        style: GoogleFonts.inter(color: Colors.white)),
                    backgroundColor: Colors.orange.shade700,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Reset',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF00897B),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildHealthConnectCard(HealthProvider health) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E31),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: health.isConnected
              ? const Color(0xFF00897B).withOpacity(0.5)
              : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: health.isConnected
                        ? [const Color(0xFF00897B), const Color(0xFF26A69A)]
                        : [Colors.grey.shade700, Colors.grey.shade800],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.monitor_heart_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Google Health Connect',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                    Text(
                      health.isConnected
                          ? 'Connected — syncing live data'
                          : 'Not connected — using phone pedometer for steps',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: health.isConnected
                              ? const Color(0xFF00897B)
                              : Colors.white54),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: health.isConnected
                      ? const Color(0xFF00897B).withOpacity(0.2)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  health.isConnected ? 'ON' : 'OFF',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: health.isConnected
                        ? const Color(0xFF00897B)
                        : Colors.white38,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (health.isConnected) ...[
            _dataRow(Icons.favorite_rounded, Colors.red,
                'Heart Rate', '${health.metrics.heartRate.toStringAsFixed(0)} bpm'),
            const SizedBox(height: 8),
            _dataRow(Icons.air_rounded, Colors.blue,
                'Blood Oxygen', '${health.metrics.spo2.toStringAsFixed(1)}%'),
            const SizedBox(height: 8),
            _dataRow(Icons.directions_walk_rounded, const Color(0xFF00897B),
                'Steps Today', '${health.metrics.steps}'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  health.disconnect();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Health Connect disconnected'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
                icon: const Icon(Icons.link_off_rounded, size: 16),
                label: Text('Disconnect',
                    style: GoogleFonts.inter(fontSize: 14)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade300,
                  side: BorderSide(color: Colors.red.shade300),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ] else ...[
            Text(
              'Connect Health Connect to sync real-time heart rate, blood oxygen and step data from your Wear OS smartwatch.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white54),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final granted =
                      await health.requestHealthConnectPermissions();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          granted
                              ? 'Health Connect connected!'
                              : 'Permission denied — using phone pedometer for steps',
                        ),
                        backgroundColor: granted
                            ? const Color(0xFF00897B)
                            : Colors.orange,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.link_rounded, size: 16),
                label: Text('Connect Health Connect',
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dataRow(IconData icon, Color color, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(label,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white54)),
        const Spacer(),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
      ],
    );
  }

  Widget _buildTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E31),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title,
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white)),
        subtitle: Text(subtitle,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white38)),
        trailing: trailing ??
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white38, size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E31),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title,
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white)),
        subtitle: Text(subtitle,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white38)),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF00897B),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? const Color(0xFF00897B).withOpacity(0.3)
                : Colors.white12,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.shade900.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade700.withOpacity(0.4)),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
        ),
        title: Text('Sign Out',
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade300)),
        subtitle: Text('Sign out of your FitVerse account',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.red.shade700)),
        onTap: _confirmLogout,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2E31),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign Out?',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.bold, color: Colors.white)),
        content: Text(
          'Are you sure you want to sign out of FitVerse? Your data will be saved.',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              context.read<UserProvider>().reset();
              context.read<HealthProvider>().disconnect();
              context.read<AIProvider>().resetSession();

              await context.read<AuthProvider>().signOut();

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (_) => const OnboardingScreen()),
                    (route) => false,
                  );
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Sign Out',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _confirmClearHistory(BuildContext context, UserProvider userProvider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2E31),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear History?',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.bold, color: Colors.white)),
        content: Text(
          'This will permanently delete all your workout sessions. This cannot be undone.',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await userProvider.clearSessions();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Workout history cleared'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Clear',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
