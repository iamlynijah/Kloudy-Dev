import 'package:flutter/material.dart';
import '../theme/kloudy_theme.dart';
import '../services/supabase_service.dart';

/// One calm index for the practical parts of life Kloudy helps users manage.
class MyLifeScreen extends StatelessWidget {
  final ValueChanged<int> onOpenSection;

  const MyLifeScreen({super.key, required this.onOpenSection});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
        children: [
          const Text(
            'MY LIFE',
            style: TextStyle(
              color: kKloudyBlue,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.7,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'The things you’re\nfiguring out.',
            style: TextStyle(
              color: kInk,
              fontSize: 32,
              height: 1.08,
              letterSpacing: -1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'One place for the questions, plans, and little wins that make up everyday life.',
            style: TextStyle(color: kDimText, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          _streaksPanel(context),
          const SizedBox(height: 25),
          const Text(
            'YOUR SPACES',
            style: TextStyle(
              color: kDimText,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          _spaceCard(
            context,
            index: 0,
            icon: Icons.favorite_border_rounded,
            title: 'Health & care',
            subtitle: 'Appointments, sleep, movement, and how you feel.',
            accent: const Color(0xFFF7E9EE),
          ),
          _spaceCard(
            context,
            index: 1,
            icon: Icons.restaurant_outlined,
            title: 'Food & nutrition',
            subtitle: 'Build food habits that fit your real life.',
            accent: const Color(0xFFFFF0DA),
          ),
          _spaceCard(
            context,
            index: 2,
            icon: Icons.account_balance_wallet_outlined,
            title: 'Money',
            subtitle: 'Understand your budget, bills, and goals.',
            accent: const Color(0xFFE2F4F0),
          ),
          _spaceCard(
            context,
            index: 3,
            icon: Icons.spa_outlined,
            title: 'Mindset & routines',
            subtitle: 'Make room for reflection and steady routines.',
            accent: const Color(0xFFEAE8FF),
          ),
        ],
      ),
    );
  }

  Widget _streaksPanel(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: kKloudyNavy,
      borderRadius: BorderRadius.circular(23),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [kKloudyNavy, Color(0xFF343A72)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: kKloudyCyan.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.hub_outlined, color: kKloudyCyan),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your streaks',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'A little consistency adds up.',
                    style: TextStyle(
                      color: Color(0xFFCFD2E8),
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FutureBuilder<Map<String, dynamic>?>(
          future: SupabaseService.fetchHealthData(),
          builder: (context, snapshot) {
            final streaks = (snapshot.data?['streaks'] as List<dynamic>? ?? []);
            if (streaks.isEmpty) {
              return const Text(
                'Add a habit in Health & care to start your first streak.',
                style: TextStyle(color: Color(0xFFCFD2E8), fontSize: 11.5),
              );
            }
            return Wrap(
              spacing: 7,
              runSpacing: 7,
              children: streaks.map((raw) {
                final streak = raw as Map;
                final name = streak['name'] as String? ?? 'Habit';
                final weeks = (streak['current_streak'] as num? ?? 0).toInt();
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '🔥 $name · $weeks ${streak['cadence'] == 'weekly' ? 'weeks' : 'days'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => onOpenSection(0),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
            label: const Text('Add friend'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ),
      ],
    ),
  );

  Widget _spaceCard(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: kCard,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => onOpenSection(index),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: kInk, size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: kInk,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: kDimText,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: kDimText,
                size: 15,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A community-shaped learning space: real questions, answered without shame.
class CommonsScreen extends StatelessWidget {
  final ValueChanged<String> onAskKloudy;
  final Set<String> goals;

  const CommonsScreen({
    super.key,
    required this.onAskKloudy,
    this.goals = const <String>{},
  });

  (String, String, String, IconData, Color, String) get _personalizedPrompt {
    if (goals.contains('lose_weight') ||
        goals.contains('build_muscle') ||
        goals.contains('improve_nutrition')) {
      return (
        'What’s an easy dinner that fits my goals?',
        goals.contains('lose_weight')
            ? 'Try a filling, high-protein dinner that keeps calories in mind and uses affordable ingredients.'
            : 'Try a filling, high-protein dinner that is simple to make on a busy day.',
        goals.contains('lose_weight')
            ? 'Suggest a low-calorie, high-protein dinner that is affordable, satisfying, and easy to make. Give me a recipe and ingredient swaps.'
            : 'Suggest an affordable high-protein dinner recipe that is easy to make. Include simple ingredient swaps.',
        Icons.restaurant_outlined,
        kChipGold,
        'FOOD & NUTRITION',
      );
    }
    if (goals.contains('save_money') ||
        goals.contains('pay_off_debt') ||
        goals.contains('spend_more_intentionally')) {
      return (
        'How do I make my money stretch?',
        'Get a simple meal idea and a plan for spending less on food this week.',
        'Help me plan affordable, nourishing dinners for this week. Keep the ingredients flexible and share a short grocery list.',
        Icons.account_balance_wallet_outlined,
        kChipSage,
        'MONEY & FOOD',
      );
    }
    if (goals.contains('stay_on_top_of_healthcare')) {
      return (
        'What do I say when I call a clinic?',
        'A simple appointment script can make that first call easier.',
        'Help me prepare to make a doctor’s appointment. Give me a simple script and what information to have ready.',
        Icons.medical_services_outlined,
        kChipBlush,
        'HEALTH & CARE',
      );
    }
    return (
      'How do I make a routine that sticks?',
      'Start with a week that fits your actual energy and commitments.',
      'Help me create a realistic weekly routine. Ask me about my commitments and energy before suggesting a plan.',
      Icons.calendar_month_outlined,
      kChipIndigo,
      'ROUTINES',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kKloudyBlue, kKloudyCyan],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.diversity_3_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KLOUDY COMMUNITY',
                    style: TextStyle(
                      color: kDimText,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  Text(
                    'The Commons',
                    style: TextStyle(
                      color: kInk,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE9E8FF), Color(0xFFF8EDE7)],
              ),
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A softer place\nto start.',
                  style: TextStyle(
                    color: kInk,
                    fontSize: 29,
                    height: 1.08,
                    letterSpacing: -0.9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'A lot of us are learning the basics as adults. Bring the question; leave with a little more clarity.',
                  style: TextStyle(color: kDimText, fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            'QUESTIONS WORTH ASKING',
            style: TextStyle(
              color: kDimText,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 9),
            decoration: BoxDecoration(
              color: kChipIndigo.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: kKloudyBlue, size: 17),
                SizedBox(width: 8),
                Text(
                  'PICKED FOR YOUR GOALS',
                  style: TextStyle(
                    color: kKloudyBlue,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          _questionCard(
            icon: _personalizedPrompt.$4,
            tint: _personalizedPrompt.$5,
            title: '“${_personalizedPrompt.$1}”',
            detail: _personalizedPrompt.$2,
            prompt: _personalizedPrompt.$3,
          ),
          _questionCard(
            icon: Icons.payments_outlined,
            tint: const Color(0xFFE2F4F0),
            title: '“What even is a budget?”',
            detail:
                'Start with what comes in, what has to go out, and what you want to save.',
            prompt:
                'Explain what a budget is in plain language. Help me make a simple first budget without judging my spending.',
          ),
          _questionCard(
            icon: Icons.medical_services_outlined,
            tint: const Color(0xFFF7E9EE),
            title: '“How do I make a doctor’s appointment?”',
            detail:
                'A simple script can make that first call feel less intimidating.',
            prompt:
                'Help me prepare to make a doctor’s appointment. Give me a simple script and what information to have ready.',
          ),
          _questionCard(
            icon: Icons.calendar_month_outlined,
            tint: const Color(0xFFEAE8FF),
            title: '“How do I make a routine that sticks?”',
            detail: 'Build a week around your actual energy and commitments.',
            prompt:
                'Help me create a realistic weekly routine. Ask me about my commitments and energy before suggesting a plan.',
          ),
          const SizedBox(height: 18),
          const Text(
            'Your question can be the starting point.',
            style: TextStyle(
              color: kInk,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'No one has to have it all figured out to belong here.',
            style: TextStyle(color: kDimText, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _questionCard({
    required IconData icon,
    required Color tint,
    required String title,
    required String detail,
    required String prompt,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: kCard,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => onAskKloudy(prompt),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 41,
                height: 41,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: kInk, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: kInk,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: kDimText,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.north_east_rounded,
                color: kKloudyBlue,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
