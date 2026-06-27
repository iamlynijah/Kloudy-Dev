import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/chat_message.dart';
import '../services/ai_service.dart';
import '../services/supabase_service.dart';

class KloudyConversationsScreen extends StatefulWidget {
  const KloudyConversationsScreen({super.key});

  @override
  State<KloudyConversationsScreen> createState() => _KloudyConversationsScreenState();
}

class _KloudyConversationsScreenState extends State<KloudyConversationsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  List<Map<String, dynamic>> _sessions = [];
  String? _activeSessionId;
  Map<String, dynamic> _userContext = {};
  bool _loadingContext = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final results = await Future.wait([
      SupabaseService.fetchChatSessions(),
      SupabaseService.buildAiContext(),
    ]);
    if (!mounted) return;
    final sessions = results[0] as List<Map<String, dynamic>>;
    final context = results[1] as Map<String, dynamic>;
    setState(() {
      _sessions = sessions;
      _userContext = context;
      _loadingContext = false;
      _activeSessionId = sessions.isNotEmpty ? sessions.first['id'] as String : null;
    });
  }

  void _newChat() {
    Navigator.pop(context);
    setState(() => _activeSessionId = null);
  }

  void _selectSession(String sessionId) {
    Navigator.pop(context);
    setState(() => _activeSessionId = sessionId);
  }

  void _onSessionCreated(String sessionId, String title) {
    setState(() {
      _activeSessionId = sessionId;
      _sessions.insert(0, {
        'id': sessionId,
        'title': title,
        'updated_at': DateTime.now().toIso8601String(),
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final onSurface = th.colorScheme.onSurface;
    final card = th.cardColor;
    final bg = th.scaffoldBackgroundColor;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bg,
      drawer: _buildDrawer(onSurface, card),
      appBar: AppBar(
        backgroundColor: card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.menu, color: onSurface),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          children: [
            SizedBox(
              width: 30, height: 30,
              child: Image.asset('assets/images/kloudy_mascot.png', fit: BoxFit.contain),
            ),
            const SizedBox(width: 10),
            Text('Kloudy', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: onSurface)),
          ],
        ),
        titleSpacing: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: onSurface),
            tooltip: 'New chat',
            onPressed: () => setState(() => _activeSessionId = null),
          ),
        ],
      ),
      body: _loadingContext
          ? Center(child: CircularProgressIndicator(color: onSurface))
          : _SessionChatPane(
              key: ValueKey(_activeSessionId ?? 'new'),
              sessionId: _activeSessionId,
              userContext: _userContext,
              onSessionCreated: _onSessionCreated,
            ),
    );
  }

  Widget _buildDrawer(Color onSurface, Color card) {
    return Drawer(
      backgroundColor: card,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: GestureDetector(
                onTap: _newChat,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary, size: 18),
                      const SizedBox(width: 8),
                      Text('New chat',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('Recent',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: onSurface.withValues(alpha: 0.45))),
            ),
            Expanded(
              child: _sessions.isEmpty
                  ? Center(
                      child: Text('No conversations yet',
                          style: TextStyle(
                              fontSize: 13,
                              color: onSurface.withValues(alpha: 0.4))))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      itemCount: _sessions.length,
                      itemBuilder: (context, i) {
                        final s = _sessions[i];
                        final id = s['id'] as String;
                        final title = (s['title'] as String?) ?? 'New chat';
                        final isActive = id == _activeSessionId;
                        return GestureDetector(
                          onTap: () => _selectSession(id),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? onSurface.withValues(alpha: 0.08)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: onSurface,
                                fontWeight: isActive
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Session Chat Pane ─────────────────────────────────────────────────────────

class _SessionChatPane extends StatefulWidget {
  final String? sessionId;
  final Map<String, dynamic> userContext;
  final void Function(String id, String title) onSessionCreated;

  const _SessionChatPane({
    super.key,
    required this.sessionId,
    required this.userContext,
    required this.onSessionCreated,
  });

  @override
  State<_SessionChatPane> createState() => _SessionChatPaneState();
}

class _SessionChatPaneState extends State<_SessionChatPane> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();

  bool _loading = true;
  bool _thinking = false;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _sessionId = widget.sessionId;
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
    if (_sessionId != null) {
      final history = await SupabaseService.fetchChatHistory(sessionId: _sessionId);
      if (!mounted) return;
      setState(() {
        _messages.addAll(history.map((j) => ChatMessage.fromJson(j)));
        _loading = false;
      });
      _scrollToBottom();
    } else {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (_sessionId == null) {
      final title = trimmed.length > 45 ? '${trimmed.substring(0, 45)}...' : trimmed;
      try {
        final id = await SupabaseService.createChatSession(title: title);
        _sessionId = id;
        widget.onSessionCreated(id, title);
      } catch (_) {}
    }

    final userMsg = ChatMessage(role: 'user', content: trimmed);
    setState(() {
      _messages.add(userMsg);
      _thinking = true;
    });
    _ctrl.clear();
    _scrollToBottom();

    await SupabaseService.saveChatMessage(
        sessionId: _sessionId, role: 'user', content: trimmed);

    try {
      final reply = await AiService.send(
        apiKey: kAnthropicApiKey,
        history: _messages.sublist(0, _messages.length - 1),
        message: trimmed,
        userContext: widget.userContext,
      );
      if (!mounted) return;
      final assistantMsg = ChatMessage(role: 'assistant', content: reply);
      setState(() {
        _messages.add(assistantMsg);
        _thinking = false;
      });
      await SupabaseService.saveChatMessage(
          sessionId: _sessionId, role: 'assistant', content: reply);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content:
              "I'm having a little trouble connecting right now. Give me a second and try again 💙",
        ));
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

    if (_loading) return Center(child: CircularProgressIndicator(color: onSurface));

    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty && !_thinking
              ? _buildEmptyState(onSurface)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: _messages.length + (_thinking ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (_thinking && i == _messages.length) {
                      return _TypingBubble(cardColor: card, onSurface: onSurface);
                    }
                    return _MessageBubble(
                        message: _messages[i], cardColor: card, onSurface: onSurface);
                  },
                ),
        ),
        _buildInputBar(onSurface, card),
      ],
    );
  }

  Widget _buildEmptyState(Color onSurface) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 80, height: 80,
              child: Image.asset('assets/images/kloudy_mascot.png', fit: BoxFit.contain),
            ),
            const SizedBox(height: 20),
            Text("Hey, I'm Kloudy.",
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: onSurface),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              "Ask me anything — food, sleep, money, how you're feeling. No judgment here.",
              style: TextStyle(
                  fontSize: 14, color: onSurface.withValues(alpha: 0.5), height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(Color onSurface, Color card) {
    return SafeArea(
      top: false,
      child: Container(
        color: card,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: onSurface.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(fontSize: 14, color: onSurface),
                  decoration: InputDecoration(
                    hintText: 'Ask Kloudy anything...',
                    hintStyle:
                        TextStyle(color: onSurface.withValues(alpha: 0.38), fontSize: 14),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  onSubmitted: (_) {
                    if (_ctrl.text.trim().isNotEmpty && !_thinking) _send(_ctrl.text);
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                if (_ctrl.text.trim().isNotEmpty && !_thinking) _send(_ctrl.text);
              },
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
                child: Icon(Icons.arrow_upward, color: Theme.of(context).colorScheme.onPrimary, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Message Bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final Color cardColor;
  final Color onSurface;

  const _MessageBubble(
      {required this.message, required this.cardColor, required this.onSurface});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/images/kloudy_logo.png',
                  fit: BoxFit.cover),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? Theme.of(context).colorScheme.primary : cardColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: onSurface.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.content,
                style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isUser ? Theme.of(context).colorScheme.onPrimary : onSurface),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── Typing Bubble ─────────────────────────────────────────────────────────────

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
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28, height: 28,
            decoration:
                BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            child:
                Image.asset('assets/images/kloudy_logo.png', fit: BoxFit.cover),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: widget.cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final opacity = _sineWave(_ctrl.value, i / 3).clamp(0.0, 1.0);
                  return Container(
                    margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                    width: 7, height: 7,
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
