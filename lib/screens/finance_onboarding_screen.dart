import 'package:flutter/material.dart';
import '../models/anchor_bill.dart';
import '../models/finance_goal.dart';

class FinanceOnboardingScreen extends StatefulWidget {
  const FinanceOnboardingScreen({super.key});

  @override
  State<FinanceOnboardingScreen> createState() =>
      _FinanceOnboardingScreenState();
}

class _FinanceOnboardingScreenState extends State<FinanceOnboardingScreen> {
  int _step = 0;
  static const int _totalSteps = 5;

  // Step 0
  final Map<String, double> _bills = {};
  // Step 1
  final Map<String, double> _extras = {};
  // Step 2
  final TextEditingController _incomeCtrl = TextEditingController();
  IncomeFrequency _frequency = IncomeFrequency.biweekly;
  // Step 3 — name → {targetAmount|balance, targetMonths}
  final Map<String, Map<String, dynamic>> _savingsGoals = {};
  final Map<String, Map<String, dynamic>> _debts = {};

  // ── Computed ──────────────────────────────────────────────────────

  double get _paycheck =>
      double.tryParse(_incomeCtrl.text.replaceAll(',', '')) ?? 0;

  double get _monthlyIncome => _paycheck * _frequency.monthlyMultiplier;

  double get _totalBills => _bills.values.fold(0.0, (s, v) => s + v);

  double get _totalExtras => _extras.values.fold(0.0, (s, v) => s + v);

  double get _freeCash => _monthlyIncome - _totalBills - _totalExtras;

  List<FinanceGoal> get _goals => [
        ..._savingsGoals.entries.map((e) => FinanceGoal(
              id: 'goal-${e.key.toLowerCase().replaceAll(' ', '-')}',
              name: e.key,
              targetAmount: (e.value['targetAmount'] as double? ?? 0),
              targetMonths: (e.value['targetMonths'] as int? ?? 12),
            )),
        ..._debts.entries.map((e) => FinanceGoal(
              id: 'debt-${e.key.toLowerCase().replaceAll(' ', '-')}',
              name: e.key,
              targetAmount: (e.value['balance'] as double? ?? 0),
              targetMonths: (e.value['targetMonths'] as int? ?? 24),
              isDebt: true,
            )),
      ];

  double get _totalGoalContributions =>
      _goals.fold(0.0, (s, g) => s + g.suggestedMonthlyContribution);

  double get _spendingMoney => _freeCash - _totalGoalContributions;

  // ── Navigation ────────────────────────────────────────────────────

