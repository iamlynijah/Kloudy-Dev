import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/ai_service.dart';
import '../models/self_care_task.dart';
import '../config/api_config.dart';
import '../theme/kloudy_theme.dart' show kGold, kGoldLight, kInk, kDimText, kBorder, kCard, kSurface;
import 'mindset_unlock_screen.dart';
import 'tab_gate_screen.dart';

// ── Inline mood model (no separate file needed) ────────────────────────────

class _MoodEntry {
  final String date;
  final int mood;
  final int energy;

  _MoodEntry({required this.date, required this.mood, required this.energy});

  Map<String, dynamic> toJson() =>
      {'date': date, 'mood': mood, 'energy': energy};

  factory _MoodEntry.fromJson(Map<String, dynamic> j) => _MoodEntry(
        date: j['date'] as String,
        mood: j['mood'] as int,
        energy: j['energy'] as int,
      );
}

// ── Fun self-care activities ───────────────────────────────────────────────

class _Activity {
  final IconData icon;
  final String title;
  final Color color;

  const _Activity(this.icon, this.title, this.color);
}

const _activities = [
  _Activity(Icons.directions_walk_outlined, 'Walk outside', Color(0xFFDCEED4)),
  _Activity(Icons.phone_outlined, 'Call someone you love', Color(0xFFD4E8EE)),
  _Activity(Icons.spa_outlined, 'Stretch 10 min', Color(0xFFEDD8F0)),
  _Activity(Icons.music_note_outlined, 'Put on a playlist', Color(0xFFF0E8C8)),
  _Activity(Icons.face_retouching_natural, 'Do your skincare', Color(0xFFF0D8D4)),
  _Activity(Icons.local_cafe_outlined, 'Make yourself tea', Color(0xFFEEE4CC)),
  _Activity(Icons.edit_note_outlined, 'Write it down', Color(0xFFD8E4F4)),
  _Activity(Icons.shower_outlined, 'Take a long shower', Color(0xFFD4EEE8)),
  _Activity(Icons.back_hand_outlined, 'Do your nails', Color(0xFFF4D4E8)),
  _Activity(Icons.book_outlined, 'Read 20 min', Color(0xFFD8E8D4)),
  _Activity(Icons.cleaning_services_outlined, 'Tidy one space', Color(0xFFEAE4D4)),
  _Activity(Icons.tv_outlined, 'Watch a comfort show', Color(0xFFD4D8F0)),
  _Activity(Icons.water_drop_outlined, 'Drink extra water', Color(0xFFCCE8F4)),
  _Activity(Icons.self_improvement_outlined, 'Meditate', Color(0xFFEED8F0)),
  _Activity(Icons.bedtime_outlined, 'Early night tonight', Color(0xFFD4D0F0)),
];

// ── Screen ─────────────────────────────────────────────────────────────────

class MentalWellnessScreen extends StatefulWidget {
  final ValueNotifier<bool>? activeNotifier;
  const MentalWellnessScreen({super.key, this.activeNotifier});

  @override
  State<MentalWellnessScreen> createState() => _MentalWellnessScreenState();
}

class _MentalWellnessScreenState extends State<MentalWellnessScreen> {
  bool _isLoading = true;
  bool? _isUnlocked;

  List<_MoodEntry> _moodLog = [];
  int? _todayMood;
  int? _todayEnergy;
  int? _pendingMood;

  String? _reflectionPrompt;
  bool _reflectionLoading = false;
  bool _reflectionSubmitting = false;
  String? _reflectionReply;
  final _reflectionController = TextEditingController();
  bool _reflectionExpanded = false;

  List<SelfCareTask> _selfCareTasks = [];
  List<String> _mindsetChallenges = [];
  Set<String> _completedActivitiesToday = {};
  Map<String, int> _activityStreaks = {};

  // Seed that changes daily — used to rotate activities each day
  int get _daySeed {
    final n = DateTime.now();
    return n.year * 400 + n.month * 31 + n.day;
  }

