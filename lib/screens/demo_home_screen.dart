import 'package:flutter/material.dart';
import '../demo/demo_profile.dart';
import '../theme/kloudy_theme.dart';
import '../widgets/kloudy_mark.dart';

class DemoHomeScreen extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  const DemoHomeScreen({super.key, required this.onNavigate});
  @override
  State<DemoHomeScreen> createState() => _DemoHomeScreenState();
}

class _DemoHomeScreenState extends State<DemoHomeScreen> {
  bool _guideOpen = false;
  String? _mood;
  final List<(String, bool)> _tasks = [
    ('Check what’s in the fridge', false),
    ('Move \$10 into savings', true),
    ('Pick a time for a walk', false),
  ];

  @override
  Widget build(BuildContext context) {
    final first = DemoProfile.name.split(' ').first;
    final focus = DemoProfile.goals.contains('save_money')
        ? 'money'
        : DemoProfile.goals.contains('improve_nutrition')
        ? 'food'
        : 'your next step';
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          Row(
            children: [
              const KloudyMark(size: 39),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KLOUDY',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                      color: kInk,
                    ),
                  ),
                  Text(
                    'YOUR LIFE, IN SYNC',
                    style: TextStyle(
                      fontSize: 9,
                      color: kDimText,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const _DemoBadge(),
            ],
          ),
          const SizedBox(height: 25),
          Text(
            _greeting(),
            style: const TextStyle(
              color: kDimText,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            first,
            style: const TextStyle(
              color: kInk,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'A few small things can make today feel easier.',
            style: TextStyle(color: kDimText, fontSize: 13),
          ),
          const SizedBox(height: 18),
          _guideCard(focus),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your day, at a glance',
                  style: TextStyle(
                    color: kInk,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              Text(
                'MON, SEP 22',
                style: TextStyle(
                  color: kDimText,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: _metric(
                  'TODAY',
                  '${_tasks.where((e) => e.$2).length}/${_tasks.length}',
                  'steps done',
                  kChipIndigo,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(
                  'MONEY',
                  '\$42',
                  'flexible this week',
                  kChipSage,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _metric('REST', '7.5h', 'last night', kChipGold)),
            ],
          ),
          const SizedBox(height: 14),
          _pathOverview(),
          const SizedBox(height: 15),
          _checkIn(),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Today’s plan',
                  style: TextStyle(
                    color: kInk,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _addTask,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              children: List.generate(_tasks.length, (i) {
                final task = _tasks[i];
                return CheckboxListTile(
                  value: task.$2,
                  onChanged: (value) =>
                      setState(() => _tasks[i] = (task.$1, value ?? false)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: kKloudyBlue,
                  title: Text(
                    task.$1,
                    style: TextStyle(
                      fontSize: 12,
                      color: task.$2 ? kDimText : kInk,
                      decoration: task.$2 ? TextDecoration.lineThrough : null,
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your life, all in one place',
            style: TextStyle(
              color: kInk,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _space(
                  'Health & care',
                  Icons.favorite_border_rounded,
                  kChipBlush,
                  () => widget.onNavigate(1),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _space(
                  'Food & nutrition',
                  Icons.restaurant_outlined,
                  kChipGold,
                  () => widget.onNavigate(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _space(
                  'Money',
                  Icons.account_balance_wallet_outlined,
                  kChipSage,
                  () => widget.onNavigate(3),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _space(
                  'Routines',
                  Icons.spa_outlined,
                  kChipIndigo,
                  () => widget.onNavigate(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12
        ? 'GOOD MORNING'
        : h < 17
        ? 'GOOD AFTERNOON'
        : 'GOOD EVENING';
  }

  Widget _pathOverview() => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: kCard,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: kBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'YOUR PATH TO GENERATIONAL WEALTH & HEALTH',
          style: TextStyle(
            color: kKloudyBlue,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Build skills for the things that matter to you.',
          style: TextStyle(
            color: kInk,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _pathPillar(
                'Money',
                'Learn · plan · grow',
                Icons.account_balance_wallet_outlined,
                kChipSage,
                () => widget.onNavigate(3),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _pathPillar(
                'Health',
                'Care · nourish · move',
                Icons.favorite_border_rounded,
                kChipBlush,
                () => widget.onNavigate(1),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _pathPillar(
                'Wellness',
                'Rest · reset · repeat',
                Icons.spa_outlined,
                kChipIndigo,
                () => widget.onNavigate(4),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _pathPillar(
    String title,
    String steps,
    IconData icon,
    Color tint,
    VoidCallback onTap,
  ) => Material(
    color: tint.withValues(alpha: .55),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: kInk, size: 18),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                color: kInk,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              steps,
              maxLines: 2,
              style: const TextStyle(
                color: kDimText,
                fontSize: 8,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _guideCard(String focus) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [kKloudyNavy, Color(0xFF424B82)],
      ),
      borderRadius: BorderRadius.circular(23),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: kKloudyCyan, size: 17),
            SizedBox(width: 7),
            Text(
              'YOUR GUIDE, WHEN YOU WANT IT',
              style: TextStyle(
                color: Color(0xFFCFD9FF),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'You don’t have to\nfigure it out alone.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 23,
            height: 1.12,
            letterSpacing: -0.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your space is ready. Start with $focus, or ask about anything on your mind.',
          style: const TextStyle(
            color: Color(0xFFD4D8ED),
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.icon(
              onPressed: () => widget.onNavigate(5),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
              label: const Text('Talk to Kloudy'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7882FA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
            const SizedBox(width: 6),
            TextButton(
              onPressed: () => setState(() => _guideOpen = !_guideOpen),
              child: const Text(
                'Optional guide',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        if (_guideOpen)
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: Text(
              'Try asking: “What’s one easy $focus win I can do today?”',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .8),
                fontSize: 12,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _metric(String eyebrow, String value, String label, Color tint) =>
      Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                eyebrow,
                style: const TextStyle(
                  color: kInk,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .7,
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              value,
              style: const TextStyle(
                color: kInk,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              style: const TextStyle(color: kDimText, fontSize: 9, height: 1.3),
            ),
          ],
        ),
      );

  Widget _checkIn() => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: kCard,
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: kBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'A quick check-in',
          style: TextStyle(color: kInk, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        const Text(
          'How are you feeling today?',
          style: TextStyle(color: kDimText, fontSize: 11),
        ),
        const SizedBox(height: 11),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children:
              [
                    ('Low', '😔'),
                    ('Meh', '😕'),
                    ('Okay', '😐'),
                    ('Good', '🙂'),
                    ('Great', '😊'),
                  ]
                  .map(
                    (e) => GestureDetector(
                      onTap: () => setState(() => _mood = e.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 43,
                        height: 43,
                        decoration: BoxDecoration(
                          color: _mood == e.$1 ? kChipIndigo : kBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _mood == e.$1 ? kKloudyBlue : kBorder,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(e.$2, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  )
                  .toList(),
        ),
      ],
    ),
  );

  Widget _space(String title, IconData icon, Color tint, VoidCallback onTap) =>
      Material(
        color: kCard,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 18, color: kInk),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: kInk,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: kDimText,
                  size: 17,
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _addTask() async {
    final c = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a small step'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'What would help today?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (value != null && value.isNotEmpty && mounted)
      setState(() => _tasks.add((value, false)));
    c.dispose();
  }
}

class _DemoBadge extends StatelessWidget {
  const _DemoBadge();
  @override
  Widget build(BuildContext context) => const Chip(
    avatar: Icon(Icons.offline_bolt_rounded, size: 15, color: kKloudyBlue),
    label: Text(
      'DEMO',
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: .7,
      ),
    ),
    backgroundColor: kChipIndigo,
    side: BorderSide.none,
    visualDensity: VisualDensity.compact,
  );
}
