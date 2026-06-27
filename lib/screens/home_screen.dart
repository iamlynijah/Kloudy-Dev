import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import '../services/ai_service.dart';
import '../services/plaid_service.dart';
import '../services/supabase_service.dart';
import 'kloudy_chat_screen.dart';

// Semantic colors — consistent across all themes
const Color kGreen = Color(0xFF4CD964);
const Color kBlue  = Color(0xFF5B8FD4);

class HomeScreen extends StatelessWidget {
  final String userName;
  final void Function(int) onNavigate;
  final ValueNotifier<bool>? activeNotifier;

  const HomeScreen({
    super.key,
    required this.userName,
    required this.onNavigate,
    this.activeNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _HomeTab(
        userName: userName,
        onNavigate: onNavigate,
        activeNotifier: activeNotifier,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HOME TAB
// ─────────────────────────────────────────────
class _HomeTab extends StatefulWidget {
  final String userName;
  final void Function(int) onNavigate;
  final ValueNotifier<bool>? activeNotifier;
  const _HomeTab({
    required this.userName,
    required this.onNavigate,
    this.activeNotifier,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _tasks = [];
  String? _selectedMood;
  bool _loading = true;
  bool _showMoodPicker = false;
  Map<String, dynamic>? _sleepData;
  String? _aiMessage;
  bool _aiMessageLoading = true;
  final TextEditingController _chatController = TextEditingController();
  final TextEditingController _newTaskController = TextEditingController();

  // Overview card data
  int _calorieGoal = 0;
  int _caloriesToday = 0;
  double _spendingBudget = 0;
  double _monthlyIncome = 0;
  double _actualSpent = 0;
  bool _plaidConnected = false;

  static const List<Map<String, String>> _moods = [
    {'label': 'Happy',       'emoji': '😊'},
    {'label': 'Excited',     'emoji': '🤩'},
    {'label': 'Celebrating', 'emoji': '🥳'},
    {'label': 'Okay',        'emoji': '😐'},
    {'label': 'Meh',         'emoji': '😑'},
    {'label': 'Thinking',    'emoji': '🤔'},
    {'label': 'Tired',       'emoji': '😴'},
    {'label': 'Worried',     'emoji': '😟'},
    {'label': 'Sad',         'emoji': '😢'},
    {'label': 'Angry',       'emoji': '😠'},
    // Mindset tab labels
    {'label': 'Low',         'emoji': '😔'},
    {'label': 'Good',        'emoji': '🙂'},
    {'label': 'Great',       'emoji': '😄'},
  ];

  List<Map<String, dynamic>> get _suggestions {
    final hour = DateTime.now().hour;
    final isWeekend = DateTime.now().weekday >= 6;
    final suggestions = <Map<String, dynamic>>[];

    if (hour >= 5 && hour < 12) {
      suggestions.add({'label': 'What should I have for breakfast?', 'emoji': '🍳', 'color': const Color(0xFFF5ECD6)});
      if (_profile?['lose_weight'] == true || _profile?['build_muscle'] == true)
        suggestions.add({'label': 'Best morning workout for today', 'emoji': '🏋️', 'color': const Color(0xFFE4EDDF)});
      if (_profile?['improve_sleep'] == true)
        suggestions.add({'label': 'How can I wake up more energized?', 'emoji': '☀️', 'color': const Color(0xFFF2EAE0)});
      suggestions.add({'label': 'Help me plan my day', 'emoji': '📋', 'color': const Color(0xFFDDE6EE)});
    } else if (hour >= 12 && hour < 17) {
      suggestions.add({'label': 'Quick healthy lunch ideas', 'emoji': '🥗', 'color': const Color(0xFFE4EDDF)});
      suggestions.add({'label': "I'm tired — how do I push through?", 'emoji': '⚡', 'color': const Color(0xFFF2EAE0)});
      if (_profile?['save_money'] == true)
        suggestions.add({'label': 'How am I doing on my budget this week?', 'emoji': '💰', 'color': const Color(0xFFE4EDDF)});
      suggestions.add({'label': 'Find deals near me', 'emoji': '🛒', 'color': const Color(0xFFDDE6EE)});
    } else if (hour >= 17 && hour < 22) {
      suggestions.add({'label': 'What should I cook for dinner?', 'emoji': '🍽️', 'color': const Color(0xFFF0E4E4)});
      if (_profile?['improve_sleep'] == true)
        suggestions.add({'label': 'Best wind-down routine for better sleep', 'emoji': '🌙', 'color': const Color(0xFFE3E1EE)});
      if (_profile?['save_money'] == true)
        suggestions.add({'label': 'Ways to save money this week', 'emoji': '💸', 'color': const Color(0xFFE4EDDF)});
      suggestions.add({'label': 'Review my day with me', 'emoji': '✨', 'color': const Color(0xFFEBE0EF)});
    } else {
      suggestions.add({'label': 'Help me wind down for sleep', 'emoji': '😴', 'color': const Color(0xFFE3E1EE)});
      suggestions.add({'label': 'Relaxation techniques that actually work', 'emoji': '🌙', 'color': const Color(0xFFDDE6EE)});
      suggestions.add({'label': 'Did I do well today?', 'emoji': '🌟', 'color': const Color(0xFFF2EAE0)});
    }

    if (_profile?['improve_mental_health'] == true)
      suggestions.add({'label': 'Find therapists near me', 'emoji': '🧑‍⚕️', 'color': const Color(0xFFEBE0EF)});
    if (isWeekend)
      suggestions.add({'label': 'Fun healthy things to do this weekend', 'emoji': '🌳', 'color': const Color(0xFFE0EAE2)});

    return suggestions.take(5).toList();
  }

  @override
  void initState() {
    super.initState();
    widget.activeNotifier?.addListener(_onActiveChanged);
    _load();
    _loadPlaidSpending();
  }

  @override
  void dispose() {
    widget.activeNotifier?.removeListener(_onActiveChanged);
    _chatController.dispose();
    _newTaskController.dispose();
    super.dispose();
  }

  void _onActiveChanged() {
    if (widget.activeNotifier?.value == true && mounted) {
      _load();
      _loadPlaidSpending();
    }
  }

  Future<void> _loadPlaidSpending() async {
    try {
      final result = await PlaidService.fetchTransactions();
      if (!mounted || !result.connected) return;
      final spent = result.transactions
          .where((t) => !t.isTransfer)
          .fold(0.0, (s, t) => s + t.amount);
      setState(() {
        _plaidConnected = true;
        _actualSpent = spent;
      });
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        SupabaseService.fetchProfile(),
        _fetchTasks(),
        SupabaseService.fetchSleepData(),
        SupabaseService.fetchNutritionData(),
        SupabaseService.fetchFinanceData(),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final tasks = results[1] as List<Map<String, dynamic>>;
      final sleepData = results[2] as Map<String, dynamic>?;
      final nutrition = results[3] as Map<String, dynamic>?;
      final finance = results[4] as Map<String, dynamic>?;

      // Calories
      final today = DateTime.now().toIso8601String().split('T').first;
      final foodLogs = nutrition?['food_logs'] as Map<String, dynamic>?;
      final todayEntries = foodLogs?[today] as List<dynamic>? ?? [];
      final calsToday = todayEntries.fold<int>(
          0, (s, e) => s + ((e as Map)['calories'] as num? ?? 0).toInt());
      final nutritionProfile = nutrition?['profile'] as Map<String, dynamic>?;
      final calorieGoal =
          (nutritionProfile?['calorie_goal'] as num?)?.toInt() ?? 0;

      // Spending budget
      final monthlyIncome =
          (finance?['monthly_income'] as num? ?? 0).toDouble();
      final bills = finance?['bills'] as List<dynamic>? ?? [];
      final extras = finance?['extras'] as List<dynamic>? ?? [];
      final goals = finance?['goals'] as List<dynamic>? ?? [];
      final totalBills = bills.fold<double>(
          0, (s, b) => s + ((b as Map)['monthly_amount'] as num? ?? 0).toDouble());
      final totalExtras = extras.fold<double>(
          0, (s, e) => s + ((e as Map)['estimated_monthly_amount'] as num? ?? 0).toDouble());
      final totalGoals = goals.fold<double>(0, (s, g) {
        final target = ((g as Map)['target_amount'] as num? ?? 0).toDouble();
        final current = (g['current_amount'] as num? ?? 0).toDouble();
        final months = (g['target_months'] as int?) ?? 1;
        return s + (target - current) / months;
      });
      final spendingBudget = monthlyIncome - totalBills - totalExtras - totalGoals;

      if (mounted) {
        setState(() {
          _profile = profile;
          _tasks = tasks;
          _selectedMood = profile?['current_mood'] as String?;
          _sleepData = sleepData;
          _calorieGoal = calorieGoal;
          _caloriesToday = calsToday;
          _spendingBudget = spendingBudget;
          _monthlyIncome = monthlyIncome;
          _loading = false;
        });
      }
      _fetchAiInsight();
    } catch (e) {
      debugPrint('[HomeTab] load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchAiInsight() async {
    try {
      final context = await SupabaseService.buildAiContext();
      final message = await AiService.generateInsight(
        apiKey: kAnthropicApiKey,
        userContext: context,
      );
      if (mounted) setState(() { _aiMessage = message; _aiMessageLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _aiMessageLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTasks() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return [];
    final today = DateTime.now().toIso8601String().split('T').first;
    final result = await SupabaseService.client
        .from('tasks')
        .select()
        .eq('user_id', uid)
        .eq('planned_for', today)
        .order('created_at');
    return List<Map<String, dynamic>>.from(result);
  }

  Future<void> _toggleTask(String id, bool current) async {
    await SupabaseService.client
        .from('tasks')
        .update({'completed': !current})
        .eq('id', id);
    setState(() {
      _tasks = _tasks.map((t) {
        if (t['id'] == id) return {...t, 'completed': !current};
        return t;
      }).toList();
    });
  }

  Future<void> _addTask(String title, {bool aiSuggested = false}) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null || title.trim().isEmpty) return;
    final today = DateTime.now().toIso8601String().split('T').first;
    final result = await SupabaseService.client
        .from('tasks')
        .insert({
          'user_id': uid,
          'title': title.trim(),
          'is_ai_suggested': aiSuggested,
          'planned_for': today,
        })
        .select()
        .single();
    setState(() => _tasks.add(Map<String, dynamic>.from(result)));
  }

  static int _moodToMindsetScale(String mood) {
    switch (mood) {
      case 'Great':
      case 'Happy':
      case 'Excited':
      case 'Celebrating':
        return 5;
      case 'Good':
        return 4;
      case 'Okay':
      case 'Thinking':
        return 3;
      case 'Meh':
      case 'Tired':
      case 'Worried':
        return 2;
      default:
        return 1; // Low, Sad, Angry
    }
  }

  Future<void> _syncMoodToMindset(int scale) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final existing = await SupabaseService.fetchMindsetData() ?? {};
    final rawLog = (existing['mood_log'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final todayEntry =
        rawLog.where((e) => e['date'] == today).firstOrNull;
    final energy = (todayEntry?['energy'] as int?) ?? 3;
    rawLog.removeWhere((e) => e['date'] == today);
    rawLog.add({'date': today, 'mood': scale, 'energy': energy});
    await SupabaseService.saveMindsetData({
      ...existing,
      'mood_log': rawLog,
    });
  }

  Future<void> _selectMood(String mood) async {
    setState(() {
      _selectedMood = mood;
      _showMoodPicker = false;
    });
    final scale = _moodToMindsetScale(mood);
    await Future.wait([
      SupabaseService.saveMood(mood),
      _syncMoodToMindset(scale),
    ]);
  }

  String _aiInsight() {
    if (_profile == null) return 'Setting up your personalized plan...';
    final name = widget.userName.split(' ').first;
    if (_profile!['lose_weight'] == true) return 'You\'re on track with your weight goal, $name. Keep it up! 💪';
    if (_profile!['save_money'] == true) return 'You\'re building great savings habits this week, $name! 💰';
    if (_profile!['improve_mental_health'] == true) return 'You\'ve been consistent with your mental health goals, $name 🧠';
    if (_profile!['improve_sleep'] == true) return 'Better sleep starts tonight — you\'ve got this, $name 🌙';
    return 'Your plan is ready, $name. Let\'s make today count! ✨';
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  Widget _greetingEmoji() {
    final h = DateTime.now().hour;
    if (h < 12) return const Text('☀️', style: TextStyle(fontSize: 26));
    if (h < 17) return const Text('🌤️', style: TextStyle(fontSize: 26));
    return const Text('🌙', style: TextStyle(fontSize: 26));
  }

  int get _completedTasks => _tasks.where((t) => t['completed'] == true).length;

  void _openMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _KloudyMenuSheet(
        displayName: widget.userName,
        profile: _profile,
      ),
    );
  }

  List<_AppNotification> get _notifications => buildAppNotifications(
    profile: _profile,
    tasks: _tasks,
    sleepData: _sleepData,
    selectedMood: _selectedMood,
  );

  void _openChat(String prefill) {
    final text = prefill.trim();
    _chatController.clear();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KloudyChatScreen(initialMessage: text.isEmpty ? null : text),
      ),
    );
  }

  void _openNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotificationsSheet(notifications: _notifications),
    );
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final card = th.cardColor;
    final onSurface = th.colorScheme.onSurface;
    final primary = th.colorScheme.primary;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: primary));
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        color: primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Top bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _openMenu,
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: card,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06), blurRadius: 8)],
                        ),
                        child: Icon(Icons.menu, size: 20, color: onSurface),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Kloudy',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: onSurface,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _openNotifications,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: card,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: onSurface.withOpacity(0.06), blurRadius: 8)],
                            ),
                            child: Icon(Icons.notifications_outlined, size: 20, color: onSurface),
                          ),
                          if (_notifications.isNotEmpty)
                            Positioned(
                              top: -2, right: -2,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: Text(
                                  '${_notifications.length}',
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Greeting + mascot ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting(),
                            style: TextStyle(fontSize: 20, color: onSurface.withOpacity(0.54)),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                widget.userName.split(' ').first,
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                  color: onSurface,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _greetingEmoji(),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: card,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05), blurRadius: 10)],
                            ),
                            child: Row(
                              children: [
                                const Text('✨', style: TextStyle(fontSize: 14)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _aiMessageLoading
                                      ? Row(children: [
                                          SizedBox(
                                            width: 12, height: 12,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.5,
                                              color: onSurface.withOpacity(0.3),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text('Checking in...', style: TextStyle(fontSize: 13, color: onSurface.withOpacity(0.4))),
                                        ])
                                      : Text(
                                          _aiMessage ?? _aiInsight(),
                                          style: TextStyle(fontSize: 13, height: 1.4, color: onSurface),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 140, height: 170,
                      child: Image.asset('assets/images/kloudy_mascot.png', fit: BoxFit.contain),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Kloudy's Overview ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05), blurRadius: 12)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('✨', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(
                            "Kloudy's Overview",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: onSurface),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: _OverviewCard(
                            icon: '🍽️',
                            iconBg: const Color(0xFFF5E8C8),
                            value: _calorieGoal > 0
                                ? '${(_calorieGoal - _caloriesToday).clamp(0, _calorieGoal)}'
                                : '—',
                            label: 'calories left',
                            progress: _calorieGoal > 0
                                ? ((_calorieGoal - _caloriesToday) / _calorieGoal).clamp(0.0, 1.0)
                                : null,
                            progressColor: kGreen,
                            onTap: () => widget.onNavigate(2),
                          )),
                          const SizedBox(width: 10),
                          Expanded(child: _OverviewCard(
                            icon: '💳',
                            iconBg: const Color(0xFFDDE6EE),
                            value: _monthlyIncome > 0
                                ? '\$${(_spendingBudget - (_plaidConnected ? _actualSpent : 0)).toStringAsFixed(0)}'
                                : '—',
                            label: 'left to spend',
                            progress: _monthlyIncome > 0
                                ? ((_spendingBudget - (_plaidConnected ? _actualSpent : 0)) / _monthlyIncome).clamp(0.0, 1.0)
                                : null,
                            progressColor: kBlue,
                            onTap: () => widget.onNavigate(3),
                          )),
                          const SizedBox(width: 10),
                          Expanded(child: _OverviewCard(
                            icon: _moods.firstWhere(
                              (m) => m['label'] == _selectedMood,
                              orElse: () => {'emoji': '🫧'},
                            )['emoji']!,
                            iconBg: const Color(0xFFEBE0EF),
                            value: _selectedMood ?? 'Set mood',
                            label: 'current mood',
                            progress: null,
                            onTap: () => setState(() => _showMoodPicker = !_showMoodPicker),
                          )),
                        ],
                      ),

                      if (_showMoodPicker) ...[
                        const SizedBox(height: 14),
                        Divider(color: onSurface.withOpacity(0.1), height: 1),
                        const SizedBox(height: 12),
                        Text(
                          'How are you feeling?',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onSurface.withOpacity(0.54)),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _moods.map((mood) {
                            final selected = _selectedMood == mood['label'];
                            return GestureDetector(
                              onTap: () => _selectMood(mood['label']!),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 52, height: 52,
                                decoration: BoxDecoration(
                                  color: selected ? primary : onSurface.withOpacity(0.06),
                                  shape: BoxShape.circle,
                                  border: selected ? Border.all(color: primary, width: 2) : null,
                                ),
                                child: Center(
                                  child: Text(
                                    mood['emoji']!,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Sleep Streak ──
              _SleepStreakCard(sleepData: _sleepData, onLog: _showSleepLogSheet),

              const SizedBox(height: 20),

              // ── Ask Kloudy ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05), blurRadius: 12)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Ask Kloudy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: onSurface)),
                          const SizedBox(width: 6),
                          const Text('✨', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: onSurface.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 14),
                              child: Icon(Icons.search, color: onSurface.withOpacity(0.38), size: 20),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _chatController,
                                style: TextStyle(color: onSurface),
                                textInputAction: TextInputAction.send,
                                decoration: InputDecoration(
                                  hintText: 'Ask anything...',
                                  hintStyle: TextStyle(color: onSurface.withOpacity(0.38), fontSize: 14),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                                ),
                                onSubmitted: (text) => _openChat(text),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _openChat(_chatController.text),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                                  child: Icon(Icons.arrow_upward, color: th.colorScheme.onPrimary, size: 16),
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

              const SizedBox(height: 20),

              // ── Suggestions ──
              Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 10),
                child: Text(
                  'Suggestions for you',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: onSurface),
                ),
              ),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 20, right: 8),
                  itemCount: _suggestions.length,
                  itemBuilder: (context, i) {
                    final s = _suggestions[i];
                    final label = s['label'] as String;
                    return GestureDetector(
                      onTap: () => _openChat(label),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: s['color'] as Color,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(s['emoji'] as String, style: const TextStyle(fontSize: 20)),
                            const SizedBox(height: 4),
                            Text(
                              label,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.87)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // ── Today's Plan ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05), blurRadius: 12)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('📋', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(
                            "Today's Plan",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: onSurface),
                          ),
                          const Spacer(),
                          if (_tasks.isNotEmpty)
                            Text(
                              '$_completedTasks/${_tasks.length}',
                              style: TextStyle(fontSize: 13, color: onSurface.withOpacity(0.38)),
                            ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: _showAddTaskSheet,
                            child: const Text(
                              'Edit',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlue),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      if (_tasks.isEmpty)
                        _EmptyTasks(onAdd: _showAddTaskSheet)
                      else
                        ..._tasks.map((task) => _TaskRow(
                          task: task,
                          onToggle: () => _toggleTask(task['id'], task['completed'] == true),
                        )),

                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _showAddTaskSheet,
                        child: Row(
                          children: [
                            Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                border: Border.all(color: onSurface.withOpacity(0.26)),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.add, size: 14, color: onSurface.withOpacity(0.38)),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Add a task',
                              style: TextStyle(fontSize: 14, color: onSurface.withOpacity(0.38)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showSleepLogSheet() {
    var selectedHours = 8;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final th = Theme.of(ctx);
        final onSurface = th.colorScheme.onSurface;
        return StatefulBuilder(
          builder: (ctx, setModalState) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'How many hours did you sleep?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: onSurface),
                ),
                const SizedBox(height: 6),
                Text('Last night', style: TextStyle(fontSize: 13, color: onSurface.withOpacity(0.45))),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => setModalState(() { if (selectedHours > 3) selectedHours--; }),
                      child: Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: onSurface.withOpacity(0.07),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.remove, size: 22, color: onSurface),
                      ),
                    ),
                    const SizedBox(width: 32),
                    Column(
                      children: [
                        Text(
                          '$selectedHours',
                          style: TextStyle(fontSize: 56, fontWeight: FontWeight.w800, height: 1, color: onSurface),
                        ),
                        Text('hours', style: TextStyle(fontSize: 14, color: onSurface.withOpacity(0.45))),
                      ],
                    ),
                    const SizedBox(width: 32),
                    GestureDetector(
                      onTap: () => setModalState(() { if (selectedHours < 14) selectedHours++; }),
                      child: Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: onSurface.withOpacity(0.07),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.add, size: 22, color: onSurface),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  selectedHours >= 7 ? '🔥 Counts toward streak!' : 'Need 7+ hours to count toward streak',
                  style: TextStyle(
                    fontSize: 13,
                    color: selectedHours >= 7 ? kGreen : onSurface.withOpacity(0.38),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () async {
                      final hrs = selectedHours;
                      Navigator.pop(ctx);
                      await SupabaseService.saveSleepLog(hrs.toDouble());
                      final sleepData = await SupabaseService.fetchSleepData();
                      if (mounted) setState(() => _sleepData = sleepData);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: th.colorScheme.primary,
                      foregroundColor: th.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddTaskSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final th = Theme.of(ctx);
        final onSurface = th.colorScheme.onSurface;
        return Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add a task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: onSurface)),
              const SizedBox(height: 16),
              TextField(
                controller: _newTaskController,
                autofocus: true,
                style: TextStyle(color: onSurface),
                decoration: InputDecoration(
                  hintText: 'e.g. Drink 8 glasses of water',
                  hintStyle: TextStyle(color: onSurface.withOpacity(0.38)),
                  filled: true,
                  fillColor: onSurface.withOpacity(0.07),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    final text = _newTaskController.text;
                    _newTaskController.clear();
                    Navigator.pop(ctx);
                    await _addTask(text);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: th.colorScheme.primary,
                    foregroundColor: th.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Add', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// OVERVIEW CARD
// ─────────────────────────────────────────────
class _OverviewCard extends StatelessWidget {
  final String icon;
  final Color iconBg;
  final String value;
  final String label;
  final double? progress;
  final Color? progressColor;
  final VoidCallback onTap;

  const _OverviewCard({
    required this.icon,
    required this.iconBg,
    required this.value,
    required this.label,
    required this.progress,
    required this.onTap,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: onSurface.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Center(child: Text(icon, style: const TextStyle(fontSize: 17))),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: onSurface.withOpacity(0.45))),
            if (progress != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: onSurface.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor ?? onSurface),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TASK ROW
// ─────────────────────────────────────────────
class _TaskRow extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onToggle;

  const _TaskRow({required this.task, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final done = task['completed'] == true;
    final aiSuggested = task['is_ai_suggested'] == true;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: done ? kGreen : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: done ? kGreen : onSurface.withOpacity(0.26),
                  width: 1.5,
                ),
              ),
              child: done ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['title'] as String,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done ? onSurface.withOpacity(0.38) : onSurface,
                  ),
                ),
                if (aiSuggested)
                  Text('Suggested by Kloudy', style: TextStyle(fontSize: 11, color: onSurface.withOpacity(0.38))),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: onSurface.withOpacity(0.26), size: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SLEEP STREAK CARD
// ─────────────────────────────────────────────
class _SleepStreakCard extends StatelessWidget {
  final Map<String, dynamic>? sleepData;
  final VoidCallback onLog;

  const _SleepStreakCard({required this.sleepData, required this.onLog});

  static const _dayAbbrevs = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int get _streak => (sleepData?['streak'] as int?) ?? 0;

  bool get _loggedToday {
    final logs = sleepData?['logs'] as List?;
    if (logs == null || logs.isEmpty) return false;
    return ((logs.first as Map)['date'] as String?) == _fmt(DateTime.now());
  }

  double? get _todayHours {
    if (!_loggedToday) return null;
    return ((sleepData!['logs'] as List).first as Map)['hours'] is num
        ? (((sleepData!['logs'] as List).first as Map)['hours'] as num).toDouble()
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final onSurface = th.colorScheme.onSurface;
    final streak = _streak;
    final logged = _loggedToday;

    // Build last 7 days (oldest → newest, index 6 = today)
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));

    // date → hours lookup
    final logMap = <String, double>{};
    for (final log in (sleepData?['logs'] as List? ?? [])) {
      final m = log as Map;
      logMap[m['date'] as String] = (m['hours'] as num).toDouble();
    }

    // Most recent logged day index (for streak badge placement)
    int? recentIdx;
    for (int i = 6; i >= 0; i--) {
      if (logMap.containsKey(_fmt(days[i]))) {
        recentIdx = i;
        break;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: th.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: onSurface.withValues(alpha: 0.05), blurRadius: 12)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Text('💤', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text('Sleep',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: onSurface)),
                const Spacer(),
                if (streak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text('$streak day streak',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // 7-day columns
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final day = days[i];
                final dateStr = _fmt(day);
                final hours = logMap[dateStr];
                final isToday = i == 6;
                final showStreak = i == recentIdx && streak > 0;
                return _SleepDayColumn(
                  dayLabel: _dayAbbrevs[day.weekday % 7],
                  hours: hours,
                  isToday: isToday,
                  streakCount: showStreak ? streak : null,
                );
              }),
            ),

            const SizedBox(height: 14),

            // Log button
            GestureDetector(
              onTap: onLog,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: logged
                      ? const Color(0xFFE4EDDF)
                      : th.colorScheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: logged
                      ? [
                          const Icon(Icons.check_circle,
                              color: kGreen, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '${_todayHours != null ? (_todayHours! % 1 == 0 ? _todayHours!.toInt().toString() : _todayHours!.toStringAsFixed(1)) : '?'} hrs logged',
                            style: const TextStyle(
                                color: kGreen,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                        ]
                      : [
                          Text(
                            'Log last night',
                            style: TextStyle(
                                color: th.colorScheme.onPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SLEEP DAY COLUMN
// ─────────────────────────────────────────────
class _SleepDayColumn extends StatelessWidget {
  final String dayLabel;
  final double? hours;
  final bool isToday;
  final int? streakCount;

  const _SleepDayColumn({
    required this.dayLabel,
    required this.hours,
    required this.isToday,
    this.streakCount,
  });

  Color _circleColor(double h) {
    if (h >= 7) return const Color(0xFFDCEED4);   // green — good
    if (h >= 6) return const Color(0xFFFFF9C4);   // yellow — ok
    return const Color(0xFFFFE0D0);               // orange — short
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final primary = Theme.of(context).colorScheme.primary;
    final hasLog = hours != null;
    final hrsText = hasLog
        ? (hours! % 1 == 0
            ? '${hours!.toInt()}h'
            : '${hours!.toStringAsFixed(1)}h')
        : null;

    return Column(
      children: [
        // Day label
        Text(
          dayLabel,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
            color: isToday ? primary : onSurface.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 6),

        // Hours circle
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: hasLog
                ? _circleColor(hours!)
                : onSurface.withValues(alpha: 0.06),
            shape: BoxShape.circle,
            border: isToday && !hasLog
                ? Border.all(
                    color: primary.withValues(alpha: 0.4), width: 1.5)
                : null,
          ),
          child: Center(
            child: hasLog
                ? Text(hrsText!,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: onSurface))
                : Text('—',
                    style: TextStyle(
                        fontSize: 12,
                        color: onSurface.withValues(alpha: 0.22))),
          ),
        ),

        // Streak badge (fixed height so all columns are same size)
        SizedBox(
          height: 30,
          child: streakCount != null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 11)),
                    Text('$streakCount',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ],
                )
              : null,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// EMPTY TASKS STATE
// ─────────────────────────────────────────────
class _EmptyTasks extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyTasks({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text('No tasks yet today', style: TextStyle(color: onSurface.withOpacity(0.38), fontSize: 14)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onAdd,
            child: const Text(
              'Add your first task',
              style: TextStyle(color: kBlue, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// KLOUDY MENU SHEET
// ─────────────────────────────────────────────
class _KloudyMenuSheet extends StatefulWidget {
  final String displayName;
  final Map<String, dynamic>? profile;

  const _KloudyMenuSheet({required this.displayName, required this.profile});

  @override
  State<_KloudyMenuSheet> createState() => _KloudyMenuSheetState();
}

class _KloudyMenuSheetState extends State<_KloudyMenuSheet> {
  bool _editingUsername = false;
  late final TextEditingController _usernameCtrl;
  bool _savingUsername = false;
  String? _avatarBase64;
  bool _savingAvatar = false;

  @override
  void initState() {
    super.initState();
    final answers = widget.profile?['answers'] as Map?;
    final profileSection = answers?['profile'] as Map?;
    _usernameCtrl = TextEditingController(
      text: profileSection?['username'] as String? ?? '',
    );
    _avatarBase64 = profileSection?['avatar_base64'] as String?;
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 200,
      maxHeight: 200,
      imageQuality: 75,
    );
    if (file == null || !mounted) return;

    setState(() => _savingAvatar = true);
    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);
    await SupabaseService.saveAvatarBase64(b64);
    if (mounted) setState(() { _avatarBase64 = b64; _savingAvatar = false; });
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[1].isNotEmpty) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final card = th.cardColor;
    final onSurface = th.colorScheme.onSurface;
    final isDark = th.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: onSurface.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfile(th, onSurface, isDark),
                    const SizedBox(height: 24),
                    Divider(color: onSurface.withOpacity(0.1), height: 1),
                    const SizedBox(height: 24),
                    _buildSettings(context, onSurface),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfile(ThemeData th, Color onSurface, bool isDark) {
    final primary = th.colorScheme.primary;
    final email = SupabaseService.currentUser?.email;

    return Row(
      children: [
        GestureDetector(
          onTap: _pickPhoto,
          child: Stack(
            children: [
              Container(
                width: 58, height: 58,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.1) : primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.2) : primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: _savingAvatar
                      ? Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: primary)))
                      : _avatarBase64 != null
                          ? Image.memory(base64Decode(_avatarBase64!), fit: BoxFit.cover, width: 58, height: 58)
                          : Center(
                              child: Text(
                                _initials(widget.displayName),
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? Colors.white : primary),
                              ),
                            ),
                ),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: th.cardColor, width: 1.5),
                  ),
                  child: Icon(Icons.camera_alt, size: 11, color: th.colorScheme.onPrimary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.displayName, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: onSurface)),
              const SizedBox(height: 3),
              if (!_editingUsername)
                GestureDetector(
                  onTap: () => setState(() => _editingUsername = true),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _usernameCtrl.text.isNotEmpty ? '@${_usernameCtrl.text}' : 'Add a username',
                        style: TextStyle(
                          fontSize: 13,
                          color: _usernameCtrl.text.isNotEmpty ? primary : onSurface.withOpacity(0.4),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_outlined, size: 12, color: onSurface.withOpacity(0.3)),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _usernameCtrl,
                        autofocus: true,
                        style: TextStyle(fontSize: 13, color: onSurface),
                        decoration: InputDecoration(
                          hintText: 'username',
                          hintStyle: TextStyle(color: onSurface.withOpacity(0.35), fontSize: 13),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: onSurface.withOpacity(0.07),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _savingUsername
                          ? null
                          : () async {
                              setState(() => _savingUsername = true);
                              await SupabaseService.saveUsername(_usernameCtrl.text.trim());
                              if (mounted) setState(() { _editingUsername = false; _savingUsername = false; });
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: th.colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _savingUsername
                            ? SizedBox(
                                width: 12, height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2, color: th.colorScheme.onPrimary),
                              )
                            : Text(
                                'Save',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: th.colorScheme.onPrimary),
                              ),
                      ),
                    ),
                  ],
                ),
              if (email != null && !_editingUsername) ...[
                const SizedBox(height: 2),
                Text(email, style: TextStyle(fontSize: 11, color: onSurface.withOpacity(0.35))),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettings(BuildContext context, Color onSurface) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.settings_outlined, size: 15, color: onSurface.withOpacity(0.5)),
            const SizedBox(width: 7),
            Text(
              'SETTINGS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: onSurface.withOpacity(0.5), letterSpacing: 0.8),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SettingsRow(
          icon: Icons.logout,
          label: 'Log out',
          onTap: () async {
            Navigator.pop(context);
            await SupabaseService.signOut();
          },
        ),
        const SizedBox(height: 8),
        _SettingsRow(
          icon: Icons.delete_outline,
          label: 'Delete account',
          destructive: true,
          onTap: () => _confirmDelete(context),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context) {
    final th = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: th.cardColor,
        title: Text('Delete account?', style: TextStyle(color: th.colorScheme.onSurface)),
        content: Text(
          'This will permanently delete your profile and all your data. This cannot be undone.',
          style: TextStyle(color: th.colorScheme.onSurface.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: th.colorScheme.onSurface)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              Navigator.pop(context);
              await SupabaseService.deleteAccount();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SETTINGS ROW
// ─────────────────────────────────────────────
class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final color = destructive ? Colors.red : onSurface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: destructive ? Colors.red.withOpacity(0.08) : onSurface.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: color)),
            const Spacer(),
            Icon(Icons.chevron_right, size: 16, color: color.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// NOTIFICATIONS
// ─────────────────────────────────────────────

class _AppNotification {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String category;
  const _AppNotification({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.category,
  });
}

List<_AppNotification> buildAppNotifications({
  Map<String, dynamic>? profile,
  List<Map<String, dynamic>> tasks = const [],
  Map<String, dynamic>? sleepData,
  String? selectedMood,
}) {
  final notes = <_AppNotification>[];
  final today = DateTime.now().toIso8601String().split('T').first;

  // ── Sleep ──────────────────────────────────────────────────────────
  final logs = (sleepData?['logs'] as List<dynamic>? ?? []);
  final loggedToday = logs.any((l) => (l as Map)['date'] == today);
  final streak = sleepData?['streak'] as int? ?? 0;

  if (profile?['improve_sleep'] == true || sleepData != null) {
    if (!loggedToday) {
      notes.add(const _AppNotification(
        icon: Icons.bedtime_outlined,
        color: Color(0xFF5B8FD4),
        title: 'Log last night\'s sleep',
        body: 'Keep your streak alive — how many hours did you get?',
        category: 'Sleep',
      ));
    }
    if (streak > 0 && streak % 7 == 0) {
      notes.add(_AppNotification(
        icon: Icons.local_fire_department_outlined,
        color: const Color(0xFFFF9800),
        title: '$streak-day sleep streak 🔥',
        body: 'You\'ve hit $streak days in a row. Your body thanks you.',
        category: 'Milestone',
      ));
    }
  }

  // ── Tasks ──────────────────────────────────────────────────────────
  final incomplete = tasks.where((t) => t['completed'] != true).length;
  if (tasks.isNotEmpty && incomplete > 0) {
    notes.add(_AppNotification(
      icon: Icons.check_circle_outline,
      color: const Color(0xFF4CAF50),
      title: '$incomplete task${incomplete == 1 ? '' : 's'} left today',
      body: incomplete == 1
          ? 'One more to go — you\'ve almost finished your day!'
          : 'Knock out $incomplete more tasks to complete your day.',
      category: 'Tasks',
    ));
  }

  // ── Mood ──────────────────────────────────────────────────────────
  if (selectedMood == null) {
    notes.add(const _AppNotification(
      icon: Icons.mood_outlined,
      color: Color(0xFFFFB300),
      title: 'How are you feeling today?',
      body: 'Log your mood so Kloudy can personalize your day.',
      category: 'Wellness',
    ));
  }

  // ── Nutrition nudge ────────────────────────────────────────────────
  if (profile?['lose_weight'] == true ||
      profile?['improve_nutrition'] == true ||
      profile?['build_muscle'] == true) {
    notes.add(const _AppNotification(
      icon: Icons.restaurant_menu_outlined,
      color: Color(0xFFFF7043),
      title: 'Log your meals',
      body: 'Track what you eat today to stay on top of your nutrition goals.',
      category: 'Nutrition',
    ));
  }

  // ── Finance nudge ──────────────────────────────────────────────────
  if (profile?['save_money'] == true || profile?['build_wealth'] == true) {
    notes.add(const _AppNotification(
      icon: Icons.attach_money,
      color: Color(0xFF66BB6A),
      title: 'Review your spending',
      body: 'Check in on your budget to stay on track this week.',
      category: 'Finance',
    ));
  }

  // ── Health checkups ────────────────────────────────────────────────
  final answers = profile?['answers'] as Map?;
  final healthAnswers = answers?['health'] as Map?;
  final checkups = healthAnswers?['checkups'] as Map?;
  if (checkups != null) {
    final overdue = <String>[];
    void check(String key, String label, List<String> overdueVals) {
      if (overdueVals.contains(checkups[key])) overdue.add(label);
    }
    check('primary_care', 'primary care', ['2plus_yr']);
    check('dental', 'dental', ['1_2yr', '2plus_yr']);
    check('obgyn', 'OBGYN', ['2plus_yr']);
    if (overdue.isNotEmpty) {
      notes.add(_AppNotification(
        icon: Icons.calendar_today_outlined,
        color: const Color(0xFFE57373),
        title: 'Checkup reminder',
        body: 'Your ${overdue.join(' & ')} checkup may be overdue. Worth scheduling!',
        category: 'Health',
      ));
    }
  }

  // ── Medications ────────────────────────────────────────────────────
  final meds = healthAnswers?['medications'] as List?;
  if (meds != null && meds.isNotEmpty) {
    final medNames = meds
        .map((m) => (m as Map)['name'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .take(2)
        .join(' & ');
    if (medNames.isNotEmpty) {
      notes.add(_AppNotification(
        icon: Icons.medication_outlined,
        color: const Color(0xFF9C27B0),
        title: 'Medication reminder',
        body: 'Don\'t forget: $medNames',
        category: 'Health',
      ));
    }
  }

  return notes;
}

class _NotificationsSheet extends StatelessWidget {
  final List<_AppNotification> notifications;
  const _NotificationsSheet({required this.notifications});

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final card = th.cardColor;
    final onSurface = th.colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: onSurface.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
              child: Row(
                children: [
                  Text('Notifications',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: onSurface)),
                  const Spacer(),
                  if (notifications.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: onSurface.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${notifications.length}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: onSurface)),
                    ),
                ],
              ),
            ),
            if (notifications.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 44, color: onSurface.withOpacity(0.18)),
                    const SizedBox(height: 12),
                    Text('You\'re all caught up!',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                            color: onSurface.withOpacity(0.35))),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.62),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _NotificationRow(n: notifications[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final _AppNotification n;
  const _NotificationRow({required this.n});

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final onSurface = th.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: th.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: n.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(n.icon, size: 20, color: n.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(n.title,
                          style: TextStyle(fontSize: 14,
                              fontWeight: FontWeight.w600, color: onSurface)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: n.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(n.category,
                          style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w600, color: n.color)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(n.body,
                    style: TextStyle(fontSize: 12,
                        color: onSurface.withOpacity(0.5), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
