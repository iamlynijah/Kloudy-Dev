import 'package:flutter/material.dart';

/// Two-question mindset unlock shown when the user unlocks the Mindset tab.
/// Returns Map<String, dynamic> with answers via Navigator.pop.
class MindsetUnlockScreen extends StatefulWidget {
  const MindsetUnlockScreen({super.key});

  @override
  State<MindsetUnlockScreen> createState() => _MindsetUnlockScreenState();
}

class _MindsetUnlockScreenState extends State<MindsetUnlockScreen> {
  int _step = 0;
  final Set<String> _challenges = {};
  final Set<String> _suffers = {};

  static const _challengeOptions = [
    'Stress',
    'Anxiety',
    'Burnout',
    'Confidence',
    'Motivation',
    'Work-life balance',
  ];

  static const _suffersOptions = [
    'Sleep',
    'Exercise',
    'Healthy eating',
    'Budgeting',
    'Self-care',
  ];

  static const _titles = ['What challenges you most?', 'What suffers first?'];
  static const _subtitles = [
    "On your mental health journey — pick all that apply.",
    "When life gets busy, what usually goes first?",
  ];

  void _next() {
    if (_step == 0 && _challenges.isEmpty) return;
    if (_step < 1) {
      setState(() => _step++);
    } else {
      Navigator.pop(context, {
        'mental_challenges': _challenges.toList(),
        'mental_first_to_suffer': _suffers.toList(),
      });
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _step == 0 ? _challengeOptions : _suffersOptions;
    final selected = _step == 0 ? _challenges : _suffers;

    return Scaffold(
      backgroundColor: null, // inherits from theme
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _back,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Icon(
                            _step > 0 ? Icons.arrow_back_ios : Icons.close,
                            size: 18,
                          ),
                        ),
                      ),
                      Row(
                        children: List.generate(2, (i) {
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
                    _titles[_step],
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _subtitles[_step],
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Options
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: options.map((opt) {
                    final sel = selected.contains(opt);
                    return GestureDetector(
                      onTap: () => setState(() {
                        sel ? selected.remove(opt) : selected.add(opt);
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? Colors.black : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          opt,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: sel ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            // CTA
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
                    _step == 1 ? "Let's go" : 'Continue',
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
