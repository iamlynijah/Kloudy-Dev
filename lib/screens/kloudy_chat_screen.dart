import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/ai_service.dart';
import '../services/supabase_service.dart';
import '../theme/kloudy_theme.dart' show kGold, kBackground, kChipIndigo;
import '../widgets/commons_suggestions.dart';
import '../widgets/kloudy_mark.dart';

class KloudyChatScreen extends StatefulWidget {
  final String? initialMessage;
  const KloudyChatScreen({super.key, this.initialMessage});

  @override
  State<KloudyChatScreen> createState() => _KloudyChatScreenState();
}

class _KloudyChatScreenState extends State<KloudyChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();

  bool _loading = true;
  bool _thinking = false;
  Map<String, dynamic> _userContext = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final results = await Future.wait([
      SupabaseService.fetchChatHistory(),
      SupabaseService.buildAiContext(),
    ]);

    final history = results[0] as List<Map<String, dynamic>>;
    final context = results[1] as Map<String, dynamic>;

    if (!mounted) return;
    setState(() {
      _messages.addAll(history.map((j) => ChatMessage.fromJson(j)));
      _userContext = context;
      _loading = false;
    });

    _scrollToBottom();

    if (widget.initialMessage != null &&
        widget.initialMessage!.trim().isNotEmpty) {
      await _send(widget.initialMessage!.trim());
    }
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final userMsg = ChatMessage(role: 'user', content: trimmed);
    setState(() {
      _messages.add(userMsg);
      _thinking = true;
    });
    _ctrl.clear();
    _scrollToBottom();

    await SupabaseService.saveChatMessage(role: 'user', content: trimmed);

    try {
      final reply = await AiService.send(
        history: _messages.sublist(0, _messages.length - 1),
        message: trimmed,
        userContext: _userContext,
      );

      if (!mounted) return;
      final assistantMsg = ChatMessage(role: 'assistant', content: reply);
      setState(() {
        _messages.add(assistantMsg);
        _thinking = false;
      });
      await SupabaseService.saveChatMessage(role: 'assistant', content: reply);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            role: 'assistant',
            content:
                "I'm having a little trouble connecting right now. Give me a second and try again 💙",
          ),
        );
        _thinking = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final onSurface = th.colorScheme.onSurface;
    final card = th.cardColor;
    final bg = th.scaffoldBackgroundColor;
    final primary = th.colorScheme.primary;
    final onPrimary = th.colorScheme.onPrimary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: onSurface,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const KloudyMark(size: 32),
            const SizedBox(width: 10),
            Text(
              'Kloudy',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: onSurface,
              ),
            ),
          ],
        ),
        titleSpacing: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: th.dividerColor),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: onSurface.withValues(alpha: 0.3),
                      strokeWidth: 1.5,
                    ),
                  )
                : _messages.isEmpty && !_thinking
                ? _buildEmptyState(context)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    itemCount: _messages.length + (_thinking ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (_thinking && i == _messages.length) {
                        return _TypingBubble(
                          cardColor: card,
                          onSurface: onSurface,
                        );
                      }
                      return _MessageBubble(message: _messages[i]);
                    },
                  ),
          ),
          _InputBar(
            controller: _ctrl,
            focus: _focus,
            card: card,
            onSurface: onSurface,
            primary: primary,
            onPrimary: onPrimary,
            onSend: () {
              if (_ctrl.text.trim().isNotEmpty && !_thinking) {
                _send(_ctrl.text);
              }
            },
            onSuggestion: (prompt) {
              _ctrl
                ..text = prompt
                ..selection = TextSelection.collapsed(offset: prompt.length);
              _focus.requestFocus();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final th = Theme.of(context);
    final onSurface = th.colorScheme.onSurface;

    return Column(
      children: [
        // ── Warm gradient hero ──────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(32, 56, 32, 48),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [kChipIndigo, kBackground],
            ),
          ),
          child: Column(
            children: [
              // Gold-ring logo
              Container(
                width: 84,
                height: 84,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFD4A855), kGold],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kGold.withValues(alpha: 0.28),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const KloudyMark(size: 80),
              ),
              const SizedBox(height: 28),
              Text(
                "Hey, I'm Kloudy.",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                  color: onSurface,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "Your personal guide to food, sleep,\nmoney, and everything in between.",
                style: TextStyle(
                  fontSize: 15,
                  color: onSurface.withValues(alpha: 0.48),
                  height: 1.6,
                  letterSpacing: 0.1,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // ── Starter topics ──────────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'START WITH',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: onSurface.withValues(alpha: 0.38),
                  ),
                ),
                const SizedBox(height: 14),
                ..._starterTopics.map(
                  (t) => _StarterRow(
                    emoji: t['emoji']!,
                    label: t['label']!,
                    onTap: () => _send(t['label']!),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static const List<Map<String, String>> _starterTopics = [
    {'emoji': '🍽️', 'label': "What should I eat today?"},
    {'emoji': '💰', 'label': "How am I doing on my budget?"},
    {'emoji': '😴', 'label': "Help me build a better sleep routine"},
    {'emoji': '🧠', 'label': "I need to talk through something"},
  ];
}

// ── Message Bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isUser = message.role == 'user';
    final primary = th.colorScheme.primary;
    final onPrimary = th.colorScheme.onPrimary;
    final card = th.cardColor;
    final onSurface = th.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const KloudyMark(size: 30),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? primary : card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: isUser ? onPrimary : onSurface,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── Typing Indicator ──────────────────────────────────────────────────────────

class _TypingBubble extends StatefulWidget {
  final Color cardColor;
  final Color onSurface;
  const _TypingBubble({required this.cardColor, required this.onSurface});

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _sineWave(double t, double delay) {
    return 0.3 + 0.7 * (0.5 + 0.5 * _sin((t + delay) * 2 * 3.14159));
  }

  double _sin(double x) {
    x = x % (2 * 3.14159);
    return x < 3.14159
        ? (x * (3.14159 - x) * 4) / (3.14159 * 3.14159)
        : -(_sin(x - 3.14159));
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final primary = th.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const KloudyMark(size: 28),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: widget.cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final opacity = _sineWave(_ctrl.value, i / 3).clamp(0.0, 1.0);
                  return Container(
                    margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: widget.onSurface.withValues(alpha: opacity),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input Bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final Color onSurface;
  final Color card;
  final Color primary;
  final Color onPrimary;
  final VoidCallback onSend;
  final ValueChanged<String> onSuggestion;

  const _InputBar({
    required this.controller,
    required this.focus,
    required this.onSurface,
    required this.card,
    required this.primary,
    required this.onPrimary,
    required this.onSend,
    required this.onSuggestion,
  });

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        color: card,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: onSurface.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: th.dividerColor),
                    ),
                    child: TextField(
                      controller: controller,
                      focusNode: focus,
                      maxLines: 4,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(
                        fontSize: 14,
                        color: onSurface,
                        height: 1.4,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ask Kloudy anything...',
                        hintStyle: TextStyle(
                          color: onSurface.withValues(alpha: 0.35),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onSend,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      color: onPrimary,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            CommonsSuggestions(onSelect: onSuggestion),
          ],
        ),
      ),
    );
  }
}

// ── Starter Row ───────────────────────────────────────────────────────────────

class _StarterRow extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const _StarterRow({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final onSurface = th.colorScheme.onSurface;
    final card = th.cardColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: th.dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: onSurface,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
