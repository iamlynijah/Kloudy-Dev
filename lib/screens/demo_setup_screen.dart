import 'package:flutter/material.dart';
import '../demo/demo_profile.dart';
import '../models/user_onboarding_data.dart';
import '../services/supabase_service.dart';
import '../theme/kloudy_theme.dart';
import '../widgets/kloudy_mark.dart';

class DemoSetupScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final bool saveToAccount;
  const DemoSetupScreen({
    super.key,
    required this.onComplete,
    this.saveToAccount = false,
  });

  @override
  State<DemoSetupScreen> createState() => _DemoSetupScreenState();
}

class _DemoSetupScreenState extends State<DemoSetupScreen> {
  final _name = TextEditingController();
  final Set<String> _selected = {'save_money', 'improve_nutrition'};
  int _step = 0;
  bool _saving = false;

  static const _pillars = <(String, String, IconData, Color)>[
    (
      'Money',
      'Build confidence and choices for your future.',
      Icons.account_balance_wallet_outlined,
      kChipSage,
    ),
    (
      'Health',
      'Learn care, food, and body basics without judgment.',
      Icons.favorite_border_rounded,
      kChipBlush,
    ),
    (
      'Wellness',
      'Create routines that support the life you want.',
      Icons.spa_outlined,
      kChipIndigo,
    ),
  ];

