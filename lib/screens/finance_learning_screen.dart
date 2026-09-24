import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';

class FinanceLearningScreen extends StatefulWidget {
  const FinanceLearningScreen({super.key});

  @override
  State<FinanceLearningScreen> createState() => _FinanceLearningScreenState();
}

class _FinanceLearningScreenState extends State<FinanceLearningScreen> {
  static const _datesKey = 'kloudy_money_learning_days';
  static const _modulesKey = 'kloudy_money_learning_modules';
  static const _livesKey = 'kloudy_money_lives';
  static const _refillKey = 'kloudy_money_lives_refill';
  static const _pointsKey = 'kloudy_money_points';
  static const _modules = <_MoneyModule>[
    _MoneyModule(
      'Build a first budget',
      'START HERE',
      Icons.pie_chart_outline,
      'A budget is a plan for your money, not a restriction.',
      'What is the main job of a budget?',
      [
        'Tell you what you are allowed to buy',
        'Help you decide where your money goes',
        'Make every month cost the same',
      ],
      1,
    ),
    _MoneyModule(
      'Needs, wants & trade-offs',
      'START HERE',
      Icons.balance,
      'Needs keep you safe and functioning. Wants can still matter, but they compete with other goals.',
      'Which is usually a need?',
      ['A streaming upgrade', 'A concert ticket', 'A prescription refill'],
      2,
    ),
    _MoneyModule(
      'Read your pay stub',
      'GET PAID',
      Icons.receipt_long_outlined,
      'Gross pay is before deductions. Net pay is what lands in your account.',
      'Your take-home pay is your…',
      ['Net pay', 'Gross pay', 'Hourly rate'],
      0,
    ),
    _MoneyModule(
      'Make bills less stressful',
      'STAY ON TRACK',
      Icons.calendar_month_outlined,
      'Knowing due dates and setting reminders can prevent late fees and surprises.',
      'What is a helpful first step?',
      [
        'Ignore bills until payday',
        'List due dates and minimum payments',
        'Pay only the smallest bill',
      ],
      1,
    ),
    _MoneyModule(
      'Credit scores, simply',
      'CREDIT',
      Icons.credit_score_outlined,
      'On-time payments and lower balances can help build a positive credit history over time.',
      'Which habit can support your credit history?',
      [
        'Paying at least on time',
        'Opening many cards at once',
        'Using every dollar of your limit',
      ],
      0,
    ),
    _MoneyModule(
      'Interest: friend or foe?',
      'CREDIT',
      Icons.trending_up_rounded,
      'Interest is the cost of borrowing, or the return earned when savings grow.',
      'When you carry a credit card balance, interest is…',
      [
        'A fee for borrowing',
        'A reward from the bank',
        'The same as your payment',
      ],
      0,
    ),
    _MoneyModule(
      'Start an emergency cushion',
      'SAVE & GROW',
      Icons.savings_outlined,
      'Small, regular contributions can make an unexpected expense easier to handle.',
      'A starter emergency fund is for…',
      ['A planned vacation', 'Unexpected expenses', 'Everyday subscriptions'],
      1,
    ),
    _MoneyModule(
      'Bank account basics',
      'SAVE & GROW',
      Icons.account_balance_outlined,
      'Compare fees, minimums, access, and deposit timing when choosing an account.',
      'What should you check before opening an account?',
      [
        'Monthly fees and minimums',
        'The bank logo color',
        'How many ads it has',
      ],
      0,
    ),
  ];

