import 'package:flutter/material.dart';

/// Lightweight finance goal questionnaire shown when a user unlocks
/// the Finance tab after not selecting financial goals in initial onboarding.
/// Returns a Map<String, dynamic> with goal flags and answers via Navigator.pop.
class FinanceUnlockScreen extends StatefulWidget {
  const FinanceUnlockScreen({super.key});

  @override
  State<FinanceUnlockScreen> createState() => _FinanceUnlockScreenState();
}

class _FinanceUnlockScreenState extends State<FinanceUnlockScreen> {
  int _step = 0;

  // Step 0: goal selection
  final Set<String> _goals = {};

  // Step 1: conditional follow-ups (shown only for relevant goals)
  double _savingsTarget = 5000;
  double _debtAmount = 10000;
  double _monthlyIncome = 3000;
  double _spendingBudget = 2000;
  final Set<String> _hardCategories = {};

  static final _goalOptions = [
    ('save_money', 'Build savings', Icons.savings),
    ('pay_off_debt', 'Pay off debt', Icons.credit_card),
    ('spend_more_intentionally', 'Budget better', Icons.account_balance_wallet),
    ('increase_income', 'Increase income', Icons.trending_up),
  ];

  static const _categoryOptions = [
    'Dining out',
    'Shopping',
    'Entertainment',
    'Subscriptions',
    'Travel',
    'Impulse purchases',
  ];

  bool get _hasStep1 =>
      _goals.contains('save_money') ||
      _goals.contains('pay_off_debt') ||
      _goals.contains('spend_more_intentionally') ||
      _goals.contains('increase_income');

  int get _totalSteps => _hasStep1 ? 2 : 1;

  void _next() {
    if (_step == 0 && _goals.isEmpty) return;
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

  void _finish() {
    Navigator.pop(context, {
      'goals': _goals.toList(),
      'savings_target': _savingsTarget.round(),
      'debt_amount': _debtAmount.round(),
      'monthly_income': _monthlyIncome.round(),
      'spending_budget': _spendingBudget.round(),
      'hard_categories': _hardCategories.toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
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
                        children: List.generate(_totalSteps, (i) {
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
                    _step == 0
                        ? 'Financial goals'
                        : 'A few quick details',
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _step == 0
                        ? "What are you working toward? Pick all that apply."
                        : "Helps us set up your budget correctly.",
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: _step == 0 ? _buildGoalStep() : _buildDetailsStep(),
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
                    _step == _totalSteps - 1 ? 'Continue' : 'Next',
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

  Widget _buildGoalStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: _goalOptions.map((opt) {
          final sel = _goals.contains(opt.$1);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => setState(() {
                sel ? _goals.remove(opt.$1) : _goals.add(opt.$1);
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: sel ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(children: [
                  Icon(opt.$3,
                      size: 20,
                      color: sel ? Colors.white : Colors.black),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      opt.$2,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  if (sel)
                    Icon(Icons.check_circle,
                        color: Colors.white.withOpacity(0.8), size: 18),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_goals.contains('save_money')) ...[
            _SectionLabel('Savings target'),
            const SizedBox(height: 8),
            _MoneyDisplay(value: _savingsTarget),
            Slider(
              value: _savingsTarget.clamp(0, 50000),
              min: 0,
              max: 50000,
              divisions: 100,
              activeColor: Colors.black,
              onChanged: (v) => setState(() => _savingsTarget = v),
            ),
            const SizedBox(height: 20),
          ],
          if (_goals.contains('pay_off_debt')) ...[
            _SectionLabel('Total debt to pay off'),
            const SizedBox(height: 8),
            _MoneyDisplay(value: _debtAmount),
            Slider(
              value: _debtAmount.clamp(0, 100000),
              min: 0,
              max: 100000,
              divisions: 100,
              activeColor: Colors.black,
              onChanged: (v) => setState(() => _debtAmount = v),
            ),
            const SizedBox(height: 20),
          ],
          if (_goals.contains('increase_income')) ...[
            _SectionLabel('Current monthly income'),
            const SizedBox(height: 8),
            _MoneyDisplay(value: _monthlyIncome),
            Slider(
              value: _monthlyIncome.clamp(0, 20000),
              min: 0,
              max: 20000,
              divisions: 100,
              activeColor: Colors.black,
              onChanged: (v) => setState(() => _monthlyIncome = v),
            ),
            const SizedBox(height: 20),
          ],
          if (_goals.contains('spend_more_intentionally')) ...[
            _SectionLabel('Ideal monthly spending budget'),
            const SizedBox(height: 8),
            _MoneyDisplay(value: _spendingBudget),
            Slider(
              value: _spendingBudget.clamp(0, 10000),
              min: 0,
              max: 10000,
              divisions: 100,
              activeColor: Colors.black,
              onChanged: (v) => setState(() => _spendingBudget = v),
            ),
            const SizedBox(height: 20),
            _SectionLabel('Hardest spending categories to control'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categoryOptions.map((c) {
                final sel = _hardCategories.contains(c);
                return GestureDetector(
                  onTap: () => setState(() {
                    sel
                        ? _hardCategories.remove(c)
                        : _hardCategories.add(c);
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: sel ? Colors.black : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      c,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: sel ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));
  }
}

class _MoneyDisplay extends StatelessWidget {
  final double value;
  const _MoneyDisplay({required this.value});

  @override
  Widget build(BuildContext context) {
    final formatted = _fmt(value.round());
    return Text(
      '\$$formatted',
      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
    );
  }

  static String _fmt(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