  void _next() {
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  void _finish() {
    final bills = _bills.entries
        .map((e) => AnchorBill(
              id: 'bill-${e.key.toLowerCase().replaceAll(' ', '-')}',
              name: e.key,
              monthlyAmount: e.value,
            ))
        .toList();
    final extras = _extras.entries
        .map((e) => RecurringExtra(
              id: 'extra-${e.key.toLowerCase().replaceAll(' ', '-')}',
              name: e.key,
              estimatedMonthlyAmount: e.value,
            ))
        .toList();
    Navigator.pop(context, {
      'bills': bills,
      'extras': extras,
      'monthlyIncome': _monthlyIncome,
      'incomeFrequency': _frequency,
      'goals': _goals,
    });
  }

  void _skip() {
    Navigator.pop(context, {
      'bills': <AnchorBill>[],
      'extras': <RecurringExtra>[],
      'monthlyIncome': 0.0,
      'incomeFrequency': IncomeFrequency.monthly,
      'goals': <FinanceGoal>[],
    });
  }

  // ── Custom add dialogs ────────────────────────────────────────────

  void _addCustomItem({required bool isBill}) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => _AddItemDialog(
        title: isBill ? 'Add a bill' : 'Add an extra',
        hint: isBill ? 'e.g. Storage unit' : 'e.g. Dog grooming',
        controller: ctrl,
        onConfirm: (name) => setState(() {
          if (isBill) _bills[name] = 0;
          else _extras[name] = 0;
        }),
      ),
    );
  }

  void _addCustomGoal({required bool isDebt}) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => _AddItemDialog(
        title: isDebt ? 'Add a debt' : 'Add a savings goal',
        hint: isDebt ? 'e.g. Furniture loan' : 'e.g. New laptop',
        controller: ctrl,
        onConfirm: (name) => setState(() {
          if (isDebt) {
            _debts[name] = {'balance': 0.0, 'targetMonths': 24};
          } else {
            _savingsGoals[name] = {'targetAmount': 0.0, 'targetMonths': 12};
          }
        }),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  void dispose() {
    _incomeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: null, // inherits from theme
      body: SafeArea(
        child: Column(
          children: [
            _OnboardingHeader(
              step: _step,
              totalSteps: _totalSteps,
              onBack: _step > 0 ? _back : null,
              onSkip: _skip,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                child: _buildStep(),
              ),
            ),
            _OnboardingCTA(
              label: _step == _totalSteps - 1 ? "Let's go" : 'Next',
              onTap: _next,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _ChipAmountStep(
          title: 'What are your monthly bills?',
          subtitle:
              'Fixed costs every month — rent, car, subscriptions.',
          presets: anchorBillPresets.map((p) => p.name).toList(),
          selected: _bills,
          amountLabel: 'How much per month?',
          onToggle: (name) => setState(() {
            if (_bills.containsKey(name)) _bills.remove(name);
            else _bills[name] = 0;
          }),
          onAmountChanged: (name, val) =>
              setState(() => _bills[name] = val),
          onAddCustom: () => _addCustomItem(isBill: true),
        );

      case 1:
        return _ChipAmountStep(
          title: 'Regular extras?',
          subtitle:
              'Not required, but things you spend on pretty routinely.',
          presets: recurringExtraPresets.map((p) => p.name).toList(),
          selected: _extras,
          amountLabel: 'Roughly how much per month?',
          onToggle: (name) => setState(() {
            if (_extras.containsKey(name)) _extras.remove(name);
            else _extras[name] = 0;
          }),
          onAmountChanged: (name, val) =>
              setState(() => _extras[name] = val),
          onAddCustom: () => _addCustomItem(isBill: false),
        );

      case 2:
        return _IncomeStep(
          controller: _incomeCtrl,
          frequency: _frequency,
          monthlyEquivalent: _monthlyIncome,
          onFrequencyChanged: (f) => setState(() => _frequency = f),
        );

      case 3:
        return _GoalsStep(
          savingsGoals: _savingsGoals,
          debts: _debts,
          onToggleSavings: (name) => setState(() {
            if (_savingsGoals.containsKey(name)) _savingsGoals.remove(name);
            else _savingsGoals[name] = {'targetAmount': 0.0, 'targetMonths': 12};
          }),
          onUpdateSavings: (name, key, val) => setState(() {
            _savingsGoals[name] ??= {};
            _savingsGoals[name]![key] = val;
          }),
          onToggleDebt: (name) => setState(() {
            if (_debts.containsKey(name)) _debts.remove(name);
            else _debts[name] = {'balance': 0.0, 'targetMonths': 24};
          }),
          onUpdateDebt: (name, key, val) => setState(() {
            _debts[name] ??= {};
            _debts[name]![key] = val;
          }),
          onAddCustomSavings: () => _addCustomGoal(isDebt: false),
          onAddCustomDebt: () => _addCustomGoal(isDebt: true),
        );

      case 4:
        return _SummaryStep(
          monthlyIncome: _monthlyIncome,
          totalBills: _totalBills,
          totalExtras: _totalExtras,
          freeCash: _freeCash,
          goals: _goals,
          totalGoalContributions: _totalGoalContributions,
          spendingMoney: _spendingMoney,
        );

      default:
        return const SizedBox();
    }
  }
}

// ─────────────────────────────────────────────
// SHARED HEADER + CTA
// ─────────────────────────────────────────────

class _OnboardingHeader extends StatelessWidget {
  final int step;
  final int totalSteps;
  final VoidCallback? onBack;
  final VoidCallback onSkip;

  const _OnboardingHeader({
    required this.step,
    required this.totalSteps,
    this.onBack,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack ?? () => Navigator.pop(context),
            child: Icon(
              onBack != null ? Icons.arrow_back : Icons.close,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          Row(
            children: List.generate(totalSteps, (i) {
              final active = i == step;
              final done = i < step;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: done || active ? Colors.black : Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const Spacer(),
          TextButton(
            onPressed: onSkip,
            child: Text('Skip',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45), fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

class _OnboardingCTA extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OnboardingCTA({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30)),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ADD ITEM DIALOG
// ─────────────────────────────────────────────

class _AddItemDialog extends StatelessWidget {
  final String title;
  final String hint;
  final TextEditingController controller;
  final void Function(String) onConfirm;

  const _AddItemDialog({
    required this.title,
    required this.hint,
    required this.controller,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          onPressed: () {
            final name = controller.text.trim();
            if (name.isNotEmpty) onConfirm(name);
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// SHARED WIDGETS: CHIP + ADD CHIP + AMOUNT ROW
// ─────────────────────────────────────────────

class _SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  final VoidCallback onTap;

  const _AddChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
            SizedBox(width: 6),
            Text('Add',
                style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54))),
          ],
        ),
      ),
    );
  }
}

class _AmountRow extends StatefulWidget {
  final String name;
  final double amount;
  final ValueChanged<double> onChanged;

  const _AmountRow(
      {required this.name, required this.amount, required this.onChanged});

  @override
  State<_AmountRow> createState() => _AmountRowState();
}

class _AmountRowState extends State<_AmountRow> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.amount == 0 ? '' : widget.amount.toStringAsFixed(0),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(widget.name,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          Text('\$',
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54))),
          SizedBox(
            width: 80,
            child: TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                hintText: '0',
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (v) =>
                  widget.onChanged(double.tryParse(v) ?? 0),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STEP 0 & 1: CHIP + AMOUNT
// ─────────────────────────────────────────────

class _ChipAmountStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> presets;
  final Map<String, double> selected;
  final String amountLabel;
  final void Function(String) onToggle;
  final void Function(String, double) onAmountChanged;
  final VoidCallback onAddCustom;

  const _ChipAmountStep({
    required this.title,
    required this.subtitle,
    required this.presets,
    required this.selected,
    required this.amountLabel,
    required this.onToggle,
    required this.onAmountChanged,
    required this.onAddCustom,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, height: 1.2)),
        const SizedBox(height: 10),
        Text(subtitle,
            style: TextStyle(
                fontSize: 15, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), height: 1.4)),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ...presets.map((name) => _SelectChip(
                  label: name,
                  selected: selected.containsKey(name),
                  onTap: () => onToggle(name),
                )),
            _AddChip(onTap: onAddCustom),
          ],
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text(amountLabel,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...selected.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AmountRow(
                  name: e.key,
                  amount: e.value,
                  onChanged: (v) => onAmountChanged(e.key, v),
                ),
              )),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────
// STEP 2: INCOME
// ─────────────────────────────────────────────

class _IncomeStep extends StatelessWidget {
  final TextEditingController controller;
  final IncomeFrequency frequency;
  final double monthlyEquivalent;
  final void Function(IncomeFrequency) onFrequencyChanged;

  const _IncomeStep({
    required this.controller,
    required this.frequency,
    required this.monthlyEquivalent,
    required this.onFrequencyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text("What's your take-home pay?",
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, height: 1.2)),
        const SizedBox(height: 10),
        Text("After taxes — this helps us do the real math.",
            style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54))),
        const SizedBox(height: 28),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          decoration: BoxDecoration(color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Text('\$',
                  style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '0',
                    hintStyle: TextStyle(color: Colors.black12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text('How often do you get paid?',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ...IncomeFrequency.values.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => onFrequencyChanged(f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: frequency == f
                        ? Colors.black
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          f.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: frequency == f
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      ),
                      if (frequency == f)
                        const Icon(Icons.check,
                            color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
            )),
        if (monthlyEquivalent > 0) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Text('✅', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Text(
                  "That's ~\$${monthlyEquivalent.toStringAsFixed(0)}/month",
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────
// STEP 3: GOALS & DEBT
// ─────────────────────────────────────────────

class _GoalsStep extends StatelessWidget {
  final Map<String, Map<String, dynamic>> savingsGoals;
  final Map<String, Map<String, dynamic>> debts;
  final void Function(String) onToggleSavings;
  final void Function(String, String, dynamic) onUpdateSavings;
  final void Function(String) onToggleDebt;
  final void Function(String, String, dynamic) onUpdateDebt;
  final VoidCallback onAddCustomSavings;
  final VoidCallback onAddCustomDebt;

  static const _savingsTimelines = [3, 6, 12, 18, 24, 36];
  static const _debtTimelines = [6, 12, 24, 36, 60];

  const _GoalsStep({
    required this.savingsGoals,
    required this.debts,
    required this.onToggleSavings,
    required this.onUpdateSavings,
    required this.onToggleDebt,
    required this.onUpdateDebt,
    required this.onAddCustomSavings,
    required this.onAddCustomDebt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text('What are you working toward?',
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, height: 1.2)),
        const SizedBox(height: 10),
        Text("We'll set up buckets and track your progress.",
            style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54))),
        const SizedBox(height: 28),

        // ── Savings ──
        const Text('Saving for',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ...savingsGoalPresets.map((name) => _SelectChip(
                  label: name,
                  selected: savingsGoals.containsKey(name),
                  onTap: () => onToggleSavings(name),
                )),
            _AddChip(onTap: onAddCustomSavings),
          ],
        ),
        ...savingsGoals.entries.map((e) => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _GoalDetailCard(
                key: ValueKey('savings-${e.key}'),
                name: e.key,
                isDebt: false,
                data: e.value,
                timelines: _savingsTimelines,
                onAmountChanged: (v) =>
                    onUpdateSavings(e.key, 'targetAmount', v),
                onMonthsChanged: (m) =>
                    onUpdateSavings(e.key, 'targetMonths', m),
              ),
            )),

        const SizedBox(height: 28),
        const Divider(),
        const SizedBox(height: 20),

        // ── Debt ──
        const Text('Also tackling debt?',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Pick any you want to pay off faster.',
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45))),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ...debtPresets.map((name) => _SelectChip(
                  label: name,
                  selected: debts.containsKey(name),
                  onTap: () => onToggleDebt(name),
                )),
            _AddChip(onTap: onAddCustomDebt),
          ],
        ),
        ...debts.entries.map((e) => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _GoalDetailCard(
                key: ValueKey('debt-${e.key}'),
                name: e.key,
                isDebt: true,
                data: e.value,
                timelines: _debtTimelines,
                onAmountChanged: (v) =>
                    onUpdateDebt(e.key, 'balance', v),
                onMonthsChanged: (m) =>
                    onUpdateDebt(e.key, 'targetMonths', m),
              ),
            )),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _GoalDetailCard extends StatefulWidget {
  final String name;
  final bool isDebt;
  final Map<String, dynamic> data;
  final List<int> timelines;
  final void Function(double) onAmountChanged;
  final void Function(int) onMonthsChanged;

  const _GoalDetailCard({
    super.key,
    required this.name,
    required this.isDebt,
    required this.data,
    required this.timelines,
    required this.onAmountChanged,
    required this.onMonthsChanged,
  });

  @override
  State<_GoalDetailCard> createState() => _GoalDetailCardState();
}

class _GoalDetailCardState extends State<_GoalDetailCard> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    final amountKey = widget.isDebt ? 'balance' : 'targetAmount';
    final amount = widget.data[amountKey] as double? ?? 0;
    _ctrl = TextEditingController(
        text: amount == 0 ? '' : amount.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _monthLabel(int m) {
    if (m < 12) return '${m}mo';
    final y = m ~/ 12;
    final left = m % 12;
    if (left == 0) return '${y}yr';
    return '${y}yr ${left}mo';
  }

  @override
  Widget build(BuildContext context) {
    final currentMonths =
        widget.data['targetMonths'] as int? ?? widget.timelines.first;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.name,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                widget.isDebt ? 'Balance: ' : 'Target: ',
                style: TextStyle(
                    fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
              ),
              const Text('\$',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _ctrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '0',
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  onChanged: (v) =>
                      widget.onAmountChanged(double.tryParse(v) ?? 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.isDebt ? 'Pay off in:' : 'Save by:',
            style: TextStyle(
                fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.timelines.map((months) {
              final selected = currentMonths == months;
              return GestureDetector(
                onTap: () => widget.onMonthsChanged(months),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.black
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _monthLabel(months),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.87),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STEP 4: SUMMARY / PLAN
// ─────────────────────────────────────────────

class _SummaryStep extends StatelessWidget {
  final double monthlyIncome;
  final double totalBills;
  final double totalExtras;
  final double freeCash;
  final List<FinanceGoal> goals;
  final double totalGoalContributions;
  final double spendingMoney;

  const _SummaryStep({
    required this.monthlyIncome,
    required this.totalBills,
    required this.totalExtras,
    required this.freeCash,
    required this.goals,
    required this.totalGoalContributions,
    required this.spendingMoney,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text("Here's your plan",
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
            "We'll track your progress and adjust as things change.",
            style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54))),
        const SizedBox(height: 24),

        // Income card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Monthly take-home',
                  style:
                      TextStyle(fontSize: 13, color: Colors.white60)),
              const SizedBox(height: 4),
              Text(
                '\$${monthlyIncome.toStringAsFixed(0)}/mo',
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Breakdown card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              if (totalBills > 0)
                _PlanRow(
                    label: 'Bills',
                    amount: -totalBills,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.87)),
              if (totalExtras > 0)
                _PlanRow(
                    label: 'Extras',
                    amount: -totalExtras,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45)),
              if (totalBills > 0 || totalExtras > 0)
                const Divider(height: 24),
              ...goals.map((g) => _PlanRow(
                    label: g.name,
                    amount: -g.suggestedMonthlyContribution,
                    color: g.isDebt
                        ? const Color(0xFFE53935)
                        : const Color(0xFF2E7D32),
                    sublabel: g.isDebt
                        ? 'paid off in ${g.timelineLabel}'
                        : 'goal reached in ${g.timelineLabel}',
                  )),
              if (goals.isNotEmpty) const Divider(height: 24),
              _PlanRow(
                label: 'Left to spend',
                amount: spendingMoney,
                color: Theme.of(context).colorScheme.onSurface,
                bold: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        if (spendingMoney < 0)
          _Notice(
            emoji: '⚠️',
            color: const Color(0xFFFFF3E0),
            text:
                'Your goals are ambitious — try extending the timeline on one to free up room.',
          )
        else
          _Notice(
            emoji: '✅',
            color: const Color(0xFFE8F5E9),
            text:
                "Your plan is solid. We'll show your progress in your buckets.",
          ),

        const SizedBox(height: 16),
      ],
    );
  }
}

class _PlanRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final String? sublabel;
  final bool bold;

  const _PlanRow({
    required this.label,
    required this.amount,
    required this.color,
    this.sublabel,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final isNeg = amount < 0;
    final str = '\$${amount.abs().toStringAsFixed(0)}/mo';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          bold ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                    )),
                if (sublabel != null)
                  Text(sublabel!,
                      style: TextStyle(
                          fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38))),
              ],
            ),
          ),
          Text(
            isNeg ? '-$str' : str,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String emoji;
  final Color color;
  final String text;

  const _Notice(
      {required this.emoji, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style:
                    const TextStyle(fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
