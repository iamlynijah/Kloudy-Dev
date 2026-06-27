import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/nutrition_profile.dart';

class NutritionOnboardingScreen extends StatefulWidget {
  final double? initialWeight;
  final double? initialGoalWeight;
  final NutritionGoalType? initialGoalType;
  final int? initialAge;

  const NutritionOnboardingScreen({
    super.key,
    this.initialWeight,
    this.initialGoalWeight,
    this.initialGoalType,
    this.initialAge,
  });

  @override
  State<NutritionOnboardingScreen> createState() =>
      _NutritionOnboardingState();
}

class _NutritionOnboardingState extends State<NutritionOnboardingScreen> {
  int _step = 0;

  // Step 0: Goal
  NutritionGoalType _goalType = NutritionGoalType.loseFat;
  final _startWeightCtrl = TextEditingController();
  final _goalWeightCtrl = TextEditingController();
  double _paceLbsPerWeek = 1.0;

  // Step 1: Body
  int _heightFeet = 5;
  int _heightInches = 6;
  int _age = 25;
  String _sex = 'female';
  ActivityLevel _activityLevel = ActivityLevel.moderate;

  // Step 2: Eating
  final List<String> _dietStyles = [];
  final List<String> _sensitivities = [];
  int _mealsPerDay = 3;
  int _flexDaysPerWeek = 0;
  bool _trackAlcohol = false;

  // Step 3: Meds
  bool _takesMeds = false;
  final List<String> _selectedMeds = [];
  bool _medicationReminders = false;
  String _reminderFrequency = 'daily';
  List<String> _reminderTimes = ['08:00'];
  final List<String> _supplements = [];
  String _motivation = 'all';

