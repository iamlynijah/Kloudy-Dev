import 'package:flutter/material.dart';
import '../models/anchor_bill.dart';
import '../models/finance_goal.dart';
import '../models/transaction.dart';
import '../services/supabase_service.dart';
import '../services/plaid_service.dart';
import 'finance_onboarding_screen.dart';
import 'finance_unlock_screen.dart';
import 'tab_gate_screen.dart';

class FinancesScreen extends StatefulWidget {
  const FinancesScreen({super.key});

  @override
  State<FinancesScreen> createState() => _FinancesScreenState();
}

class _FinancesScreenState extends State<FinancesScreen> {
  bool _loading = true;
  bool _onboardingDone = false;
  bool? _isUnlocked;

  double _monthlyIncome = 0;
  List<AnchorBill> _bills = [];
  List<RecurringExtra> _extras = [];
  List<FinanceGoal> _goals = [];

  bool _plaidConnected = false;
  bool _plaidLoading = false;
  String? _institutionName;
  List<Transaction> _transactions = [];
  List<PlaidAccount> _accounts = [];
  String? _selectedAccountId;
  final Set<String> _dismissedNudges = {};

  // ── Computed ──────────────────────────────────────────────────────

  double get _totalBills =>
      _bills.fold(0.0, (s, b) => s + b.monthlyAmount);

  double get _totalExtras =>
      _extras.fold(0.0, (s, e) => s + e.estimatedMonthlyAmount);

  double get _totalGoalContributions =>
      _goals.fold(0.0, (s, g) => s + g.suggestedMonthlyContribution);

  double get _spendingBudget =>
      _monthlyIncome - _totalBills - _totalExtras - _totalGoalContributions;

  String get _aiInsight {
    if (_goals.isEmpty && _monthlyIncome == 0) {
      return 'Set up your budget to get personalized insights.';
    }
    if (_goals.isEmpty) {
      return 'Add savings goals to start tracking your progress.';
    }
    // Find the goal that finishes soonest
    final sorted = [..._goals]
      ..sort((a, b) => a.targetMonths.compareTo(b.targetMonths));
    final first = sorted.first;
    if (first.isDebt) {
      return 'Keep it up — your ${first.name} will be paid off in ${first.timelineLabel}.';
    }
    return "At this rate, you'll hit your ${first.name} goal in ${first.timelineLabel}.";
  }