  List<String> _completedDays = [];
  Set<String> _completedModules = {};
  int _lives = 5;
  int _points = 0;
  DateTime _nextRefill = DateTime.now().add(const Duration(hours: 24));
  _MoneyModule? _selected;
  int? _answer;
  bool _loaded = false;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _load();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _refreshLives());
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic>? cloudProgress;
    try {
      cloudProgress = await SupabaseService.fetchLearningData();
    } catch (_) {}
    final now = DateTime.now();
    final savedRefill = DateTime.fromMillisecondsSinceEpoch(
      prefs.getInt(_refillKey) ??
          now.add(const Duration(hours: 24)).millisecondsSinceEpoch,
    );
    final expired = !now.isBefore(savedRefill);
    final refill = expired ? now.add(const Duration(hours: 24)) : savedRefill;
    final lives = (prefs.getInt(_livesKey) ?? 5) + (expired ? 5 : 0);
    if (!mounted) return;
    setState(() {
      _completedDays = List<String>.from(
        cloudProgress?['completed_days'] as List? ??
            prefs.getStringList(_datesKey) ??
            [],
      );
      _completedModules = Set<String>.from(
        cloudProgress?['completed_modules'] as List? ??
            prefs.getStringList(_modulesKey) ??
            [],
      );
      _lives = lives;
      _points =
          cloudProgress?['coins'] as int? ?? prefs.getInt(_pointsKey) ?? 0;
      _nextRefill = refill;
      _loaded = true;
    });
    await prefs.setInt(_livesKey, lives);
    await prefs.setInt(_refillKey, refill.millisecondsSinceEpoch);
  }

  Future<void> _refreshLives() async {
    if (!_loaded) return;
    final now = DateTime.now();
    if (!now.isBefore(_nextRefill)) {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final next = now.add(const Duration(hours: 24));
      final lives = _lives + 5;
      setState(() {
        _lives = lives;
        _nextRefill = next;
      });
      await prefs.setInt(_livesKey, lives);
      await prefs.setInt(_refillKey, next.millisecondsSinceEpoch);
    } else {
      setState(() {});
    }
  }

  String get _today => _date(DateTime.now());
  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  bool get _doneToday => _completedDays.contains(_today);

  int get _streak {
    final days = _completedDays.toSet();
    var cursor = DateTime.now();
    if (!days.contains(_date(cursor)))
      cursor = cursor.subtract(const Duration(days: 1));
    var count = 0;
    while (days.contains(_date(cursor))) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  Future<void> _complete(_MoneyModule module) async {
    final prefs = await SharedPreferences.getInstance();
    final modules = {..._completedModules, module.title};
    final days = _doneToday ? _completedDays : [..._completedDays, _today];
    final points = _points + 1000;
    setState(() {
      _completedDays = days;
      _completedModules = modules;
      _points = points;
      _selected = null;
      _answer = null;
    });
    await prefs.setStringList(_datesKey, days);
    await prefs.setStringList(_modulesKey, modules.toList());
    await prefs.setInt(_pointsKey, points);
    await SupabaseService.saveLearningData({
      'completed_days': days,
      'completed_modules': modules.toList(),
      'coins': points,
    });
  }

  Future<void> _chooseAnswer(int index, _MoneyModule module) async {
    if (_answer != null || _lives <= 0) return;
    setState(() => _answer = index);
    if (index != module.correct) {
      final prefs = await SharedPreferences.getInstance();
      final lives = (_lives - 1).clamp(0, 99);
      setState(() => _lives = lives);
      await prefs.setInt(_livesKey, lives);
      await prefs.setInt(_refillKey, _nextRefill.millisecondsSinceEpoch);
    }
  }

  Future<void> _buyLives() async {
    if (_points < 500) return;
    final prefs = await SharedPreferences.getInstance();
    final points = _points - 500;
    final lives = _lives + 5;
    setState(() {
      _points = points;
      _lives = lives;
      _answer = null;
    });
    await prefs.setInt(_pointsKey, points);
    await prefs.setInt(_livesKey, lives);
    await SupabaseService.saveLearningData({
      'completed_days': _completedDays,
      'completed_modules': _completedModules.toList(),
      'coins': points,
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(_selected == null ? 'Money moves' : _selected!.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _selected == null
          ? _buildLibrary(colors)
          : _buildLesson(colors, _selected!),
    );
  }

  Widget _buildLibrary(ColorScheme colors) {
    final sections = _modules.map((m) => m.section).toSet();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _streakCard(colors),
        const SizedBox(height: 12),
        _walletCard(colors),
        const SizedBox(height: 16),
        _friendsCard(colors),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Your learning path',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${_completedDays.length} day${_completedDays.length == 1 ? '' : 's'} learned',
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurface.withOpacity(.56),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final section in sections) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 9, top: 9),
            child: Text(
              section,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
          ),
          ..._modules.where((m) => m.section == section).map(_moduleTile),
        ],
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Demo leaderboard · friend scores are sample data',
            style: TextStyle(
              color: colors.onSurface.withOpacity(.45),
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _streakCard(ColorScheme colors) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [colors.primary, colors.tertiary]),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.18),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('🔥', style: TextStyle(fontSize: 28)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_streak day${_streak == 1 ? '' : 's'} of money smarts',
                style: TextStyle(
                  color: colors.onPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _doneToday
                    ? 'Today’s lesson complete. Come back tomorrow!'
                    : 'Finish one quick module today to keep your streak.',
                style: TextStyle(
                  color: colors.onPrimary.withOpacity(.84),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _friendsCard(ColorScheme colors) {
    final ranks = <(String, String, int)>[
      ('You', '🙂', _points),
      ('Maya', '🧑🏽‍🎓', 6000),
      ('Jules', '🧑🏻‍💻', 3000),
      ('Sam', '🧑🏾‍🎨', 1000),
    ]..sort((a, b) => b.$3.compareTo(a.$3));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.groups_2_outlined, color: colors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Friends leaderboard',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const Text(
                'TOTAL PTS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < ranks.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: colors.onSurface.withOpacity(.5),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(ranks[i].$2, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      ranks[i].$1,
                      style: TextStyle(
                        fontWeight: ranks[i].$1 == 'You'
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${ranks[i].$3} pts',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurface.withOpacity(.62),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _walletCard(ColorScheme colors) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _walletMetric(
                colors,
                Icons.favorite_rounded,
                '$_lives lives',
                'Refill in ${_countdown(_nextRefill.difference(DateTime.now()))}',
              ),
            ),
            Container(width: 1, height: 42, color: colors.outlineVariant),
            Expanded(
              child: _walletMetric(
                colors,
                Icons.stars_rounded,
                '$_points points',
                '1,000 per module',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _points >= 500 ? _buyLives : null,
          icon: const Icon(Icons.favorite_border_rounded),
          label: const Text('Get 5 lives · 500 points'),
        ),
      ],
    ),
  );

  Widget _walletMetric(
    ColorScheme colors,
    IconData icon,
    String value,
    String caption,
  ) => Row(
    children: [
      Icon(icon, color: colors.primary),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              caption,
              style: TextStyle(
                fontSize: 11,
                color: colors.onSurface.withOpacity(.6),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  String _countdown(Duration duration) {
    if (duration.isNegative) return '00:00:00';
    final h = duration.inHours.toString().padLeft(2, '0');
    final m = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final s = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Widget _moduleTile(_MoneyModule module) {
    final colors = Theme.of(context).colorScheme;
    final done = _completedModules.contains(module.title);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: () => setState(() {
            _selected = module;
            _answer = null;
          }),
          borderRadius: BorderRadius.circular(17),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(module.icon, color: colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '2 min · quick check',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurface.withOpacity(.54),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  done ? Icons.check_circle : Icons.chevron_right,
                  color: done
                      ? colors.primary
                      : colors.onSurface.withOpacity(.48),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLesson(ColorScheme colors, _MoneyModule module) {
    final answered = _answer != null;
    final correct = _answer == module.correct;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
      children: [
        Text(
          module.section,
          style: TextStyle(
            color: colors.primary,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          module.title,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            module.lesson,
            style: TextStyle(
              color: colors.onPrimaryContainer,
              fontSize: 17,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Icon(Icons.favorite_rounded, size: 18, color: colors.error),
            const SizedBox(width: 6),
            Text(
              '$_lives lives left',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Icon(Icons.stars_rounded, size: 18, color: colors.primary),
            const SizedBox(width: 5),
            Text(
              '$_points points',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        if (_lives == 0) ...[
          const SizedBox(height: 10),
          Text(
            'Your next five lives arrive in ${_countdown(_nextRefill.difference(DateTime.now()))}.',
            style: TextStyle(color: colors.error),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _points >= 500 ? _buyLives : null,
            icon: const Icon(Icons.favorite_border_rounded),
            label: const Text('Trade 500 points for 5 lives'),
          ),
        ],
        const SizedBox(height: 18),
        Text(
          module.question,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 13),
        for (var i = 0; i < module.answers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton(
              onPressed: answered || _lives <= 0
                  ? null
                  : () => _chooseAnswer(i, module),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                alignment: Alignment.centerLeft,
                backgroundColor: answered && i == module.correct
                    ? colors.primary.withOpacity(.11)
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(child: Text(module.answers[i])),
                  if (answered && i == module.correct)
                    Icon(Icons.check_circle, color: colors.primary),
                ],
              ),
            ),
          ),
        if (answered) ...[
          const SizedBox(height: 6),
          Text(
            correct
                ? 'That’s it! You’ve got this.'
                : 'Good try. The key idea is: ${module.lesson}',
            style: TextStyle(
              color: correct
                  ? colors.primary
                  : colors.onSurface.withOpacity(.75),
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          if (!correct && _lives > 0)
            OutlinedButton.icon(
              onPressed: () => setState(() => _answer = null),
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Try again · costs 1 life'),
            )
          else if (correct)
            FilledButton.icon(
              onPressed: _completedModules.contains(module.title)
                  ? () => setState(() {
                      _selected = null;
                      _answer = null;
                    })
                  : () => _complete(module),
              icon: Icon(
                _completedModules.contains(module.title)
                    ? Icons.check
                    : Icons.stars_rounded,
              ),
              label: Text(
                _completedModules.contains(module.title)
                    ? 'Module complete'
                    : 'Complete · earn 1,000 points',
              ),
            ),
        ],
        if (!answered)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Choose an answer to check your understanding.',
              style: TextStyle(color: colors.onSurface.withOpacity(.54)),
            ),
          ),
      ],
    );
  }
}

class _MoneyModule {
  final String title;
  final String section;
  final IconData icon;
  final String lesson;
  final String question;
  final List<String> answers;
  final int correct;
  const _MoneyModule(
    this.title,
    this.section,
    this.icon,
    this.lesson,
    this.question,
    this.answers,
    this.correct,
  );
}