  // Step 4: Targets (computed + editable)
  final _caloriesCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  int _waterCups = 8;
  bool _targetsComputed = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialWeight != null) {
      _startWeightCtrl.text = widget.initialWeight!.round().toString();
    }
    if (widget.initialGoalWeight != null) {
      _goalWeightCtrl.text = widget.initialGoalWeight!.round().toString();
    }
    if (widget.initialGoalType != null) {
      _goalType = widget.initialGoalType!;
    }
    if (widget.initialAge != null) {
      _age = widget.initialAge!;
    }
  }

  @override
  void dispose() {
    _startWeightCtrl.dispose();
    _goalWeightCtrl.dispose();
    _caloriesCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  void _computeTargets() {
    if (_targetsComputed) return;
    final startWeight = double.tryParse(_startWeightCtrl.text) ?? 160;
    final heightIn = (_heightFeet * 12 + _heightInches).toDouble();
    final calories = calculateCalorieGoal(
      weightLbs: startWeight,
      heightInches: heightIn,
      age: _age,
      sex: _sex,
      activityLevel: _activityLevel,
      goalType: _goalType,
      paceLbsPerWeek: _paceLbsPerWeek,
    );
    final macros = calculateMacros(
      calories: calories,
      weightLbs: startWeight,
      goalType: _goalType,
      dietStyles: _dietStyles,
    );
    _caloriesCtrl.text = '$calories';
    _proteinCtrl.text = '${macros.protein}';
    _carbsCtrl.text = '${macros.carbs}';
    _fatCtrl.text = '${macros.fat}';
    _targetsComputed = true;
  }

  void _next() {
    if (_step == 3) _computeTargets();
    if (_step < 4) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  void _addCustomSupplement() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add supplement'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration:
              const InputDecoration(hintText: 'e.g. Magnesium'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && !_supplements.contains(result)) {
      setState(() => _supplements.add(result));
    }
  }

  void _addCustomMedication() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add medication'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration:
              const InputDecoration(hintText: 'e.g. Lisinopril'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && !_selectedMeds.contains(result)) {
      setState(() => _selectedMeds.add(result));
    }
  }

  void _finish() {
    final startWeight = double.tryParse(_startWeightCtrl.text) ?? 160;
    final goalWeight = double.tryParse(_goalWeightCtrl.text) ?? startWeight;
    final heightIn = (_heightFeet * 12 + _heightInches).toDouble();

    final profile = NutritionProfile(
      goalType: _goalType,
      paceLbsPerWeek: _paceLbsPerWeek,
      startWeightLbs: startWeight,
      goalWeightLbs: goalWeight,
      heightInches: heightIn,
      sex: _sex,
      age: _age,
      activityLevel: _activityLevel,
      dietStyles: List.from(_dietStyles),
      foodSensitivities: List.from(_sensitivities),
      mealsPerDay: _mealsPerDay,
      flexDaysPerWeek: _flexDaysPerWeek,
      trackAlcohol: _trackAlcohol,
      medications: List.from(_selectedMeds),
      medicationReminders: _medicationReminders,
      reminderFrequency: _reminderFrequency,
      reminderTimes: List.from(_reminderTimes),
      supplements: List.from(_supplements),
      motivation: _motivation,
      calorieGoal: int.tryParse(_caloriesCtrl.text) ?? 2000,
      proteinGoal: int.tryParse(_proteinCtrl.text) ?? 150,
      carbGoal: int.tryParse(_carbsCtrl.text) ?? 200,
      fatGoal: int.tryParse(_fatCtrl.text) ?? 65,
      waterCupsGoal: _waterCups,
    );

    final today = _todayStr();

    Navigator.pop(context, {
      'profile': profile.toJson(),
      'current_weight': startWeight,
      'weight_log': [
        {'date': today, 'weight_lbs': startWeight}
      ],
      'food_logs': <String, dynamic>{},
      'water_log': <String, dynamic>{},
      'logging_streak': 0,
      'logging_streak_last_date': '',
    });
  }

  String _todayStr() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  static const _stepTitles = [
    'Your goal',
    'About you',
    'Eating style',
    'Medications',
    'Your plan',
  ];
  static const _stepSubtitles = [
    'What are you working toward?',
    'Helps us calculate your calorie needs.',
    'We\'ll tailor your suggestions around this.',
    'Optional — helps us give accurate guidance.',
    'Here\'s your personalized daily target.',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: null, // inherits from theme
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _step > 0 ? _back : () => Navigator.pop(context),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Icon(
                            _step > 0 ? Icons.arrow_back_ios : Icons.close,
                            size: 18,
                          ),
                        ),
                      ),
                      Row(
                        children: List.generate(5, (i) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.only(right: 6),
                            width: i == _step ? 20 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i <= _step
                                  ? Colors.black
                                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _stepTitles[_step],
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _stepSubtitles[_step],
                    style: TextStyle(
                        fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // ── Step content ──
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    0 => _GoalStep(
                        goalType: _goalType,
                        startWeightCtrl: _startWeightCtrl,
                        goalWeightCtrl: _goalWeightCtrl,
                        pace: _paceLbsPerWeek,
                        prefilledWeight: widget.initialWeight,
                        prefilledGoalWeight: widget.initialGoalWeight,
                        onGoalType: (t) => setState(() {
                          _goalType = t;
                          _targetsComputed = false;
                        }),
                        onPace: (p) => setState(() {
                          _paceLbsPerWeek = p;
                          _targetsComputed = false;
                        }),
                      ),
                    1 => _BodyStep(
                        heightFeet: _heightFeet,
                        heightInches: _heightInches,
                        age: _age,
                        sex: _sex,
                        activityLevel: _activityLevel,
                        ageProvided: widget.initialAge != null,
                        onFeet: (v) => setState(() {
                          _heightFeet = v;
                          _targetsComputed = false;
                        }),
                        onInches: (v) => setState(() {
                          _heightInches = v;
                          _targetsComputed = false;
                        }),
                        onAge: (v) => setState(() {
                          _age = v;
                          _targetsComputed = false;
                        }),
                        onSex: (v) => setState(() {
                          _sex = v;
                          _targetsComputed = false;
                        }),
                        onActivity: (v) => setState(() {
                          _activityLevel = v;
                          _targetsComputed = false;
                        }),
                      ),
                    2 => _EatingStep(
                        dietStyles: _dietStyles,
                        sensitivities: _sensitivities,
                        mealsPerDay: _mealsPerDay,
                        flexDays: _flexDaysPerWeek,
                        trackAlcohol: _trackAlcohol,
                        onToggleDiet: (s) => setState(() {
                          _dietStyles.contains(s)
                              ? _dietStyles.remove(s)
                              : _dietStyles.add(s);
                          _targetsComputed = false;
                        }),
                        onToggleSens: (s) => setState(() {
                          _sensitivities.contains(s)
                              ? _sensitivities.remove(s)
                              : _sensitivities.add(s);
                        }),
                        onMeals: (v) => setState(() => _mealsPerDay = v),
                        onFlex: (v) => setState(() => _flexDaysPerWeek = v),
                        onAlcohol: (v) => setState(() => _trackAlcohol = v),
                      ),
                    3 => _MedsStep(
                        takesMeds: _takesMeds,
                        selectedMeds: _selectedMeds,
                        reminders: _medicationReminders,
                        reminderFrequency: _reminderFrequency,
                        reminderTimes: _reminderTimes,
                        supplements: _supplements,
                        motivation: _motivation,
                        onTakesMeds: (v) =>
                            setState(() => _takesMeds = v),
                        onToggleMed: (v) => setState(() {
                          _selectedMeds.contains(v)
                              ? _selectedMeds.remove(v)
                              : _selectedMeds.add(v);
                        }),
                        onAddMedication: _addCustomMedication,
                        onReminders: (v) =>
                            setState(() => _medicationReminders = v),
                        onReminderFrequency: (freq) => setState(() {
                          _reminderFrequency = freq;
                          if (freq == 'twice_daily' &&
                              _reminderTimes.length < 2) {
                            _reminderTimes = [..._reminderTimes, '20:00'];
                          } else if (freq != 'twice_daily' &&
                              _reminderTimes.length > 1) {
                            _reminderTimes = [_reminderTimes.first];
                          }
                        }),
                        onReminderTime: (index, time) => setState(() {
                          if (index < _reminderTimes.length) {
                            _reminderTimes[index] = time;
                          }
                        }),
                        onToggleSupplement: (s) => setState(() {
                          _supplements.contains(s)
                              ? _supplements.remove(s)
                              : _supplements.add(s);
                        }),
                        onAddSupplement: _addCustomSupplement,
                        onMotivation: (v) => setState(() => _motivation = v),
                      ),
                    _ => _TargetsStep(
                        caloriesCtrl: _caloriesCtrl,
                        proteinCtrl: _proteinCtrl,
                        carbsCtrl: _carbsCtrl,
                        fatCtrl: _fatCtrl,
                        waterCups: _waterCups,
                        onWater: (v) => setState(() => _waterCups = v),
                      ),
                  },
                ),
              ),
            ),
            // ── CTA ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(29)),
                  ),
                  child: Text(
                    _step == 4 ? "Let's go" : 'Continue',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 0: Goal ───────────────────────────────────────────────────────────

class _GoalStep extends StatelessWidget {
  final NutritionGoalType goalType;
  final TextEditingController startWeightCtrl;
  final TextEditingController goalWeightCtrl;
  final double pace;
  final double? prefilledWeight;
  final double? prefilledGoalWeight;
  final void Function(NutritionGoalType) onGoalType;
  final void Function(double) onPace;

  const _GoalStep({
    required this.goalType,
    required this.startWeightCtrl,
    required this.goalWeightCtrl,
    required this.pace,
    this.prefilledWeight,
    this.prefilledGoalWeight,
    required this.onGoalType,
    required this.onPace,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Goal type
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: NutritionGoalType.values.map((t) {
              final sel = goalType == t;
              return GestureDetector(
                onTap: () => onGoalType(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? Colors.black : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    t.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          // Weight summary card (prefilled) or input fields
          if (prefilledWeight != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_outline, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    prefilledGoalWeight != null
                        ? '${prefilledWeight!.round()} lbs now  ·  ${prefilledGoalWeight!.round()} lbs goal'
                        : '${prefilledWeight!.round()} lbs current weight',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  'from setup',
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                ),
              ]),
            ),
          ] else ...[
            _FieldLabel('Current weight (lbs)'),
            const SizedBox(height: 8),
            _NumField(
                controller: startWeightCtrl,
                hint: 'e.g. 165',
                decimal: true),
            if (goalType.hasWeightGoal) ...[
              const SizedBox(height: 16),
              _FieldLabel('Goal weight (lbs)'),
              const SizedBox(height: 8),
              _NumField(
                  controller: goalWeightCtrl,
                  hint: 'e.g. 145',
                  decimal: true),
            ],
          ],
          // Pace picker — always shown when goal has a weight target
          if (goalType.hasWeightGoal) ...[
            const SizedBox(height: 20),
            _FieldLabel('How fast do you want to get there?'),
            const SizedBox(height: 10),
            ...[
              (0.5, 'Slow & steady', '0.5 lb/week — most sustainable'),
              (1.0, 'Moderate', '1 lb/week — recommended'),
              (1.5, 'Aggressive', '1.5 lb/week — requires a lot of discipline and consistency'),
            ].map((opt) {
              final sel = pace == opt.$1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => onPace(opt.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: sel ? Colors.black : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opt.$2,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: sel ? Colors.white : Colors.black,
                                ),
                              ),
                              Text(
                                opt.$3,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: sel
                                      ? Colors.white.withOpacity(0.65)
                                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (sel)
                          Icon(Icons.check_circle,
                              color: Colors.white.withOpacity(0.8), size: 18),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Step 1: Body ───────────────────────────────────────────────────────────

class _BodyStep extends StatelessWidget {
  final int heightFeet;
  final int heightInches;
  final int age;
  final String sex;
  final ActivityLevel activityLevel;
  final bool ageProvided;
  final void Function(int) onFeet;
  final void Function(int) onInches;
  final void Function(int) onAge;
  final void Function(String) onSex;
  final void Function(ActivityLevel) onActivity;

  const _BodyStep({
    required this.heightFeet,
    required this.heightInches,
    required this.age,
    required this.sex,
    required this.activityLevel,
    this.ageProvided = false,
    required this.onFeet,
    required this.onInches,
    required this.onAge,
    required this.onSex,
    required this.onActivity,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Height
          _FieldLabel('Height'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _Stepper(
                    label: 'ft',
                    value: heightFeet,
                    min: 4,
                    max: 7,
                    onChanged: onFeet)),
            const SizedBox(width: 12),
            Expanded(
                child: _Stepper(
                    label: 'in',
                    value: heightInches,
                    min: 0,
                    max: 11,
                    onChanged: onInches)),
          ]),
          if (!ageProvided) ...[
            const SizedBox(height: 20),
            _FieldLabel('Age'),
            const SizedBox(height: 10),
            _Stepper(label: 'years', value: age, min: 16, max: 80, onChanged: onAge),
          ],
          const SizedBox(height: 20),
          // Sex
          _FieldLabel('Biological sex (for calorie calculation)'),
          const SizedBox(height: 10),
          Row(children: [
            for (final opt in [('male', 'Male'), ('female', 'Female'), ('other', 'Other')])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onSex(opt.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: sex == opt.$1 ? Colors.black : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      opt.$2,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: sex == opt.$1 ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 20),
          // Activity level
          _FieldLabel('Activity level'),
          const SizedBox(height: 10),
          ...ActivityLevel.values.map((level) {
            final sel = activityLevel == level;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => onActivity(level),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: sel ? Colors.black : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(level.label,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: sel ? Colors.white : Colors.black)),
                          Text(level.description,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: sel
                                      ? Colors.white.withOpacity(0.6)
                                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                        ],
                      ),
                    ),
                    if (sel)
                      Icon(Icons.check_circle,
                          color: Colors.white.withOpacity(0.8), size: 18),
                  ]),
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Step 2: Eating ─────────────────────────────────────────────────────────

class _EatingStep extends StatelessWidget {
  final List<String> dietStyles;
  final List<String> sensitivities;
  final int mealsPerDay;
  final int flexDays;
  final bool trackAlcohol;
  final void Function(String) onToggleDiet;
  final void Function(String) onToggleSens;
  final void Function(int) onMeals;
  final void Function(int) onFlex;
  final void Function(bool) onAlcohol;

  const _EatingStep({
    required this.dietStyles,
    required this.sensitivities,
    required this.mealsPerDay,
    required this.flexDays,
    required this.trackAlcohol,
    required this.onToggleDiet,
    required this.onToggleSens,
    required this.onMeals,
    required this.onFlex,
    required this.onAlcohol,
  });

  static const _dietOptions = [
    ('standard', 'Standard'),
    ('high_protein', 'High protein'),
    ('keto', 'Keto'),
    ('vegetarian', 'Vegetarian'),
    ('vegan', 'Vegan'),
    ('if', 'Intermittent fasting'),
    ('halal', 'Halal'),
    ('kosher', 'Kosher'),
  ];

  static const _sensOptions = [
    'Dairy',
    'Gluten',
    'Tree nuts',
    'Eggs',
    'Soy',
    'Shellfish',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Diet style
          _FieldLabel('Eating pattern (pick all that apply)'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _dietOptions.map((opt) {
              final sel = dietStyles.contains(opt.$1);
              return _MultiChip(
                  label: opt.$2,
                  selected: sel,
                  onTap: () => onToggleDiet(opt.$1));
            }).toList(),
          ),
          const SizedBox(height: 20),
          // Sensitivities
          _FieldLabel('Food sensitivities'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _sensOptions.map((s) {
              final sel = sensitivities.contains(s);
              return _MultiChip(
                  label: s, selected: sel, onTap: () => onToggleSens(s));
            }).toList(),
          ),
          const SizedBox(height: 20),
          // Meals per day
          _FieldLabel('How do you prefer to eat?'),
          const SizedBox(height: 10),
          ...[
            (3, '3 meals/day', 'Breakfast, lunch & dinner'),
            (5, '4-5 smaller meals', 'More frequent, smaller portions'),
            (2, 'Intermittent fasting', 'Eating window — 16:8 or similar'),
          ].map((opt) {
            final sel = mealsPerDay == opt.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => onMeals(opt.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: sel ? Colors.black : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(opt.$2,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: sel ? Colors.white : Colors.black)),
                          Text(opt.$3,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: sel
                                      ? Colors.white.withOpacity(0.6)
                                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                        ])),
                    if (sel)
                      Icon(Icons.check_circle,
                          color: Colors.white.withOpacity(0.8), size: 18),
                  ]),
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
          // Flex days
          _FieldLabel('Flex days (eat at maintenance)'),
          const SizedBox(height: 10),
          Row(
            children: [0, 1, 2].map((n) {
              final sel = flexDays == n;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onFlex(n),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? Colors.black : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      n == 0 ? 'None' : '$n/week',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: sel ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Track alcohol
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
                color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: trackAlcohol,
              onChanged: onAlcohol,
              activeColor: Colors.black,
              title: const Text('Track alcohol calories',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: Text('Adds a Drinks section to your food log',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Step 3: Medications ────────────────────────────────────────────────────

class _MedsStep extends StatefulWidget {
  final bool takesMeds;
  final List<String> selectedMeds;
  final bool reminders;
  final String reminderFrequency;
  final List<String> reminderTimes;
  final List<String> supplements;
  final String motivation;
  final void Function(bool) onTakesMeds;
  final void Function(String) onToggleMed;
  final VoidCallback onAddMedication;
  final void Function(bool) onReminders;
  final void Function(String) onReminderFrequency;
  final void Function(int, String) onReminderTime;
  final void Function(String) onToggleSupplement;
  final VoidCallback onAddSupplement;
  final void Function(String) onMotivation;

  const _MedsStep({
    required this.takesMeds,
    required this.selectedMeds,
    required this.reminders,
    required this.reminderFrequency,
    required this.reminderTimes,
    required this.supplements,
    required this.motivation,
    required this.onTakesMeds,
    required this.onToggleMed,
    required this.onAddMedication,
    required this.onReminders,
    required this.onReminderFrequency,
    required this.onReminderTime,
    required this.onToggleSupplement,
    required this.onAddSupplement,
    required this.onMotivation,
  });

  static const _medOptions = [
    // Weight management
    'Ozempic', 'Wegovy', 'Mounjaro', 'Tirzepatide', 'Phentermine', 'Contrave',
    // Diabetes
    'Metformin', 'Insulin', 'Jardiance', 'Farxiga', 'Januvia', 'Trulicity',
    // Mental health
    'Antidepressant', 'Anti-anxiety', 'Mood stabilizer', 'ADHD medication',
    // Thyroid & hormones
    'Levothyroxine', 'Birth control', 'Testosterone', 'HRT / Estrogen',
    // Cardiovascular
    'Beta-blocker', 'ACE inhibitor', 'Statin',
    // Other
    'Blood thinner', 'Prednisone / Steroid', 'Other',
  ];

  static const _suppOptions = [
    'Creatine',
    'Protein powder',
    'Pre-workout',
    'Multivitamin',
    'Fish oil / Omega-3',
    'Vitamin D',
    'Vitamin B12',
    'Magnesium',
    'Collagen',
    'Zinc',
  ];

  static const _motivOptions = [
    ('looks', 'Look & feel better'),
    ('performance', 'Athletic performance'),
    ('health', 'Health reasons'),
    ('all', 'All of the above'),
  ];

  @override
  State<_MedsStep> createState() => _MedsStepState();
}

class _MedsStepState extends State<_MedsStep> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatTime(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$h:${minute.toString().padLeft(2, '0')} $ampm';
  }

  Future<void> _pickTime(BuildContext context, int index) async {
    final timeStr = index < widget.reminderTimes.length
        ? widget.reminderTimes[index]
        : (index == 0 ? '08:00' : '20:00');
    final parts = timeStr.split(':');
    final initial =
        TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    final picked =
        await showTimePicker(context: context, initialTime: initial);
    if (picked != null && mounted) {
      final str =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      widget.onReminderTime(index, str);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customMeds = widget.selectedMeds
        .where((m) => !_MedsStep._medOptions.contains(m))
        .toList();
    final customSupps = widget.supplements
        .where((s) => !_MedsStep._suppOptions.contains(s))
        .toList();
    final filtered = _query.isEmpty
        ? _MedsStep._medOptions
        : _MedsStep._medOptions
            .where((m) => m.toLowerCase().contains(_query))
            .toList();
    final filteredCustom = _query.isEmpty
        ? customMeds
        : customMeds
            .where((m) => m.toLowerCase().contains(_query))
            .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Medications yes/no ──
          _FieldLabel('Are you currently taking any medications?'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => widget.onTakesMeds(false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color:
                        !widget.takesMeds ? Colors.black : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text('No',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: !widget.takesMeds
                                ? Colors.white
                                : Colors.black)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => widget.onTakesMeds(true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color:
                        widget.takesMeds ? Colors.black : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text('Yes',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: widget.takesMeds
                                ? Colors.white
                                : Colors.black)),
                  ),
                ),
              ),
            ),
          ]),
          if (widget.takesMeds) ...[
            const SizedBox(height: 14),
            // Search field
            TextField(
              controller: _searchCtrl,
              onChanged: (v) =>
                  setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search medications...',
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...filtered.map((med) {
                  final sel = widget.selectedMeds.contains(med);
                  return _MultiChip(
                      label: med,
                      selected: sel,
                      onTap: () => widget.onToggleMed(med));
                }),
                ...filteredCustom.map((m) => _MultiChip(
                    label: m,
                    selected: true,
                    onTap: () => widget.onToggleMed(m))),
                if (_query.isEmpty)
                  GestureDetector(
                    onTap: widget.onAddMedication,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 14),
                          SizedBox(width: 4),
                          Text('Add',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            if (widget.selectedMeds.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 2),
                decoration: BoxDecoration(color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16)),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: widget.reminders,
                  onChanged: widget.onReminders,
                  activeColor: Colors.black,
                  title: const Text('Medication reminders',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: const Text('Get notified to take your meds',
                      style: TextStyle(fontSize: 12)),
                ),
              ),
              if (widget.reminders) ...[
                const SizedBox(height: 12),
                _FieldLabel('How often?'),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final opt in [
                        ('daily', 'Once daily'),
                        ('twice_daily', 'Twice daily'),
                        ('as_needed', 'As needed'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () =>
                                widget.onReminderFrequency(opt.$1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: widget.reminderFrequency == opt.$1
                                    ? Colors.black
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                opt.$2,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      widget.reminderFrequency == opt.$1
                                          ? Colors.white
                                          : Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.reminderFrequency != 'as_needed') ...[
                  const SizedBox(height: 12),
                  _FieldLabel(
                    widget.reminderFrequency == 'twice_daily'
                        ? 'Reminder times'
                        : 'Reminder time',
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _pickTime(context, 0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_outlined, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            widget.reminderFrequency == 'twice_daily'
                                ? 'Morning'
                                : 'Time',
                            style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                          ),
                          const Spacer(),
                          Text(
                            _formatTime(widget.reminderTimes.isNotEmpty
                                ? widget.reminderTimes[0]
                                : '08:00'),
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right,
                              size: 16,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                        ],
                      ),
                    ),
                  ),
                  if (widget.reminderFrequency == 'twice_daily') ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _pickTime(context, 1),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_outlined,
                                size: 18),
                            const SizedBox(width: 10),
                            Text(
                              'Evening',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                            ),
                            const Spacer(),
                            Text(
                              _formatTime(widget.reminderTimes.length > 1
                                  ? widget.reminderTimes[1]
                                  : '20:00'),
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right,
                                size: 16,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ],
          ],
          const SizedBox(height: 20),
          // ── Supplements ──
          _FieldLabel('Supplements (pick all that you take)'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._MedsStep._suppOptions.map((s) {
                final sel = widget.supplements.contains(s);
                return _MultiChip(
                    label: s,
                    selected: sel,
                    onTap: () => widget.onToggleSupplement(s));
              }),
              ...customSupps.map((s) => _MultiChip(
                  label: s,
                  selected: true,
                  onTap: () => widget.onToggleSupplement(s))),
              GestureDetector(
                onTap: widget.onAddSupplement,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(22),
                    border:
                        Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14),
                      SizedBox(width: 4),
                      Text('Add',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // ── Motivation ──
          _FieldLabel("What's your primary motivation?"),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _MedsStep._motivOptions.map((opt) {
              final sel = widget.motivation == opt.$1;
              return _MultiChip(
                  label: opt.$2,
                  selected: sel,
                  onTap: () => widget.onMotivation(opt.$1));
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Step 4: Targets ────────────────────────────────────────────────────────

class _TargetsStep extends StatelessWidget {
  final TextEditingController caloriesCtrl;
  final TextEditingController proteinCtrl;
  final TextEditingController carbsCtrl;
  final TextEditingController fatCtrl;
  final int waterCups;
  final void Function(int) onWater;

  const _TargetsStep({
    required this.caloriesCtrl,
    required this.proteinCtrl,
    required this.carbsCtrl,
    required this.fatCtrl,
    required this.waterCups,
    required this.onWater,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calorie card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily calories',
                    style: TextStyle(
                        fontSize: 13, color: Colors.white.withOpacity(0.6))),
                const SizedBox(height: 8),
                _EditableNumber(
                    controller: caloriesCtrl,
                    suffix: 'cal',
                    color: Colors.white,
                    fontSize: 36),
                const SizedBox(height: 4),
                Text('Edit to customize',
                    style: TextStyle(
                        fontSize: 12, color: Colors.white.withOpacity(0.4))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Macros row
          Row(
            children: [
              Expanded(
                  child: _MacroField(
                      label: 'Protein',
                      color: const Color(0xFFE8F5E9),
                      controller: proteinCtrl)),
              const SizedBox(width: 8),
              Expanded(
                  child: _MacroField(
                      label: 'Carbs',
                      color: const Color(0xFFFFF8E1),
                      controller: carbsCtrl)),
              const SizedBox(width: 8),
              Expanded(
                  child: _MacroField(
                      label: 'Fat',
                      color: const Color(0xFFFCE4EC),
                      controller: fatCtrl)),
            ],
          ),
          const SizedBox(height: 20),
          // Water goal
          _FieldLabel('Daily water goal'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              const Icon(Icons.water_drop_outlined, size: 20),
              const SizedBox(width: 12),
              Text('$waterCups cups / day',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500)),
              const Spacer(),
              _SmallStepper(
                  icon: Icons.remove,
                  onTap:
                      waterCups > 4 ? () => onWater(waterCups - 1) : null),
              const SizedBox(width: 8),
              _SmallStepper(
                  icon: Icons.add,
                  onTap:
                      waterCups < 16 ? () => onWater(waterCups + 1) : null),
            ]),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Numbers are calculated from your stats. Edit anything — you know your body best.',
                  style: TextStyle(
                      fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));
  }
}

class _NumField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool decimal;

  const _NumField({
    required this.controller,
    required this.hint,
    this.decimal = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType:
          TextInputType.numberWithOptions(decimal: decimal, signed: false),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(decimal ? r'[\d.]' : r'\d')),
      ],
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Theme.of(context).cardColor,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final void Function(int) onChanged;

  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        _SmallStepper(
            icon: Icons.remove,
            onTap: value > min ? () => onChanged(value - 1) : null),
        Expanded(
          child: Center(
            child: Text(
              '$value $label',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        _SmallStepper(
            icon: Icons.add,
            onTap: value < max ? () => onChanged(value + 1) : null),
      ]),
    );
  }
}

class _SmallStepper extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _SmallStepper({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: onTap != null ? Colors.black : Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}

class _MultiChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MultiChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}

class _MacroField extends StatelessWidget {
  final String label;
  final Color color;
  final TextEditingController controller;

  const _MacroField({
    required this.label,
    required this.color,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              suffix: Text('g',
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54))),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableNumber extends StatelessWidget {
  final TextEditingController controller;
  final String suffix;
  final Color color;
  final double fontSize;

  const _EditableNumber({
    required this.controller,
    required this.suffix,
    required this.color,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: color),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
            ),
          ),
        ),
        Text(
          ' $suffix',
          style: TextStyle(
              fontSize: 18,
              color: color.withOpacity(0.6),
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