  // ── Data loading ──────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _load();
    _loadPlaid();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.fetchFinanceData(),
        SupabaseService.fetchProfile(),
      ]);
      if (!mounted) return;

      final data = results[0];
      final profile = results[1];

      final hasFinanceGoals = profile?['save_money'] == true ||
          profile?['pay_off_debt'] == true ||
          profile?['spend_more_intentionally'] == true ||
          profile?['increase_income'] == true;

      if (!hasFinanceGoals) {
        setState(() {
          _isUnlocked = false;
          _loading = false;
        });
        return;
      }

      setState(() => _isUnlocked = true);

      if (data == null) {
        setState(() {
          _loading = false;
          _onboardingDone = false;
        });
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _openOnboarding());
      } else {
        _populateFromData(data);
        setState(() {
          _loading = false;
          _onboardingDone = true;
        });
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _unlock() async {
    final answers = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const FinanceUnlockScreen()),
    );
    if (!mounted || answers == null) return;

    final goals = List<String>.from(answers['goals'] as List? ?? []);
    if (goals.isNotEmpty) {
      final flags = {for (final g in goals) g: true};
      await SupabaseService.setGoalFlags(flags);
    }
    if (!mounted) return;
    setState(() {
      _isUnlocked = true;
      _loading = false;
    });
    _openOnboarding();
  }

  void _populateFromData(Map<String, dynamic> data) {
    _monthlyIncome = (data['monthly_income'] as num? ?? 0).toDouble();
    _bills = (data['bills'] as List<dynamic>? ?? [])
        .map((e) => AnchorBill.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    _extras = (data['extras'] as List<dynamic>? ?? [])
        .map((e) =>
            RecurringExtra.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    _goals = (data['goals'] as List<dynamic>? ?? [])
        .map((e) =>
            FinanceGoal.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> _openOnboarding() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
          builder: (_) => const FinanceOnboardingScreen()),
    );
    if (result == null) return;

    final bills = result['bills'] as List<AnchorBill>;
    final extras = result['extras'] as List<RecurringExtra>;
    final income = result['monthlyIncome'] as double;
    final goals = result['goals'] as List<FinanceGoal>;

    final payload = {
      'monthly_income': income,
      'bills': bills.map((b) => b.toJson()).toList(),
      'extras': extras.map((e) => e.toJson()).toList(),
      'goals': goals.map((g) => g.toJson()).toList(),
    };

    await SupabaseService.saveFinanceData(payload);

    setState(() {
      _monthlyIncome = income;
      _bills = bills;
      _extras = extras;
      _goals = goals;
      _onboardingDone = true;
    });
  }

  // ── Manual goal update (edit flow) ───────────────────────────────

  Future<void> _addContribution(FinanceGoal goal) async {
    final ctrl = TextEditingController();
    final confirmed = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add to ${goal.name}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Text('\$',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 20),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '0',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  final v = double.tryParse(ctrl.text);
                  Navigator.pop(ctx, v);
                },
                child: const Text('Add',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == null || confirmed <= 0) return;

    setState(() {
      goal.currentAmount =
          (goal.currentAmount + confirmed).clamp(0, goal.targetAmount);
    });

    // Persist updated goals
    final payload = {
      'monthly_income': _monthlyIncome,
      'bills': _bills.map((b) => b.toJson()).toList(),
      'extras': _extras.map((e) => e.toJson()).toList(),
      'goals': _goals.map((g) => g.toJson()).toList(),
    };
    await SupabaseService.saveFinanceData(payload);
  }

  Future<void> _logContribution(FinanceGoal goal, double amount) async {
    setState(() {
      goal.currentAmount =
          (goal.currentAmount + amount).clamp(0, goal.targetAmount);
    });
    final payload = {
      'monthly_income': _monthlyIncome,
      'bills': _bills.map((b) => b.toJson()).toList(),
      'extras': _extras.map((e) => e.toJson()).toList(),
      'goals': _goals.map((g) => g.toJson()).toList(),
    };
    await SupabaseService.saveFinanceData(payload);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('\$${amount.toStringAsFixed(0)} logged to ${goal.name}!'),
        ),
      );
    }
  }

  // ── Plaid ─────────────────────────────────────────────────────────

  Future<void> _loadPlaid() async {
    try {
      final result = await PlaidService.fetchTransactions();
      if (!mounted) return;
      setState(() {
        _plaidConnected = result.connected;
        _institutionName = result.institutionName;
        _transactions = result.transactions;
        _accounts = result.accounts;
      });
    } catch (_) {}
  }

  List<Transaction> get _filteredTransactions {
    if (_selectedAccountId == null) return _transactions;
    return _transactions
        .where((t) => t.accountId == _selectedAccountId)
        .toList();
  }

  Future<void> _connectPlaid() async {
    setState(() => _plaidLoading = true);
    try {
      final connected = await PlaidService.connect();
      if (!mounted) return;
      if (connected) {
        await _loadPlaid();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank connection cancelled')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    if (mounted) setState(() => _plaidLoading = false);
  }

  double get _totalSpent =>
      _transactions.where((t) => !t.isTransfer).fold(0.0, (s, t) => s + t.amount);

  // Returns the first undismissed transfer that matches a goal, or null.
  ({Transaction txn, FinanceGoal goal})? get _activeNudge {
    for (final txn in _filteredTransactions) {
      if (_dismissedNudges.contains(txn.id)) continue;
      if (txn.transferType == 'loan_payment') {
        final debtGoals = _goals.where((g) => g.isDebt).toList();
        if (debtGoals.isNotEmpty) return (txn: txn, goal: debtGoals.first);
      }
    }
    for (final txn in _filteredTransactions) {
      if (_dismissedNudges.contains(txn.id)) continue;
      if (txn.transferType == 'transfer') {
        final savingsGoals = _goals.where((g) => !g.isDebt).toList();
        if (savingsGoals.isNotEmpty) return (txn: txn, goal: savingsGoals.first);
      }
    }
    return null;
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: null,
        body: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
      );
    }

    if (_isUnlocked == false) {
      return TabGateScreen(
        tabName: 'Finances',
        icon: Icons.attach_money,
        tagline: 'Budget smarter, pay off debt, and build toward your goals.',
        features: [
          (Icons.receipt_long_outlined, 'Track bills and income'),
          (Icons.savings_outlined, 'Set savings goals with timelines'),
          (Icons.credit_card_outlined, 'Pay off debt with a plan'),
        ],
        onSetUp: _unlock,
      );
    }

    if (!_onboardingDone) {
      return Scaffold(
        backgroundColor: null, // inherits from theme
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('💰',
                      style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  const Text('Set up your finances',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    "We'll build your budget and track your goals.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _openOnboarding,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28)),
                      ),
                      child: const Text("Let's do it",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: null, // inherits from theme
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        onPressed: _openOnboarding,
        child: const Icon(Icons.edit_outlined),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: Theme.of(context).colorScheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Title ──
                const Text('Finances',
                    style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold)),

                const SizedBox(height: 16),

                // ── AI Insight ──
                _AiInsightCard(text: _aiInsight),

                const SizedBox(height: 20),

                // ── Spending snapshot ──
                _SpendingSnapshot(
                  monthlyIncome: _monthlyIncome,
                  bills: _bills,
                  extras: _extras,
                  totalGoals: _totalGoalContributions,
                  spendingBudget: _spendingBudget,
                  actualSpent: _plaidConnected ? _totalSpent : null,
                ),

                const SizedBox(height: 24),

                // ── Goal buckets ──
                if (_goals.isNotEmpty) ...[
                  const Text('Your buckets',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ..._goals.map((g) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GoalBucketCard(
                          goal: g,
                          onAddContribution: () => _addContribution(g),
                        ),
                      )),
                  const SizedBox(height: 8),
                ],

                // ── Transactions ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Spending this month',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    if (_plaidConnected)
                      Text(
                        _institutionName ?? 'Connected',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_plaidLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (!_plaidConnected)
                  _ConnectBankCard(onConnect: _connectPlaid)
                else ...[
                  // Account filter chips
                  if (_accounts.length > 1) ...[
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _AccountChip(
                            label: 'All',
                            selected: _selectedAccountId == null,
                            onTap: () => setState(() => _selectedAccountId = null),
                          ),
                          ..._accounts.map((a) => _AccountChip(
                                label: a.displayName,
                                selected: _selectedAccountId == a.id,
                                onTap: () => setState(() => _selectedAccountId = a.id),
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Category breakdown (transfers excluded)
                  Builder(builder: (context) {
                    final spendTxns = _filteredTransactions
                        .where((t) => !t.isTransfer)
                        .toList();
                    if (spendTxns.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CategoryBreakdown(
                          totals: Map.fromEntries(
                            spendTxns
                                .fold(<String, double>{}, (map, t) {
                                  map[t.category] =
                                      (map[t.category] ?? 0) + t.amount;
                                  return map;
                                })
                                .entries
                                .toList()
                              ..sort((a, b) => b.value.compareTo(a.value)),
                          ),
                          totalSpent:
                              spendTxns.fold(0.0, (s, t) => s + t.amount),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }),

                  // Transfer nudge card
                  if (_activeNudge != null) ...[
                    _TransferNudgeCard(
                      txn: _activeNudge!.txn,
                      goal: _activeNudge!.goal,
                      onLog: () {
                        final nudge = _activeNudge!;
                        setState(() =>
                            _dismissedNudges.add(nudge.txn.id));
                        _logContribution(nudge.goal, nudge.txn.amount);
                      },
                      onDismiss: () => setState(
                          () => _dismissedNudges.add(_activeNudge!.txn.id)),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Transaction list
                  if (_filteredTransactions.isNotEmpty) ...[
                    Text(
                      'All transactions',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6)),
                    ),
                    const SizedBox(height: 8),
                  ],
                  ..._filteredTransactions.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _TransactionRow(transaction: t),
                      )),
                  if (_filteredTransactions.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text('No transactions this month',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.4))),
                      ),
                    ),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// AI INSIGHT CARD
// ─────────────────────────────────────────────

class _AiInsightCard extends StatelessWidget {
  final String text;

  const _AiInsightCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Text('✨', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SPENDING SNAPSHOT
// ─────────────────────────────────────────────

class _SpendingSnapshot extends StatefulWidget {
  final double monthlyIncome;
  final List<AnchorBill> bills;
  final List<RecurringExtra> extras;
  final double totalGoals;
  final double spendingBudget;
  final double? actualSpent;

  const _SpendingSnapshot({
    required this.monthlyIncome,
    required this.bills,
    required this.extras,
    required this.totalGoals,
    required this.spendingBudget,
    this.actualSpent,
  });

  @override
  State<_SpendingSnapshot> createState() => _SpendingSnapshotState();
}

class _SpendingSnapshotState extends State<_SpendingSnapshot> {
  bool _billsExpanded = false;
  bool _extrasExpanded = false;

  double get _totalBills =>
      widget.bills.fold(0.0, (s, b) => s + b.monthlyAmount);
  double get _totalExtras =>
      widget.extras.fold(0.0, (s, e) => s + e.estimatedMonthlyAmount);

  @override
  Widget build(BuildContext context) {
    final remaining = widget.actualSpent != null
        ? widget.spendingBudget - widget.actualSpent!
        : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _SnapshotRow(
            label: 'Monthly income',
            value: '\$${widget.monthlyIncome.toStringAsFixed(0)}',
            positive: true,
          ),

          // Bills — tappable, expands to list
          if (_totalBills > 0) ...[
            GestureDetector(
              onTap: () => setState(() => _billsExpanded = !_billsExpanded),
              child: _SnapshotRow(
                label: 'Bills',
                value: '-\$${_totalBills.toStringAsFixed(0)}',
                trailing: Icon(
                  _billsExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
            ),
            if (_billsExpanded)
              ...widget.bills.map((b) => _SubRow(
                    label: b.name,
                    value: '\$${b.monthlyAmount.toStringAsFixed(0)}',
                  )),
          ],

          // Extras — tappable, expands to list
          if (_totalExtras > 0) ...[
            GestureDetector(
              onTap: () => setState(() => _extrasExpanded = !_extrasExpanded),
              child: _SnapshotRow(
                label: 'Extras',
                value: '-\$${_totalExtras.toStringAsFixed(0)}',
                trailing: Icon(
                  _extrasExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
            ),
            if (_extrasExpanded)
              ...widget.extras.map((e) => _SubRow(
                    label: e.name,
                    value: '\$${e.estimatedMonthlyAmount.toStringAsFixed(0)}',
                  )),
          ],

          if (widget.totalGoals > 0)
            _SnapshotRow(
              label: 'Goals',
              value: '-\$${widget.totalGoals.toStringAsFixed(0)}',
            ),

          const Divider(height: 20),

          // If Plaid connected, show spent + remaining
          if (widget.actualSpent != null) ...[
            _SnapshotRow(
              label: 'Spent this month',
              value: '-\$${widget.actualSpent!.toStringAsFixed(0)}',
            ),
            const SizedBox(height: 4),
            _SnapshotRow(
              label: 'Remaining',
              value: '\$${remaining!.toStringAsFixed(0)}',
              bold: true,
              positive: remaining >= 0,
            ),
          ] else
            _SnapshotRow(
              label: 'Left to spend',
              value: '\$${widget.spendingBudget.toStringAsFixed(0)}/mo',
              bold: true,
              positive: widget.spendingBudget >= 0,
            ),
        ],
      ),
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final bool positive;
  final Widget? trailing;

  const _SnapshotRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.positive = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.87),
                )),
          ),
          Text(value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: bold
                    ? (positive ? const Color(0xFF2E7D32) : Colors.red)
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.87),
              )),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _SubRow extends StatelessWidget {
  final String label;
  final String value;

  const _SubRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 3, bottom: 3),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GOAL BUCKET CARD
// ─────────────────────────────────────────────

class _GoalBucketCard extends StatelessWidget {
  final FinanceGoal goal;
  final VoidCallback onAddContribution;

  const _GoalBucketCard({
    required this.goal,
    required this.onAddContribution,
  });

  String get _emoji {
    if (goal.isDebt) return '💳';
    switch (goal.name.toLowerCase()) {
      case 'vacation': return '✈️';
      case 'emergency fund': return '🛡️';
      case 'new car': return '🚗';
      case 'down payment': return '🏠';
      case 'wedding': return '💍';
      case 'education': return '🎓';
      default: return '🎯';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = goal.percentComplete;
    final isComplete = pct >= 1.0;
    final monthly = goal.suggestedMonthlyContribution;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(goal.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              if (!isComplete)
                GestureDetector(
                  onTap: onAddContribution,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('+ Add',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                )
              else
                const Text('✅ Done',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E7D32))),
            ],
          ),

          const SizedBox(height: 12),

          // Fill bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: const Color(0xFFF0F0F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                goal.isDebt
                    ? const Color(0xFFE53935)
                    : const Color(0xFF2E7D32),
              ),
            ),
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                goal.isDebt
                    ? '\$${goal.remaining.toStringAsFixed(0)} left'
                    : '\$${goal.currentAmount.toStringAsFixed(0)} of \$${goal.targetAmount.toStringAsFixed(0)}',
                style: TextStyle(
                    fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
              ),
              if (!isComplete)
                Text(
                  '\$${monthly.toStringAsFixed(0)}/mo · ${goal.timelineLabel} to go',
                  style: TextStyle(
                      fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ACCOUNT CHIP
// ─────────────────────────────────────────────

class _AccountChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AccountChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CATEGORY BREAKDOWN
// ─────────────────────────────────────────────

class _CategoryBreakdown extends StatelessWidget {
  final Map<String, double> totals;
  final double totalSpent;

  const _CategoryBreakdown({required this.totals, required this.totalSpent});

  static const _categoryIcons = <String, IconData>{
    'Food & Drink':   Icons.restaurant_outlined,
    'Shopping':       Icons.shopping_bag_outlined,
    'Transport':      Icons.directions_car_outlined,
    'Entertainment':  Icons.movie_outlined,
    'Personal Care':  Icons.face_retouching_natural,
    'Health':         Icons.favorite_outline,
    'Travel':         Icons.flight_outlined,
    'Home':           Icons.home_outlined,
    'Utilities':      Icons.bolt_outlined,
    'Other':          Icons.payments_outlined,
  };

  static const _categoryColors = <String, Color>{
    'Food & Drink':   Color(0xFFEDD4B0),
    'Shopping':       Color(0xFFD4D8F0),
    'Transport':      Color(0xFFDCEED4),
    'Entertainment':  Color(0xFFEDD8F0),
    'Personal Care':  Color(0xFFF4D4E8),
    'Health':         Color(0xFFE8C4C4),
    'Travel':         Color(0xFFD4E8EE),
    'Home':           Color(0xFFEAE4D4),
    'Utilities':      Color(0xFFF0E8C8),
    'Other':          Color(0xFFE4DDD4),
  };

  @override
  Widget build(BuildContext context) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('By category',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(
                '\$${totalSpent.toStringAsFixed(0)} total',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...totals.entries.map((e) {
            final pct = totalSpent > 0 ? e.value / totalSpent : 0.0;
            final color = _categoryColors[e.key] ?? const Color(0xFFE4DDD4);
            final icon = _categoryIcons[e.key] ?? Icons.payments_outlined;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, size: 15,
                        color: Theme.of(context).colorScheme.onSurface),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.key,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500)),
                            Text('\$${e.value.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 5,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.08),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CONNECT BANK CARD
// ─────────────────────────────────────────────

class _ConnectBankCard extends StatelessWidget {
  final VoidCallback onConnect;

  const _ConnectBankCard({required this.onConnect});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onConnect,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Icon(Icons.account_balance_outlined, size: 28),
            const SizedBox(height: 10),
            const Text('Connect your bank',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'See your spending automatically, no manual entry',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Connect bank',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TRANSACTION ROW
// ─────────────────────────────────────────────

class _TransactionRow extends StatelessWidget {
  final Transaction transaction;

  const _TransactionRow({required this.transaction});

  IconData get _icon {
    if (transaction.isTransfer) return Icons.swap_horiz;
    switch (transaction.category) {
      case 'Food & Drink': return Icons.restaurant_outlined;
      case 'Groceries': return Icons.shopping_basket_outlined;
      case 'Gas': return Icons.local_gas_station_outlined;
      case 'Shopping': return Icons.shopping_bag_outlined;
      default: return Icons.payments_outlined;
    }
  }

  String get _dateLabel {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[transaction.date.weekday - 1];
  }

  String get _subtitleLabel {
    if (transaction.isTransfer) return 'Transfer · $_dateLabel';
    return '${transaction.category} · $_dateLabel';
  }

  @override
  Widget build(BuildContext context) {
    final dimmed = transaction.isTransfer;
    final baseColor = Theme.of(context).colorScheme.onSurface;

    return Opacity(
      opacity: dimmed ? 0.45 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, size: 18, color: baseColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(transaction.merchantName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  Text(
                    _subtitleLabel,
                    style: TextStyle(
                        fontSize: 12,
                        color: baseColor.withValues(alpha: 0.45)),
                  ),
                ],
              ),
            ),
            Text('\$${transaction.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TRANSFER NUDGE CARD
// ─────────────────────────────────────────────

class _TransferNudgeCard extends StatelessWidget {
  final Transaction txn;
  final FinanceGoal goal;
  final VoidCallback onLog;
  final VoidCallback onDismiss;

  const _TransferNudgeCard({
    required this.txn,
    required this.goal,
    required this.onLog,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isLoan = txn.transferType == 'loan_payment';
    final emoji = isLoan ? '💳' : '🏦';
    final desc = isLoan
        ? '\$${txn.amount.toStringAsFixed(0)} payment to ${txn.merchantName}'
        : '\$${txn.amount.toStringAsFixed(0)} transfer detected';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD54F)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(desc,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                  'Count toward ${goal.name}?',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onLog,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFCA28),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Log it',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close,
                size: 16,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3)),
          ),
        ],
      ),
    );
  }
}