  static const _goals = <(String, String, IconData, String)>[
    (
      'save_money',
      'Feel better about budgeting and saving',
      Icons.savings_outlined,
      'Money',
    ),
    (
      'pay_off_debt',
      'Make a plan for debt',
      Icons.credit_card_outlined,
      'Money',
    ),
    (
      'spend_more_intentionally',
      'Make my money stretch',
      Icons.payments_outlined,
      'Money',
    ),
    (
      'stay_on_top_of_healthcare',
      'Feel comfortable getting care',
      Icons.medical_services_outlined,
      'Health',
    ),
    (
      'improve_nutrition',
      'Eat well in real life',
      Icons.restaurant_outlined,
      'Health',
    ),
    (
      'move_more',
      'Find movement that feels good',
      Icons.directions_walk_rounded,
      'Health',
    ),
    (
      'build_healthier_habits',
      'Build routines that stick',
      Icons.auto_awesome_outlined,
      'Wellness',
    ),
    (
      'improve_sleep',
      'Make sleep a little easier',
      Icons.nightlight_outlined,
      'Wellness',
    ),
    (
      'manage_stress',
      'Make space to reset',
      Icons.self_improvement_rounded,
      'Wellness',
    ),
  ];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await DemoProfile.save(displayName: _name.text, selectedGoals: _selected);
      if (widget.saveToAccount) {
        DemoProfile.isDemo = false;
        await SupabaseService.saveProfile(
          UserOnboardingData(
            name: DemoProfile.name,
            loseWeight: _selected.contains('lose_weight'),
            buildMuscle: _selected.contains('build_muscle'),
            improveNutrition: _selected.contains('improve_nutrition'),
            buildHealthierHabits: _selected.contains('build_healthier_habits'),
            saveMoney: _selected.contains('save_money'),
            payOffDebt: _selected.contains('pay_off_debt'),
            spendMoreIntentionally: _selected.contains(
              'spend_more_intentionally',
            ),
            increaseIncome: _selected.contains('increase_income'),
            improveMentalHealth: _selected.contains('manage_stress'),
            stayOnTopOfHealthcare: _selected.contains(
              'stay_on_top_of_healthcare',
            ),
            improveSleep: _selected.contains('improve_sleep'),
            answers: {
              'goals': _selected.toList(),
              'move_more': _selected.contains('move_more'),
            },
          ),
        );
      }
      widget.onComplete();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'We couldn’t save your setup. Check your connection and try again.',
            ),
          ),
        );
        setState(() => _saving = false);
      }
    }
  }

  void _next() {
    if (_step < 2)
      setState(() => _step++);
    else
      _start();
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Welcome to Kloudy',
      'What matters to you?',
      'Your path, all in one place',
    ];
    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  if (_step > 0)
                    IconButton(
                      onPressed: () => setState(() => _step--),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Back',
                    )
                  else
                    const SizedBox(width: 48),
                  const KloudyMark(size: 38),
                  const SizedBox(width: 10),
                  const Text(
                    'KLOUDY',
                    style: TextStyle(
                      color: kInk,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.7,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_step + 1} of 3',
                    style: const TextStyle(
                      color: kDimText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (_step + 1) / 3,
                  minHeight: 5,
                  backgroundColor: kBorder,
                  color: kKloudyBlue,
                ),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: ListView(
                  key: ValueKey(_step),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  children: [
                    Text(
                      titles[_step],
                      style: const TextStyle(
                        color: kInk,
                        fontSize: 29,
                        height: 1.1,
                        letterSpacing: -0.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      _step == 0
                          ? 'A warm place to learn the life skills many of us were never taught.'
                          : _step == 1
                          ? 'Pick what you want to make easier. You can change this any time.'
                          : 'Small skills can change what’s possible for you and the people who come after you.',
                      style: const TextStyle(
                        color: kDimText,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (_step == 0) ..._welcomeContent(),
                    if (_step == 1) ..._priorityContent(),
                    if (_step == 2) ..._pathContent(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: _saving ? null : _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: kKloudyBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _step == 2 ? 'Build my path' : 'Continue',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Local demo · Your setup stays on this device',
                    style: TextStyle(color: kDimText, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _welcomeContent() => [
    Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kKloudyNavy, Color(0xFF3D477F)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: kKloudyCyan, size: 23),
          SizedBox(height: 13),
          Text(
            'A stronger future starts with what you learn today.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'We’ll bring money, health, and everyday wellbeing into one clear, judgment-free space.',
            style: TextStyle(
              color: Color(0xFFD4D8ED),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 18),
    const Text(
      'YOUR WHOLE LIFE, IN ONE PLACE',
      style: TextStyle(
        color: kDimText,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    ),
    const SizedBox(height: 10),
    ..._pillars.map(_pillarTile),
    const SizedBox(height: 8),
    const Text(
      'What should we call you?',
      style: TextStyle(color: kInk, fontWeight: FontWeight.w700, fontSize: 15),
    ),
    const SizedBox(height: 9),
    TextField(
      controller: _name,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        hintText: 'Your name',
        prefixIcon: Icon(Icons.person_outline_rounded),
      ),
    ),
  ];

  List<Widget> _priorityContent() => [
    for (final pillar in ['Money', 'Health', 'Wellness']) ...[
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(
          pillar.toUpperCase(),
          style: const TextStyle(
            color: kKloudyBlue,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.3,
          ),
        ),
      ),
      ..._goals.where((g) => g.$4 == pillar).map(_goalTile),
    ],
  ];

  List<Widget> _pathContent() => [
    Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: kChipIndigo,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Row(
        children: [
          const Icon(Icons.route_rounded, color: kKloudyBlue, size: 25),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${_name.text.trim().isEmpty ? 'Your' : '${_name.text.trim()}’s'} path to generational wealth & health',
              style: const TextStyle(
                color: kInk,
                fontWeight: FontWeight.w800,
                fontSize: 17,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 15),
    _pathStep(
      '01',
      'MONEY',
      'Understand your money → make a plan → build savings and options.',
      Icons.account_balance_wallet_outlined,
      kChipSage,
    ),
    _pathConnector(),
    _pathStep(
      '02',
      'HEALTH',
      'Learn to find care, nourish yourself, and make health choices with confidence.',
      Icons.favorite_border_rounded,
      kChipBlush,
    ),
    _pathConnector(),
    _pathStep(
      '03',
      'WELLNESS',
      'Create routines for rest, resilience, and the life you want to keep building.',
      Icons.spa_outlined,
      kChipIndigo,
    ),
    const SizedBox(height: 15),
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: kBorder),
      ),
      child: const Text(
        'No overnight promises or one-size-fits-all rules. Kloudy helps you learn practical skills and take the next step at your pace.',
        style: TextStyle(color: kDimText, fontSize: 12, height: 1.5),
      ),
    ),
  ];

  Widget _pillarTile((String, String, IconData, Color) pillar) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: kCard,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: kBorder),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: pillar.$4,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(pillar.$3, color: kInk, size: 19),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pillar.$1,
                style: const TextStyle(
                  color: kInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                pillar.$2,
                style: const TextStyle(
                  color: kDimText,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _goalTile((String, String, IconData, String) goal) {
    final selected = _selected.contains(goal.$1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: kCard,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: () => setState(
            () => selected ? _selected.remove(goal.$1) : _selected.add(goal.$1),
          ),
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: selected ? kKloudyBlue : kBorder,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(goal.$3, size: 20, color: kKloudyBlue),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    goal.$2,
                    style: const TextStyle(
                      color: kInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 19,
                  color: selected ? kKloudyBlue : kBorder,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pathStep(
    String number,
    String title,
    String description,
    IconData icon,
    Color tint,
  ) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: kCard,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: kBorder),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: kInk, size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$number  $title',
                style: const TextStyle(
                  color: kKloudyBlue,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                style: const TextStyle(color: kInk, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _pathConnector() => Padding(
    padding: const EdgeInsets.only(left: 32),
    child: Container(width: 2, height: 12, color: kBorder),
  );
}
