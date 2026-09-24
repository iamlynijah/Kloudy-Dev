import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/nutrition_profile.dart';
import '../models/streak.dart';
import '../services/supabase_service.dart';
import '../services/food_scan_service.dart';
import 'nutrition_onboarding_screen.dart';
import 'tab_gate_screen.dart';

enum _ScanMode { scan, barcode, manual }

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  bool _isLoading = true;
  bool _hasData = false;
  bool? _isUnlocked;

  NutritionProfile? _profile;
  double _currentWeightLbs = 0;
  Map<String, List<FoodEntry>> _foodLogs = {};
  Map<String, int> _waterLog = {};
  List<WeightEntry> _weightLog = [];
  int _loggingStreak = 0;
  List<String> _flexUsedDates = [];
  List<String> _flexPromptedDates = [];
  String _loggingStreakLastDate = '';
  int _gymStreak = 0;

  String get _todayStr {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  String get _formattedDate {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final n = DateTime.now();
    return '${months[n.month]} ${n.day}';
  }

  List<FoodEntry> get _todayEntries => _foodLogs[_todayStr] ?? [];
  int get _waterToday => _waterLog[_todayStr] ?? 0;

  int get _todayCalories => _todayEntries.fold(0, (sum, e) => sum + e.calories);
  double get _todayProtein =>
      _todayEntries.fold(0.0, (sum, e) => sum + e.protein);
  double get _todayCarbs => _todayEntries.fold(0.0, (sum, e) => sum + e.carbs);
  double get _todayFat => _todayEntries.fold(0.0, (sum, e) => sum + e.fat);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      SupabaseService.fetchNutritionData(),
      SupabaseService.fetchHealthData(),
      SupabaseService.fetchProfile(),
    ]);
    if (!mounted) return;

    final nutritionData = results[0];
    final healthData = results[1];
    final profile = results[2];

    final hasNutritionGoals =
        profile?['lose_weight'] == true ||
        profile?['build_muscle'] == true ||
        profile?['improve_nutrition'] == true;

    if (!hasNutritionGoals) {
      setState(() {
        _isUnlocked = false;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isUnlocked = true);

    // Extract gym streak from health data
    if (healthData != null) {
      final streakList = (healthData['streaks'] as List<dynamic>? ?? [])
          .map((j) => Streak.fromJson(j as Map<String, dynamic>))
          .toList();
      final gymStreak = streakList
          .where(
            (s) =>
                s.name.toLowerCase().contains('gym') ||
                s.icon.codePoint == Icons.fitness_center.codePoint,
          )
          .firstOrNull;
      _gymStreak = gymStreak?.currentStreak ?? 0;
    }

    if (nutritionData == null) {
      setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openOnboarding();
      });
    } else {
      _populateFromData(nutritionData);
    }
  }

  void _unlock() async {
    await SupabaseService.setGoalFlags({
      'lose_weight': true,
      'improve_nutrition': true,
    });
    if (!mounted) return;
    setState(() {
      _isUnlocked = true;
      _isLoading = false;
    });
    _openOnboarding();
  }

  void _populateFromData(Map<String, dynamic> data) {
    final profileJson = data['profile'] as Map<String, dynamic>?;
    final profile = profileJson != null
        ? NutritionProfile.fromJson(profileJson)
        : null;

    final foodLogsRaw = data['food_logs'] as Map<String, dynamic>? ?? {};
    final foodLogs = foodLogsRaw.map(
      (date, entries) => MapEntry(
        date,
        (entries as List<dynamic>)
            .map((e) => FoodEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );

    final waterLogRaw = data['water_log'] as Map<String, dynamic>? ?? {};
    final waterLog = waterLogRaw.map(
      (date, cups) => MapEntry(date, (cups as num).toInt()),
    );

    final weightLogRaw = data['weight_log'] as List<dynamic>? ?? [];
    final weightLog = weightLogRaw
        .map((e) => WeightEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    setState(() {
      _profile = profile;
      _currentWeightLbs = (data['current_weight'] as num?)?.toDouble() ?? 0;
      _foodLogs = foodLogs;
      _waterLog = waterLog;
      _weightLog = weightLog;
      _loggingStreak = data['logging_streak'] as int? ?? 0;
      _flexUsedDates = List<String>.from(
        data['flex_used_dates'] as List? ?? [],
      );
      _flexPromptedDates = List<String>.from(
        data['flex_prompted_dates'] as List? ?? [],
      );
      _loggingStreakLastDate =
          data['logging_streak_last_date'] as String? ?? '';
      _hasData = profile != null;
      _isLoading = false;
    });
  }

  Future<void> _saveNutritionData() async {
    if (_profile == null) return;
    await SupabaseService.saveNutritionData({
      'profile': _profile!.toJson(),
      'current_weight': _currentWeightLbs,
      'weight_log': _weightLog.map((e) => e.toJson()).toList(),
      'food_logs': _foodLogs.map(
        (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
      ),
      'water_log': _waterLog,
      'logging_streak': _loggingStreak,
      'logging_streak_last_date': _loggingStreakLastDate,
      'flex_used_dates': _flexUsedDates,
      'flex_prompted_dates': _flexPromptedDates,
    });
  }

  void _openOnboarding() async {
    final profile = await SupabaseService.fetchProfile();
    if (!mounted) return;

    final answers = profile?['answers'] as Map<String, dynamic>?;
    final initialWeight = (answers?['current_weight'] as num?)?.toDouble();
    final initialGoalWeight = (answers?['goal_weight'] as num?)?.toDouble();
    final initialAge = profile?['age'] as int?;

    NutritionGoalType? initialGoalType;
    final loseWeight = profile?['lose_weight'] as bool? ?? false;
    final buildMuscle = profile?['build_muscle'] as bool? ?? false;
    if (loseWeight && buildMuscle) {
      initialGoalType = NutritionGoalType.recomposition;
    } else if (loseWeight) {
      initialGoalType = NutritionGoalType.loseFat;
    } else if (buildMuscle) {
      initialGoalType = NutritionGoalType.buildMuscle;
    }

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => NutritionOnboardingScreen(
          initialWeight: initialWeight,
          initialGoalWeight: initialGoalWeight,
          initialGoalType: initialGoalType,
          initialAge: initialAge,
          initialProfile: _profile,
        ),
      ),
    );
    if (result != null && mounted) {
      final existing = await SupabaseService.fetchNutritionData() ?? {};
      final merged = <String, dynamic>{...existing, ...result};
      for (final key in [
        'food_logs',
        'water_log',
        'logging_streak',
        'logging_streak_last_date',
        'flex_used_dates',
        'flex_prompted_dates',
      ]) {
        if (existing.containsKey(key)) merged[key] = existing[key];
      }
      final oldWeights = (existing['weight_log'] as List<dynamic>? ?? [])
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();
      final newWeights = (result['weight_log'] as List<dynamic>? ?? [])
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();
      final mergedWeights = <String, Map<String, dynamic>>{
        for (final entry in oldWeights) entry['date'] as String: entry,
        for (final entry in newWeights) entry['date'] as String: entry,
      };
      merged['weight_log'] = mergedWeights.values.toList()
        ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
      await SupabaseService.saveNutritionData(merged);
      _populateFromData(merged);
    }
  }

  void _updateLoggingStreak() {
    final today = _todayStr;
    if (_loggingStreakLastDate == today) return;
    final yesterday = () {
      final y = DateTime.now().subtract(const Duration(days: 1));
      return '${y.year}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
    }();
    _loggingStreak = _loggingStreakLastDate == yesterday
        ? _loggingStreak + 1
        : 1;
    _loggingStreakLastDate = today;
  }

  void _addFood(String meal) async {
    final result = await showModalBottomSheet<FoodEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddFoodSheet(defaultMeal: meal),
    );
    if (result != null && mounted) {
      setState(() {
        _foodLogs[_todayStr] = [...(_foodLogs[_todayStr] ?? []), result];
        _updateLoggingStreak();
      });
      await _saveNutritionData();
      await _maybeOfferFlexDay();
    }
  }

  Future<void> _maybeOfferFlexDay() async {
    final profile = _profile;
    if (profile == null || profile.flexibilitySchedule == 'none') return;
    final today = _todayStr;
    if (_flexPromptedDates.contains(today)) return;
    final foods = _foodLogs[today] ?? [];
    final consumed = foods.fold<int>(0, (sum, item) => sum + item.calories);
    final over = consumed - profile.calorieGoal;
    if (over < 100) return;

    final usedThisPeriod = _flexUsedDates.any((rawDate) {
      final used = DateTime.tryParse(rawDate);
      if (used == null) return false;
      final now = DateTime.now();
      if (profile.flexibilitySchedule == 'monthly') {
        return used.year == now.year && used.month == now.month;
      }
      final start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
      return !used.isBefore(start);
    });
    if (usedThisPeriod) return;

    _flexPromptedDates = [..._flexPromptedDates, today];
    await _saveNutritionData();
    if (!mounted) return;
    final useDay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Make room for flexibility?'),
        content: Text(
          'You’re $over calories over your target today. Would you like to use your planned flexibility day or keep tracking as usual?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep tracking'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Use flexibility day'),
          ),
        ],
      ),
    );
    if (useDay == true) {
      _flexUsedDates = [..._flexUsedDates, today];
      await _saveNutritionData();
    }
  }

  void _removeFood(FoodEntry entry) {
    setState(() {
      _foodLogs[_todayStr] = (_foodLogs[_todayStr] ?? [])
          .where((e) => e.id != entry.id)
          .toList();
    });
    _saveNutritionData();
  }

  void _tapWater(int cups) {
    setState(() => _waterLog[_todayStr] = cups);
    _saveNutritionData();
  }

  void _logWeight() async {
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LogWeightSheet(currentWeight: _currentWeightLbs),
    );
    if (result != null && mounted) {
      setState(() {
        _currentWeightLbs = result;
        _weightLog.removeWhere((e) => e.date == _todayStr);
        _weightLog.add(WeightEntry(date: _todayStr, weightLbs: result));
      });
      await _saveNutritionData();
    }
  }

  List<String> get _mealSections {
    final base = ['breakfast', 'lunch', 'dinner', 'snack', 'dessert'];
    if (_profile?.trackAlcohol == true) base.add('drinks');
    return base;
  }

  @override
  Widget build(BuildContext context) {
    if (_isUnlocked == false) {
      return TabGateScreen(
        tabName: 'Nutrition',
        icon: Icons.restaurant_menu,
        tagline: 'Track calories, macros, and make progress toward your goal.',
        features: [
          (Icons.local_fire_department_outlined, 'Calorie & macro tracking'),
          (Icons.show_chart, 'Weight progress toward your goal'),
          (Icons.water_drop_outlined, 'Daily water intake tracker'),
        ],
        onSetUp: _unlock,
      );
    }

    final profile = _profile;

    return Scaffold(
      backgroundColor: null, // inherits from theme
      appBar: AppBar(
        leading: Navigator.of(context).canPop() ? const BackButton() : null,
        title: const Text('Nutrition'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: _hasData
          ? FloatingActionButton(
              onPressed: _openOnboarding,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: const CircleBorder(),
              child: const Icon(Icons.edit_outlined, size: 20),
            )
          : null,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Nutrition',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _formattedDate,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.45),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    if (!_hasData) ...[
                      const SizedBox(height: 24),
                      _SetupPrompt(onTap: _openOnboarding),
                    ] else ...[
                      // ── Streak pills ──
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _StreakPill(
                            icon: Icons.local_fire_department,
                            count: _loggingStreak,
                            label: 'day streak',
                            color: const Color(0xFFFF6F00),
                          ),
                          if (_gymStreak > 0) ...[
                            const SizedBox(width: 8),
                            _StreakPill(
                              icon: Icons.fitness_center,
                              count: _gymStreak,
                              label: 'gym streak',
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ],
                        ],
                      ),

                      // ── Calorie card ──
                      const SizedBox(height: 16),
                      _CalorieCard(
                        consumed: _todayCalories,
                        goal: profile!.calorieGoal,
                        protein: _todayProtein,
                        proteinGoal: profile.proteinGoal,
                        carbs: _todayCarbs,
                        carbsGoal: profile.carbGoal,
                        fat: _todayFat,
                        fatGoal: profile.fatGoal,
                      ),

                      // ── Water tracker ──
                      const SizedBox(height: 12),
                      _WaterTracker(
                        cups: _waterToday,
                        goal: profile.waterCupsGoal,
                        onTap: _tapWater,
                      ),

                      // ── Food log ──
                      const SizedBox(height: 24),
                      const Text(
                        "Today's food",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._mealSections.map(
                        (meal) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _MealSection(
                            meal: meal,
                            entries: _todayEntries
                                .where((e) => e.meal == meal)
                                .toList(),
                            onAdd: () => _addFood(meal),
                            onRemove: _removeFood,
                          ),
                        ),
                      ),

                      // ── Weight goal bar ──
                      const SizedBox(height: 24),
                      const Text(
                        'Weight goal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _WeightGoalCard(
                        startWeight: profile.startWeightLbs,
                        currentWeight: _currentWeightLbs,
                        goalWeight: profile.goalWeightLbs,
                        goalType: profile.goalType,
                        onLog: _logWeight,
                      ),

                      const SizedBox(height: 80),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Setup prompt ───────────────────────────────────────────────────────────

class _SetupPrompt extends StatelessWidget {
  final VoidCallback onTap;

  const _SetupPrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.restaurant_menu_outlined, size: 24),
            ),
            const SizedBox(height: 14),
            const Text(
              'Set up your nutrition plan',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Track calories, hit your macros, and move toward your weight goal.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "Let's do it",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Streak pill ────────────────────────────────────────────────────────────

class _StreakPill extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;

  const _StreakPill({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$count-$label',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Calorie card ───────────────────────────────────────────────────────────

class _CalorieCard extends StatelessWidget {
  final int consumed;
  final int goal;
  final double protein;
  final int proteinGoal;
  final double carbs;
  final int carbsGoal;
  final double fat;
  final int fatGoal;

  const _CalorieCard({
    required this.consumed,
    required this.goal,
    required this.protein,
    required this.proteinGoal,
    required this.carbs,
    required this.carbsGoal,
    required this.fat,
    required this.fatGoal,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (goal - consumed).clamp(0, goal);
    final over = consumed > goal ? consumed - goal : 0;
    final progress = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: consumed / goal
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$consumed',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ' / $goal cal',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.45),
                ),
              ),
              const Spacer(),
              Text(
                over > 0 ? '$over over' : '$remaining left',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: over > 0
                      ? Colors.red
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFF0F0F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                over > 0 ? Colors.red : Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Macro pills
          Row(
            children: [
              _MacroPill(
                label: 'Protein',
                value: protein.round(),
                goal: proteinGoal,
                color: const Color(0xFF43A047),
              ),
              const SizedBox(width: 8),
              _MacroPill(
                label: 'Carbs',
                value: carbs.round(),
                goal: carbsGoal,
                color: const Color(0xFFF9A825),
              ),
              const SizedBox(width: 8),
              _MacroPill(
                label: 'Fat',
                value: fat.round(),
                goal: fatGoal,
                color: const Color(0xFFE53935),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  final String label;
  final int value;
  final int goal;
  final Color color;

  const _MacroPill({
    required this.label,
    required this.value,
    required this.goal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${value}g',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              'of ${goal}g',
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.45),
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.08),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Water tracker ──────────────────────────────────────────────────────────

class _WaterTracker extends StatelessWidget {
  final int cups;
  final int goal;
  final void Function(int) onTap;

  const _WaterTracker({
    required this.cups,
    required this.goal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            Icons.water_drop_outlined,
            size: 18,
            color: const Color(0xFF1565C0),
          ),
          const SizedBox(width: 10),
          Text(
            '$cups / $goal cups',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          ...List.generate(goal.clamp(0, 10), (i) {
            final filled = i < cups;
            return GestureDetector(
              onTap: () => onTap(filled && cups == i + 1 ? i : i + 1),
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  filled ? Icons.water_drop : Icons.water_drop_outlined,
                  size: 20,
                  color: filled
                      ? const Color(0xFF1565C0)
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.15),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Meal section ───────────────────────────────────────────────────────────

class _MealSection extends StatelessWidget {
  final String meal;
  final List<FoodEntry> entries;
  final VoidCallback onAdd;
  final void Function(FoodEntry) onRemove;

  const _MealSection({
    required this.meal,
    required this.entries,
    required this.onAdd,
    required this.onRemove,
  });

  String get _mealLabel => switch (meal) {
    'breakfast' => 'Breakfast',
    'lunch' => 'Lunch',
    'dinner' => 'Dinner',
    'snack' => 'Snacks',
    'dessert' => 'Dessert',
    'drinks' => 'Drinks',
    _ => meal,
  };

  IconData get _mealIcon => switch (meal) {
    'breakfast' => Icons.wb_sunny_outlined,
    'lunch' => Icons.lunch_dining_outlined,
    'dinner' => Icons.dinner_dining_outlined,
    'snack' => Icons.apple_outlined,
    'dessert' => Icons.cake_outlined,
    'drinks' => Icons.local_bar_outlined,
    _ => Icons.restaurant_outlined,
  };

  int get _totalCals => entries.fold(0, (sum, e) => sum + e.calories);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                Icon(
                  _mealIcon,
                  size: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 8),
                Text(
                  _mealLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (entries.isNotEmpty)
                  Text(
                    '$_totalCals cal',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.45),
                    ),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          // Food entries
          if (entries.isNotEmpty) ...[
            const Divider(height: 1, indent: 14, endIndent: 14),
            ...entries.map(
              (e) => _FoodRow(entry: e, onRemove: () => onRemove(e)),
            ),
          ],
        ],
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  final FoodEntry entry;
  final VoidCallback onRemove;

  const _FoodRow({required this.entry, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final hasMacros = entry.protein > 0 || entry.carbs > 0 || entry.fat > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (hasMacros)
                  Text(
                    '${entry.protein.round()}g P · ${entry.carbs.round()}g C · ${entry.fat.round()}g F',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.45),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${entry.calories} cal',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Weight goal card ───────────────────────────────────────────────────────

class _WeightGoalCard extends StatelessWidget {
  final double startWeight;
  final double currentWeight;
  final double goalWeight;
  final NutritionGoalType goalType;
  final VoidCallback onLog;

  const _WeightGoalCard({
    required this.startWeight,
    required this.currentWeight,
    required this.goalWeight,
    required this.goalType,
    required this.onLog,
  });

  @override
  Widget build(BuildContext context) {
    final hasGoal = goalType.hasWeightGoal && goalWeight != 0;
    double progress = 0;
    double remaining = 0;
    bool isGain = goalType == NutritionGoalType.buildMuscle;

    if (hasGoal && startWeight != goalWeight) {
      if (isGain) {
        progress = ((currentWeight - startWeight) / (goalWeight - startWeight))
            .clamp(0.0, 1.0);
        remaining = (goalWeight - currentWeight).abs();
      } else {
        progress = ((startWeight - currentWeight) / (startWeight - goalWeight))
            .clamp(0.0, 1.0);
        remaining = (currentWeight - goalWeight).clamp(0.0, double.infinity);
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasGoal) ...[
            // Weight labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _WeightLabel(label: 'Start', weight: startWeight, faded: true),
                _WeightLabel(label: 'Now', weight: currentWeight, faded: false),
                _WeightLabel(label: 'Goal', weight: goalWeight, faded: true),
              ],
            ),
            const SizedBox(height: 10),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: const Color(0xFFF0F0F0),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              remaining > 0
                  ? '${remaining.toStringAsFixed(1)} lbs to go · ${(progress * 100).round()}% there'
                  : 'Goal reached!',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 14),
          ],
          // Current weight display
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current weight',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        currentWeight.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        ' lbs',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.54),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: onLog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '+ Log weight',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeightLabel extends StatelessWidget {
  final String label;
  final double weight;
  final bool faded;

  const _WeightLabel({
    required this.label,
    required this.weight,
    required this.faded,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withOpacity(faded ? 0.4 : 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '${weight.toStringAsFixed(0)} lb',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withOpacity(faded ? 0.5 : 1.0),
          ),
        ),
      ],
    );
  }
}

// ── Add food sheet ─────────────────────────────────────────────────────────

class _AddFoodSheet extends StatefulWidget {
  final String defaultMeal;

  const _AddFoodSheet({required this.defaultMeal});

  @override
  State<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<_AddFoodSheet> {
  late String _meal;
  final _nameCtrl = TextEditingController();
  final _calCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  bool _showMacros = false;

  _ScanMode _mode = _ScanMode.manual;
  bool _scanning = false;
  String? _scanError;
  FoodScanResult? _baseResult;
  double _quantity = 1.0;

  static const _mealOptions = [
    'breakfast',
    'lunch',
    'dinner',
    'snack',
    'dessert',
    'drinks',
  ];

  @override
  void initState() {
    super.initState();
    _meal = widget.defaultMeal;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _calCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final calories = int.tryParse(_calCtrl.text) ?? 0;
    if (name.isEmpty || calories == 0) return;
    Navigator.pop(
      context,
      FoodEntry(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        meal: _meal,
        calories: calories,
        protein: double.tryParse(_proteinCtrl.text) ?? 0,
        carbs: double.tryParse(_carbsCtrl.text) ?? 0,
        fat: double.tryParse(_fatCtrl.text) ?? 0,
      ),
    );
  }

  void _quickAdd(QuickAddPreset p) {
    _nameCtrl.text = p.name;
    _calCtrl.text = '${p.calories}';
    _proteinCtrl.text = '${p.protein}';
    _carbsCtrl.text = '${p.carbs}';
    _fatCtrl.text = '${p.fat}';
    setState(() => _showMacros = true);
  }

  String _mealLabel(String m) => switch (m) {
    'breakfast' => 'Breakfast',
    'lunch' => 'Lunch',
    'dinner' => 'Dinner',
    'snack' => 'Snacks',
    'dessert' => 'Dessert',
    'drinks' => 'Drinks',
    _ => m,
  };

  String _fmt(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

  void _applyResult(FoodScanResult r) {
    setState(() {
      _baseResult = r;
      _quantity = 1.0;
      _scanning = false;
      _scanError = null;
    });
    _nameCtrl.text = r.name;
    _calCtrl.text = '${r.calories}';
    if (r.protein > 0 || r.carbs > 0 || r.fat > 0) {
      _proteinCtrl.text = r.protein > 0 ? _fmt(r.protein) : '';
      _carbsCtrl.text = r.carbs > 0 ? _fmt(r.carbs) : '';
      _fatCtrl.text = r.fat > 0 ? _fmt(r.fat) : '';
      setState(() => _showMacros = true);
    }
  }

  void _updateQuantity(double q) {
    if (_baseResult == null) return;
    setState(() => _quantity = q);
    final s = _baseResult!.scaled(q);
    _calCtrl.text = '${s.calories}';
    if (_showMacros) {
      _proteinCtrl.text = _fmt(s.protein);
      _carbsCtrl.text = _fmt(s.carbs);
      _fatCtrl.text = _fmt(s.fat);
    }
  }

  Future<void> _scanWithCamera() async {
    setState(() => _scanError = null);
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (file == null || !mounted) return;
    setState(() => _scanning = true);
    try {
      final bytes = await file.readAsBytes();
      final result = await FoodScanService.analyzeImage(bytes);
      if (!mounted) return;
      if (result != null) {
        _applyResult(result);
      } else {
        final error = SupabaseService.currentUser == null
            ? 'Sign in to use photo analysis.'
            : 'We couldn’t analyze this photo. Check your connection and try again, or enter the food manually.';
        setState(() {
          _scanning = false;
          _scanError = error;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _scanning = false;
          _scanError =
              'Photo analysis failed. Try again or enter the food manually.';
        });
      }
    }
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _BarcodeScanScreen()),
    );
    if (barcode == null || !mounted) return;
    setState(() => _scanning = true);
    try {
      final result = await FoodScanService.lookupBarcode(barcode);
      if (!mounted) return;
      if (result != null) {
        _applyResult(result);
      } else {
        _showError('Product not found. Try manual entry.');
        setState(() => _scanning = false);
      }
    } catch (_) {
      if (mounted) {
        _showError('Lookup failed. Please try again.');
        setState(() => _scanning = false);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final presets = quickAddPresets[_meal] ?? [];

    return Container(
      decoration: BoxDecoration(
        color: th.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: th.colorScheme.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add food',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),

              // ── Mode selector ─────────────────────────────────────────────
              Row(
                children: [
                  _ModeButton(
                    label: '📷  Scan',
                    selected: _mode == _ScanMode.scan,
                    onTap: () {
                      setState(() => _mode = _ScanMode.scan);
                      _scanWithCamera();
                    },
                  ),
                  const SizedBox(width: 8),
                  _ModeButton(
                    label: '🏷️  Barcode',
                    selected: _mode == _ScanMode.barcode,
                    onTap: () {
                      setState(() => _mode = _ScanMode.barcode);
                      _scanBarcode();
                    },
                  ),
                  const SizedBox(width: 8),
                  _ModeButton(
                    label: '✏️  Manual',
                    selected: _mode == _ScanMode.manual,
                    onTap: () => setState(() {
                      _mode = _ScanMode.manual;
                      _scanError = null;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Scanning indicator ────────────────────────────────────────
              if (_scanning) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: th.cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: th.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _mode == _ScanMode.barcode
                            ? 'Looking up product…'
                            : 'Analyzing with AI…',
                        style: TextStyle(
                          fontSize: 13,
                          color: th.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              if (_scanError != null) ...[
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF2DD),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF8A5A00),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          _scanError!,
                          style: const TextStyle(fontSize: 12, height: 1.35),
                        ),
                      ),
                      TextButton(
                        onPressed: _scanning ? null : _scanWithCamera,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Scan result card ──────────────────────────────────────────
              if (_baseResult != null && !_scanning) ...[
                _ScanResultCard(
                  result: _baseResult!,
                  quantity: _quantity,
                  onQuantityChanged: _updateQuantity,
                  theme: th,
                ),
                const SizedBox(height: 14),
              ],

              // ── Meal selector ─────────────────────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _mealOptions.map((m) {
                    final sel = _meal == m;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _meal = m),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: sel
                                ? th.colorScheme.primary
                                : th.colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _mealLabel(m),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: sel
                                  ? th.colorScheme.onPrimary
                                  : th.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // ── Quick add presets (only in manual mode without a result) ──
              if (presets.isNotEmpty && _baseResult == null) ...[
                Text(
                  'Quick add',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: th.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: presets.map((p) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => _quickAdd(p),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: th.cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: th.colorScheme.onSurface.withValues(
                                  alpha: 0.1,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${p.calories} cal',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: th.colorScheme.onSurface.withValues(
                                      alpha: 0.45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // ── Food name field ───────────────────────────────────────────
              TextField(
                controller: _nameCtrl,
                autofocus: _mode == _ScanMode.manual && _baseResult == null,
                decoration: InputDecoration(
                  hintText: 'Food name',
                  filled: true,
                  fillColor: th.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Calories field ────────────────────────────────────────────
              TextField(
                controller: _calCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: 'Calories',
                  filled: true,
                  fillColor: th.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── Macros toggle ─────────────────────────────────────────────
              GestureDetector(
                onTap: () => setState(() => _showMacros = !_showMacros),
                child: Row(
                  children: [
                    Icon(
                      _showMacros ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: th.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _showMacros ? 'Hide macros' : '+ Add macros',
                      style: TextStyle(
                        fontSize: 13,
                        color: th.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (_showMacros) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MacroInput(
                        ctrl: _proteinCtrl,
                        label: 'Protein (g)',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MacroInput(ctrl: _carbsCtrl, label: 'Carbs (g)'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MacroInput(ctrl: _fatCtrl, label: 'Fat (g)'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: th.colorScheme.primary,
                    foregroundColor: th.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                  ),
                  child: const Text(
                    'Add to log',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mode button ────────────────────────────────────────────────────────────

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? th.colorScheme.primary
                : th.colorScheme.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected
                  ? th.colorScheme.onPrimary
                  : th.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Scan result card ───────────────────────────────────────────────────────

class _ScanResultCard extends StatelessWidget {
  final FoodScanResult result;
  final double quantity;
  final ValueChanged<double> onQuantityChanged;
  final ThemeData theme;

  const _ScanResultCard({
    required this.result,
    required this.quantity,
    required this.onQuantityChanged,
    required this.theme,
  });

  String _fmt(double v) => v % 1 == 0 ? '${v.toInt()}' : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final scaled = result.scaled(quantity);
    final th = theme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: th.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: th.colorScheme.primary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: th.colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${scaled.calories} cal',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: th.colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            result.serving,
            style: TextStyle(
              fontSize: 12,
              color: th.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          if (scaled.protein > 0 || scaled.carbs > 0 || scaled.fat > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (scaled.protein > 0)
                  _ScanMacroPill('${_fmt(scaled.protein)}g P', th),
                if (scaled.carbs > 0) ...[
                  const SizedBox(width: 6),
                  _ScanMacroPill('${_fmt(scaled.carbs)}g C', th),
                ],
                if (scaled.fat > 0) ...[
                  const SizedBox(width: 6),
                  _ScanMacroPill('${_fmt(scaled.fat)}g F', th),
                ],
              ],
            ),
          ],
          const SizedBox(height: 12),
          // Quantity adjuster
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Servings:',
                style: TextStyle(
                  fontSize: 13,
                  color: th.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 12),
              _QtyButton(
                icon: Icons.remove,
                enabled: quantity > 0.5,
                onTap: () => onQuantityChanged(
                  double.parse((quantity - 0.5).toStringAsFixed(1)),
                ),
                theme: th,
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 40,
                child: Text(
                  _fmt(quantity),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _QtyButton(
                icon: Icons.add,
                enabled: quantity < 5,
                onTap: () => onQuantityChanged(
                  double.parse((quantity + 0.5).toStringAsFixed(1)),
                ),
                theme: th,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScanMacroPill extends StatelessWidget {
  final String label;
  final ThemeData th;
  const _ScanMacroPill(this.label, this.th);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: th.colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: th.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final ThemeData theme;
  const _QtyButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.colorScheme.onSurface.withValues(alpha: 0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}

class _MacroInput extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;

  const _MacroInput({required this.ctrl, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      decoration: InputDecoration(
        hintText: label,
        filled: true,
        fillColor: Theme.of(context).cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}

// ── Barcode scanner screen ─────────────────────────────────────────────────

class _BarcodeScanScreen extends StatefulWidget {
  const _BarcodeScanScreen();

  @override
  State<_BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<_BarcodeScanScreen> {
  late final MobileScannerController _ctrl;
  bool _detected = false;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _ctrl = MobileScannerController(autoStart: false);
    _startCamera();
  }

  Future<void> _startCamera() async {
    try {
      await _ctrl.start();
    } on MobileScannerException catch (e) {
      if (mounted && e.errorCode == MobileScannerErrorCode.permissionDenied) {
        setState(() => _permissionDenied = true);
      }
    } catch (_) {
      if (mounted) setState(() => _permissionDenied = true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Scan Barcode'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.camera_alt, color: Colors.white54, size: 56),
                const SizedBox(height: 20),
                const Text(
                  'Camera access required',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Go to Settings → Kloudy → Camera and enable access, then come back.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: () => _ctrl.stop().then((_) => _startCamera()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                  ),
                  child: const Text(
                    'Try again',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan Barcode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _ctrl.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _ctrl,
            errorBuilder: (context, error) {
              if (error.errorCode == MobileScannerErrorCode.permissionDenied &&
                  !_permissionDenied) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => setState(() => _permissionDenied = true),
                );
              }
              return const SizedBox.shrink();
            },
            onDetect: (BarcodeCapture capture) {
              if (_detected) return;
              final value = capture.barcodes.firstOrNull?.rawValue;
              if (value != null) {
                _detected = true;
                Navigator.of(context).pop(value);
              }
            },
          ),
          // Targeting frame
          Center(
            child: Container(
              width: 260,
              height: 140,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Point camera at barcode',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Log weight sheet ───────────────────────────────────────────────────────

class _LogWeightSheet extends StatefulWidget {
  final double currentWeight;

  const _LogWeightSheet({required this.currentWeight});

  @override
  State<_LogWeightSheet> createState() => _LogWeightSheetState();
}

class _LogWeightSheetState extends State<_LogWeightSheet> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.currentWeight > 0
          ? widget.currentWeight.toStringAsFixed(1)
          : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Today's weight",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ctrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                decoration: InputDecoration(
                  hintText: 'Weight in lbs',
                  suffixText: 'lbs',
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    final w = double.tryParse(_ctrl.text);
                    if (w != null && w > 0) Navigator.pop(context, w);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