  List<_Activity> get _todaysActivities {
    final seed = _daySeed;
    final list = List<_Activity>.from(_activities);
    for (int i = list.length - 1; i > 0; i--) {
      final j = (seed + i * 1327) % (i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
    return list.take(8).toList();
  }

  Map<String, int> _computeStreaks(List<Map<String, dynamic>> log) {
    final streaks = <String, int>{};
    for (final a in _activities) {
      int streak = 0;
      while (streak < 365) {
        final ds = DateTime.now().subtract(Duration(days: streak));
        final dateStr =
            '${ds.year}-${ds.month.toString().padLeft(2, '0')}-${ds.day.toString().padLeft(2, '0')}';
        final entry = log.where((e) => e['date'] == dateStr).firstOrNull;
        final done = (entry?['completed'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toSet();
        if (done.contains(a.title)) {
          streak++;
        } else {
          break;
        }
      }
      if (streak > 0) streaks[a.title] = streak;
    }
    return streaks;
  }

  Future<void> _toggleActivity(String title) async {
    setState(() {
      if (_completedActivitiesToday.contains(title)) {
        _completedActivitiesToday.remove(title);
      } else {
        _completedActivitiesToday.add(title);
      }
    });
    await _saveMindset();
    // Recompute streaks after save
    final data = await SupabaseService.fetchMindsetData() ?? {};
    final log = (data['activity_log'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    if (mounted) setState(() => _activityStreaks = _computeStreaks(log));
  }

  String get _today {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  static const _moodEmojis = ['😔', '😕', '😐', '🙂', '😄'];
  static const _moodLabels = ['Low', 'Meh', 'Okay', 'Good', 'Great'];

  Color _moodColor(int? mood) {
    if (mood == null) return kBorder;
    switch (mood) {
      case 1: return const Color(0xFFE8C4C4);
      case 2: return const Color(0xFFEDD4B0);
      case 3: return const Color(0xFFEDE0C0);
      case 4: return const Color(0xFFC8DCB8);
      case 5: return const Color(0xFFF0D880);
      default: return kBorder;
    }
  }

  @override
  void initState() {
    super.initState();
    widget.activeNotifier?.addListener(_onActiveChanged);
    _load();
  }

  @override
  void dispose() {
    widget.activeNotifier?.removeListener(_onActiveChanged);
    _reflectionController.dispose();
    super.dispose();
  }

  void _onActiveChanged() {
    if (widget.activeNotifier?.value == true && mounted) _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      SupabaseService.fetchProfile(),
      SupabaseService.fetchMindsetData(),
      SupabaseService.fetchHealthData(),
    ]);
    if (!mounted) return;

    final profile = results[0];
    final mindset = results[1];
    final health = results[2];

    if (profile?['improve_mental_health'] != true) {
      setState(() {
        _isUnlocked = false;
        _isLoading = false;
      });
      return;
    }

    // Mindset challenges from onboarding answers
    final answers = profile?['answers'] as Map<String, dynamic>?;
    final mindsetGoals = answers?['mindset_goals'] as Map<String, dynamic>?;
    final challenges =
        (mindsetGoals?['mental_challenges'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [];

    // Mood log
    final rawLog = (mindset?['mood_log'] as List<dynamic>? ?? [])
        .map((e) => _MoodEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    final todayEntry = rawLog.where((e) => e.date == _today).firstOrNull;

    // Today's reflection
    final reflections = (mindset?['reflections'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final todayR =
        reflections.where((r) => r['date'] == _today).firstOrNull;

    // Self-care tasks from health data
    final tasks = (health?['self_care'] as List<dynamic>? ?? [])
        .map((j) => SelfCareTask.fromJson(j as Map<String, dynamic>))
        .toList();

    // Activity log
    final activityLog = (mindset?['activity_log'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final todayActivityEntry =
        activityLog.where((e) => e['date'] == _today).firstOrNull;
    final completedToday =
        (todayActivityEntry?['completed'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toSet();

    setState(() {
      _isUnlocked = true;
      _isLoading = false;
      _moodLog = rawLog;
      _todayMood = todayEntry?.mood;
      _todayEnergy = todayEntry?.energy;
      _mindsetChallenges = challenges;
      _selfCareTasks = tasks;
      _reflectionPrompt = todayR?['prompt'] as String?;
      _reflectionController.text = todayR?['response'] as String? ?? '';
      _reflectionReply = todayR?['ai_reply'] as String?;
      _reflectionExpanded = _reflectionReply != null;
      _completedActivitiesToday = completedToday;
      _activityStreaks = _computeStreaks(activityLog);
    });

    if (_reflectionPrompt == null) _generateReflectionPrompt();
  }

  Future<void> _generateReflectionPrompt() async {
    setState(() => _reflectionLoading = true);
    try {
      final prompt = await AiService.generateReflectionPrompt(
        apiKey: kAnthropicApiKey,
        challenges: _mindsetChallenges,
      );
      if (!mounted) return;
      setState(() {
        _reflectionPrompt = prompt;
        _reflectionLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reflectionPrompt = "What's one thing on your mind right now?";
        _reflectionLoading = false;
      });
    }
  }

  Future<void> _pickMoodThenEnergy(int mood) async {
    setState(() => _pendingMood = mood);
  }

  Future<void> _finishCheckin(int energy) async {
    final mood = _pendingMood!;
    setState(() {
      _todayMood = mood;
      _todayEnergy = energy;
      _pendingMood = null;
      _moodLog.removeWhere((e) => e.date == _today);
      _moodLog.add(_MoodEntry(date: _today, mood: mood, energy: energy));
    });
    await Future.wait([
      _saveMindset(),
      // Sync to profile.current_mood so the home screen overview updates
      SupabaseService.saveMood(_moodLabels[mood - 1]),
    ]);
  }

  Future<void> _submitReflection() async {
    final text = _reflectionController.text.trim();
    if (text.isEmpty || _reflectionPrompt == null) return;
    setState(() => _reflectionSubmitting = true);
    try {
      final reply = await AiService.respondToReflection(
        apiKey: kAnthropicApiKey,
        prompt: _reflectionPrompt!,
        userResponse: text,
      );
      if (!mounted) return;
      setState(() {
        _reflectionReply = reply;
        _reflectionSubmitting = false;
      });
      await _saveMindset();
    } catch (_) {
      if (!mounted) return;
      setState(() => _reflectionSubmitting = false);
    }
  }

  Future<void> _saveMindset() async {
    final existing = await SupabaseService.fetchMindsetData() ?? {};
    final rawLog = (existing['mood_log'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    rawLog.removeWhere((e) => e['date'] == _today);
    if (_todayMood != null) {
      rawLog.add({
        'date': _today,
        'mood': _todayMood,
        'energy': _todayEnergy ?? 3
      });
    }
    final reflections = (existing['reflections'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    reflections.removeWhere((r) => r['date'] == _today);
    if (_reflectionPrompt != null) {
      reflections.add({
        'date': _today,
        'prompt': _reflectionPrompt,
        'response': _reflectionController.text.trim(),
        'ai_reply': _reflectionReply,
      });
    }
    // Activity log
    final activityLog = (existing['activity_log'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    activityLog.removeWhere((e) => e['date'] == _today);
    activityLog.add({
      'date': _today,
      'completed': _completedActivitiesToday.toList(),
    });

    await SupabaseService.saveMindsetData({
      ...existing,
      'mood_log': rawLog,
      'reflections': reflections,
      'activity_log': activityLog,
    });
  }

  void _toggleSelfCare(SelfCareTask task) {
    setState(() {
      task.isDone = !task.isDone;
      if (task.isDone) task.lastCompletedAt = DateTime.now();
    });
    _saveHealthTasks();
  }

  Future<void> _saveHealthTasks() async {
    final existing = await SupabaseService.fetchHealthData() ?? {};
    await SupabaseService.saveHealthData({
      ...existing,
      'self_care': _selfCareTasks.map((t) => t.toJson()).toList(),
    });
  }

  void _unlock() async {
    final answers = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const MindsetUnlockScreen()),
    );
    if (!mounted) return;
    await SupabaseService.setGoalFlags({'improve_mental_health': true});
    if (answers != null) {
      final profile = await SupabaseService.fetchProfile();
      if (!mounted) return;
      final existing =
          Map<String, dynamic>.from(profile?['answers'] as Map? ?? {});
      existing['mindset_goals'] = answers;
      await SupabaseService.client
          .from('profiles')
          .update({'answers': existing}).eq(
              'id', SupabaseService.currentUser!.id);
    }
    if (!mounted) return;
    setState(() => _isUnlocked = true);
    _load();
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isUnlocked == null) {
      return Scaffold(
        backgroundColor: null,
        body: Center(
            child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary)),
      );
    }

    if (_isUnlocked == false) {
      return TabGateScreen(
        tabName: 'Mindset',
        icon: Icons.self_improvement,
        tagline: 'Build mental resilience and show up for yourself daily.',
        features: const [
          (Icons.spa_outlined, 'Guided mindset check-ins'),
          (Icons.insights_outlined, 'Track mood and energy patterns'),
          (Icons.auto_awesome_outlined, 'Personalized coping strategies'),
        ],
        onSetUp: _unlock,
      );
    }

    return Scaffold(
      backgroundColor: null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 80),
          children: [
            // ── Header ──
            _buildHeader(),
            const SizedBox(height: 20),

            // ── Mood check-in ──
            _buildMoodSection(),
            const SizedBox(height: 20),

            // ── Weekly chart ──
            if (_moodLog.isNotEmpty) ...[
              _buildWeeklyChart(),
              const SizedBox(height: 20),
            ],

            // ── Daily reflection ──
            _buildReflectionSection(),
            const SizedBox(height: 20),

            // ── Self-care tasks ──
            if (_selfCareTasks.isNotEmpty) ...[
              _buildSelfCareSection(),
              const SizedBox(height: 20),
            ],

            // ── Things to try today ──
            _buildActivitiesSection(),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          greeting,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: kGoldLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Text(
                'Mindset',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: kGold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Mood section ─────────────────────────────────────────────────────────

  Widget _buildMoodSection() {
    // Already logged today
    if (_todayMood != null && _pendingMood == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _moodColor(_todayMood),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Text(
              _moodEmojis[_todayMood! - 1],
              style: const TextStyle(fontSize: 36),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today: ${_moodLabels[_todayMood! - 1]}",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  if (_todayEnergy != null)
                    Text(
                      'Energy ${_todayEnergy! >= 4 ? 'high' : _todayEnergy! >= 3 ? 'moderate' : 'low'}',
                      style: TextStyle(
                          fontSize: 13,
                          color: kInk.withOpacity(0.6)),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () =>
                  setState(() {
                    _todayMood = null;
                    _todayEnergy = null;
                  }),
              child: Text('Edit',
                  style: TextStyle(
                      fontSize: 12,
                      color: kInk.withOpacity(0.5))),
            ),
          ],
        ),
      );
    }

    // Step 2: pick energy
    if (_pendingMood != null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_moodEmojis[_pendingMood! - 1],
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                const Text('How\'s your energy?',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (i) {
                final level = i + 1;
                return GestureDetector(
                  onTap: () => _finishCheckin(level),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _moodColor(level),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text('$level',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        level == 1
                            ? 'Empty'
                            : level == 2
                                ? 'Low'
                                : level == 3
                                    ? 'Okay'
                                    : level == 4
                                        ? 'Good'
                                        : 'Full',
                        style: TextStyle(
                            fontSize: 10, color: kDimText),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      );
    }

    // Step 1: pick mood
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How are you feeling?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Tap to check in',
              style: TextStyle(fontSize: 13, color: kDimText)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (i) {
              final mood = i + 1;
              return GestureDetector(
                onTap: () => _pickMoodThenEnergy(mood),
                child: Column(
                  children: [
                    Text(_moodEmojis[i],
                        style: const TextStyle(fontSize: 32)),
                    const SizedBox(height: 4),
                    Text(_moodLabels[i],
                        style:
                            TextStyle(fontSize: 11, color: kDimText)),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Weekly chart ─────────────────────────────────────────────────────────

  Widget _buildWeeklyChart() {
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This week',
              style:
                  TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.asMap().entries.map((entry) {
              final day = entry.value;
              final dateStr =
                  '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
              final moodEntry =
                  _moodLog.where((e) => e.date == dateStr).firstOrNull;
              final label =
                  dayLabels[day.weekday - 1 < 7 ? day.weekday - 1 : 0];
              return Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _moodColor(moodEntry?.mood),
                      shape: BoxShape.circle,
                    ),
                    child: moodEntry != null
                        ? Center(
                            child: Text(
                              _moodEmojis[moodEntry.mood - 1],
                              style: const TextStyle(fontSize: 16),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: dateStr == _today ? kInk : kDimText,
                          fontWeight: dateStr == _today
                              ? FontWeight.w700
                              : FontWeight.normal)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Reflection section ────────────────────────────────────────────────────

  Widget _buildReflectionSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: kGoldLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text('✍️',
                      style: const TextStyle(fontSize: 14)),
                ),
              ),
              const SizedBox(width: 10),
              const Text("Today's reflection",
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          if (_reflectionLoading)
            const Center(
                child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(strokeWidth: 2),
            ))
          else if (_reflectionPrompt != null) ...[
            Text(
              _reflectionPrompt!,
              style: TextStyle(
                  fontSize: 14,
                  color: kDimText,
                  fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
            // Show reply if we have one and not editing
            if (_reflectionReply != null && !_reflectionExpanded) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kGoldLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _reflectionReply!,
                  style: const TextStyle(fontSize: 14, height: 1.45),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () =>
                    setState(() => _reflectionExpanded = true),
                child: Text('Edit response',
                    style: TextStyle(
                        fontSize: 12, color: kDimText)),
              ),
            ] else ...[
              TextField(
                controller: _reflectionController,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Write whatever comes to mind...',
                  hintStyle: TextStyle(color: kDimText, fontSize: 13),
                  filled: true,
                  fillColor: kSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed:
                      _reflectionSubmitting ? null : _submitReflection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kInk,
                    foregroundColor: kCard,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _reflectionSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Send to Kloudy',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ── Self-care tasks ───────────────────────────────────────────────────────

  Widget _buildSelfCareSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Self-care checklist',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ...(_selfCareTasks.map((task) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => _toggleSelfCare(task),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: task.isDone ? kGoldLight : kCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color:
                            task.isDone ? kGold : kBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(task.icon,
                          size: 18,
                          color:
                              task.isDone ? kGold : kDimText),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          task.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color:
                                task.isDone ? kInk : kInk,
                            decoration: task.isDone
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: kDimText,
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: task.isDone
                            ? Icon(Icons.check_circle,
                                key: const ValueKey('done'),
                                color: kGold,
                                size: 20)
                            : Icon(
                                Icons.radio_button_unchecked,
                                key: const ValueKey('undone'),
                                color: kBorder,
                                size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ))),
      ],
    );
  }

  // ── Fun activities ────────────────────────────────────────────────────────

  Widget _buildActivitiesSection() {
    final today = _todaysActivities;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Things to try today',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Refreshes daily · tap to mark done',
            style: TextStyle(fontSize: 12, color: kDimText)),
        const SizedBox(height: 10),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: today.length,
            separatorBuilder: (context, i) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final a = today[i];
              final done = _completedActivitiesToday.contains(a.title);
              final streak = _activityStreaks[a.title] ?? 0;
              return GestureDetector(
                onTap: () => _toggleActivity(a.title),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 116,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: done
                        ? Color.lerp(a.color, kGold, 0.25)
                        : a.color,
                    borderRadius: BorderRadius.circular(18),
                    border: done
                        ? Border.all(color: kGold, width: 1.5)
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(a.icon,
                              size: 22,
                              color: done
                                  ? kGold
                                  : kInk),
                          if (streak > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🔥',
                                      style: TextStyle(fontSize: 10)),
                                  const SizedBox(width: 2),
                                  Text('$streak',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        a.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: done ? kGold : kInk,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (done) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.check_circle,
                                size: 12, color: kGold),
                            const SizedBox(width: 3),
                            Text('Done',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: kGold,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
