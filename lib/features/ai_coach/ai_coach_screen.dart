import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/ai_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/workout_model.dart';

class AICoachScreen extends StatefulWidget {
  const AICoachScreen({super.key});
  @override
  State<AICoachScreen> createState() => _AICoachScreenState();
}

class _AICoachScreenState extends State<AICoachScreen> {
  final TextEditingController _msgCtrl    = TextEditingController();
  final ScrollController      _scrollCtrl = ScrollController();

  bool _initialized      = false;
  int  _lastSessionCount = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAIContext();
  }

  void _syncAIContext() {
    final userProvider = context.read<UserProvider>();
    if (userProvider.user == null) return;

    final ai           = context.read<AIProvider>();
    final sessions     = userProvider.recentSessions;
    final sessionCount = userProvider.sessions.length;
    final uid          = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (!_initialized) {
      ai.initializeSession(
        user: userProvider.user!,
        recentSessions: sessions,
        uid: uid,
      );
      _initialized      = true;
      _lastSessionCount = sessionCount;
      return;
    }

    if (sessionCount != _lastSessionCount) {
      ai.refreshContext(user: userProvider.user!, recentSessions: sessions);
      _lastSessionCount = sessionCount;
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    await context.read<AIProvider>().sendMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear chat history?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will permanently delete all messages from this device '
          'and Firestore. This cannot be undone.',
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final userProvider = context.read<UserProvider>();
      await context.read<AIProvider>().clearHistory(
        userProvider.user!,
        userProvider.recentSessions,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<UserProvider>();

    final ai       = context.watch<AIProvider>();
    final messages = ai.messages;

    return Column(
      children: [
        // ── Header banner ──────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.seedColor.withOpacity(0.2),
                AppTheme.tealAccent.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.seedColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Text('🤖', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gemini AI Coach',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    Text('Personalized · Health-aware · Context-driven',
                        style: TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
              _SessionBadge(
                  count: _lastSessionCount < 0 ? 0 : _lastSessionCount),
              const SizedBox(width: 8),
              // Clear history button
              if (!ai.isLoadingHistory)
                GestureDetector(
                  onTap: _confirmClearHistory,
                  child: Tooltip(
                    message: 'Clear chat history',
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_sweep_outlined,
                          color: Colors.white38, size: 16),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── Loading indicator (while history is being fetched) ─────────────
        if (ai.isLoadingHistory)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.seedColor),
                ),
                const SizedBox(width: 10),
                Text('Restoring your conversation...',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.45), fontSize: 12)),
              ],
            ),
          ),

        // ── Quick prompts (always visible for fast topic access) ──────────
        if (!ai.isLoadingHistory) _QuickPrompts(onTap: _sendQuick),

        // ── Messages ───────────────────────────────────────────────────────
        Expanded(
          child: ai.isLoadingHistory
              ? const SizedBox.shrink()
              : messages.isEmpty
                  ? const _EmptyChat()
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (_, i) =>
                          _MessageBubble(message: messages[i]),
                    ),
        ),

        // ── Input bar ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            border:
                Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  enabled: !ai.isLoadingHistory,
                  decoration: InputDecoration(
                    hintText: ai.isLoadingHistory
                        ? 'Loading history...'
                        : 'Ask your AI coach anything...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: AppTheme.cardDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: (ai.isThinking || ai.isLoadingHistory) ? null : _send,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (ai.isThinking || ai.isLoadingHistory)
                        ? Colors.white12
                        : AppTheme.seedColor,
                    shape: BoxShape.circle,
                  ),
                  child: (ai.isThinking || ai.isLoadingHistory)
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _sendQuick(String text) {
    _msgCtrl.text = text;
    _send();
  }
}

// ─── Session count badge ──────────────────────────────────────────────────────
class _SessionBadge extends StatelessWidget {
  final int count;
  const _SessionBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: count > 0
            ? const Color(0xFF1B5E20).withOpacity(0.8)
            : Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 0 ? '📋 $count workouts' : '📋 No history yet',
        style: TextStyle(
          color: count > 0 ? const Color(0xFF81C784) : Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🤖', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    const Text('AI Coach',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.seedColor : AppTheme.cardDark,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
              ),
              child: message.isLoading
                  ? const _TypingIndicator()
                  : Text(
                      message.content,
                      style: TextStyle(
                          color: isUser
                              ? Colors.white
                              : Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          height: 1.5),
                    ),
            ),
            // Timestamp
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
              child: Text(
                _formatTime(message.timestamp),
                style: const TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    if (isToday) return '$hh:$mm';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]}, $hh:$mm';
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: const Text('Thinking...',
          style: TextStyle(color: Colors.white54, fontSize: 14)),
    );
  }
}

class _QuickPrompts extends StatelessWidget {
  final void Function(String) onTap;
  const _QuickPrompts({required this.onTap});

  static const List<String> _prompts = [
    'Analyse my recent workout history',
    'What should I eat after my last session?',
    'How do I build muscle faster?',
    'How much rest do I need between sessions?',
    'Suggest a recovery routine for me',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        scrollDirection: Axis.horizontal,
        itemCount: _prompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => onTap(_prompts[i]),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Text(
              _prompts[i],
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🤖', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text('AI Coach is ready',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Ask me anything about your fitness journey',
              style: TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }
}
