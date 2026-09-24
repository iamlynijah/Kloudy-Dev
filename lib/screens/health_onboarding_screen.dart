import 'package:flutter/material.dart';
import '../models/self_care_task.dart';
import '../models/streak.dart';

// ── Draft models used only during onboarding ──────────────────────────────

class _SelfCareDraft {
  String name;
  IconData icon;
  SelfCareCadence cadence;
  _SelfCareDraft({
    required this.name,
    required this.icon,
    this.cadence = SelfCareCadence.weekly,
  });
}

class _StreakDraft {
  String name;
  IconData icon;
  StreakCadence cadence;
  int weeklyTarget;
  List<int> scheduledDays;
  _StreakDraft({
    required this.name,
    required this.icon,
    this.cadence = StreakCadence.daily,
    this.weeklyTarget = 3,
    List<int>? scheduledDays,
  }) : scheduledDays = scheduledDays ?? [1, 3, 5];
}

// ── Preset data ────────────────────────────────────────────────────────────

const _streakPresets = [
  (name: 'Gym', icon: Icons.fitness_center),
  (name: 'Running', icon: Icons.directions_run),
  (name: 'Reading', icon: Icons.menu_book_outlined),
  (name: 'Journaling', icon: Icons.edit_note),
  (name: 'Bible study', icon: Icons.book_outlined),
  (name: 'Prayer', icon: Icons.self_improvement),
  (name: 'Meditation', icon: Icons.spa_outlined),
  (name: 'Water intake', icon: Icons.water_drop_outlined),
  (name: 'Walking', icon: Icons.directions_walk),
  (name: 'Yoga', icon: Icons.accessibility_new),
];

const _checkupTypes = [
  (key: 'primary_care', label: 'Primary care'),
  (key: 'dental', label: 'Dental'),
  (key: 'obgyn', label: 'OBGYN'),
  (key: 'optometrist', label: 'Optometrist'),
  (key: 'therapy', label: 'Therapy'),
];

const _checkupOptions = ['Within 6 mo', '6-12 mo', '1-2 yr', '2+ yr', 'N/A'];

const _checkupOptionKeys = {
  'Within 6 mo': 'within_6mo',
  '6-12 mo': '6_12mo',
  '1-2 yr': '1_2yr',
  '2+ yr': '2plus_yr',
  'N/A': 'na',
};

// ── Main screen ────────────────────────────────────────────────────────────

class HealthOnboardingScreen extends StatefulWidget {
  const HealthOnboardingScreen({super.key});

  @override
  State<HealthOnboardingScreen> createState() => _HealthOnboardingState();
}

class _HealthOnboardingState extends State<HealthOnboardingScreen> {
  int _step = 0;
  final List<_SelfCareDraft> _selfCareDrafts = [];
  final List<_StreakDraft> _streakDrafts = [];
  final Map<String, String?> _checkups = {
    'primary_care': null,
    'dental': null,
    'obgyn': null,
    'optometrist': null,
    'therapy': null,
  };

  bool _selfCareHas(String name) => _selfCareDrafts.any((d) => d.name == name);
  bool _streakHas(String name) => _streakDrafts.any((d) => d.name == name);

  void _toggleSelfCare(String name, IconData icon) {
    setState(() {
      if (_selfCareHas(name)) {
        _selfCareDrafts.removeWhere((d) => d.name == name);
      } else {
        _selfCareDrafts.add(_SelfCareDraft(name: name, icon: icon));
      }
    });
  }

  void _toggleStreak(String name, IconData icon) {
    setState(() {
      if (_streakHas(name)) {
        _streakDrafts.removeWhere((d) => d.name == name);
      } else {
        _streakDrafts.add(_StreakDraft(name: name, icon: icon));
      }
    });
  }

  void _updateSelfCareCadence(String name, SelfCareCadence cadence) {
    setState(() {
      _selfCareDrafts.firstWhere((d) => d.name == name).cadence = cadence;
    });
  }

  void _updateStreakCadence(String name, StreakCadence cadence) {
    setState(() {
      _streakDrafts.firstWhere((d) => d.name == name).cadence = cadence;
    });
  }

  void _updateStreakTarget(String name, int target) {
    setState(() {
      final draft = _streakDrafts.firstWhere((d) => d.name == name);
      draft.weeklyTarget = target;
      draft.scheduledDays = [1, 2, 3, 4, 5, 6, 7].take(target).toList();
    });
  }

  void _toggleScheduledDay(String name, int day) {
    setState(() {
      final draft = _streakDrafts.firstWhere((d) => d.name == name);
      if (draft.scheduledDays.contains(day)) {
        if (draft.scheduledDays.length == 1) return;
        draft.scheduledDays.remove(day);
      } else {
        draft.scheduledDays.add(day);
        draft.scheduledDays.sort();
      }
      draft.weeklyTarget = draft.scheduledDays.length;
    });
  }

  void _setCheckup(String key, String? value) {
    setState(() => _checkups[key] = value);
  }

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  void _finish() {
    final selfCare = _selfCareDrafts.asMap().entries.map((e) {
      final d = e.value;
      return SelfCareTask(
        id: 'sc-${e.key}-${d.name.hashCode}',
        name: d.name,
        icon: d.icon,
        cadence: d.cadence,
      ).toJson();
    }).toList();

    final streaks = _streakDrafts.asMap().entries.map((e) {
      final d = e.value;
      return Streak(
        id: 'streak-${e.key}-${d.name.hashCode}',
        name: d.name,
        icon: d.icon,
        cadence: d.cadence,
        weeklyTarget: d.weeklyTarget,
        scheduledDays: d.scheduledDays,
      ).toJson();
    }).toList();

    Navigator.pop(context, {
      'self_care': selfCare,
      'streaks': streaks,
      'checkups': _checkups,
    });
  }

  void _addCustomSelfCare() async {
    final result = await showModalBottomSheet<_SelfCareDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddCustomSelfCareSheet(),
    );
    if (result != null && !_selfCareHas(result.name)) {
      setState(() => _selfCareDrafts.add(result));
    }
  }

  void _addCustomStreak() async {
    final result = await showModalBottomSheet<_StreakDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddCustomStreakSheet(),
    );
    if (result != null && !_streakHas(result.name)) {
      setState(() => _streakDrafts.add(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['Self-care', 'Habits & streaks', 'Checkup history'];
    const subtitles = [
      'What does your routine look like?',
      'What habits are you building?',
      'When did you last see a doctor?',
    ];

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
                        children: List.generate(3, (i) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.only(right: 6),
                            width: i == _step ? 20 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i <= _step
                                  ? Colors.black
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    titles[_step],
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitles[_step],
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Step content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    0 => _SelfCareStep(
                      drafts: _selfCareDrafts,
                      onToggle: _toggleSelfCare,
                      onUpdateCadence: _updateSelfCareCadence,
                      onAddCustom: _addCustomSelfCare,
                    ),
                    1 => _StreaksStep(
                      drafts: _streakDrafts,
                      onToggle: _toggleStreak,
                      onUpdateCadence: _updateStreakCadence,
                      onUpdateTarget: _updateStreakTarget,
                      onToggleDay: _toggleScheduledDay,
                      onAddCustom: _addCustomStreak,
                    ),
                    _ => _CheckupsStep(checkups: _checkups, onSet: _setCheckup),
                  },
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
                      borderRadius: BorderRadius.circular(29),
                    ),
                  ),
                  child: Text(
                    _step == 2 ? "Let's go" : 'Continue',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
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

// ── Step 0: Self-care ──────────────────────────────────────────────────────

class _SelfCareStep extends StatelessWidget {
  final List<_SelfCareDraft> drafts;
  final void Function(String name, IconData icon) onToggle;
  final void Function(String name, SelfCareCadence cadence) onUpdateCadence;
  final VoidCallback onAddCustom;

  const _SelfCareStep({
    required this.drafts,
    required this.onToggle,
    required this.onUpdateCadence,
    required this.onAddCustom,
  });

  @override
  Widget build(BuildContext context) {
    final selectedNames = drafts.map((d) => d.name).toSet();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...selfCarePresets.map(
                (p) => _SelectChip(
                  label: p.name,
                  icon: p.icon,
                  selected: selectedNames.contains(p.name),
                  onTap: () => onToggle(p.name, p.icon),
                ),
              ),
              _AddChip(onTap: onAddCustom),
            ],
          ),
          if (drafts.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'How often?',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            ...drafts.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SelfCareDetailCard(
                  draft: d,
                  onUpdateCadence: (c) => onUpdateCadence(d.name, c),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SelfCareDetailCard extends StatelessWidget {
  final _SelfCareDraft draft;
  final void Function(SelfCareCadence) onUpdateCadence;

  const _SelfCareDetailCard({
    required this.draft,
    required this.onUpdateCadence,
  });

  static const _options = [
    (cadence: SelfCareCadence.daily, label: 'Daily'),
    (cadence: SelfCareCadence.weekly, label: 'Weekly'),
    (cadence: SelfCareCadence.biweekly, label: 'Every 2 wks'),
    (cadence: SelfCareCadence.monthly, label: 'Monthly'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(draft.icon, size: 16),
              const SizedBox(width: 8),
              Text(
                draft.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _options.map((opt) {
              final sel = draft.cadence == opt.cadence;
              return GestureDetector(
                onTap: () => onUpdateCadence(opt.cadence),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: sel ? Colors.black : const Color(0xFFF8F5F2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: sel ? Colors.white : Colors.black,
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

// ── Step 1: Streaks ────────────────────────────────────────────────────────

class _StreaksStep extends StatelessWidget {
  final List<_StreakDraft> drafts;
  final void Function(String name, IconData icon) onToggle;
  final void Function(String name, StreakCadence cadence) onUpdateCadence;
  final void Function(String name, int target) onUpdateTarget;
  final void Function(String name, int day) onToggleDay;
  final VoidCallback onAddCustom;

  const _StreaksStep({
    required this.drafts,
    required this.onToggle,
    required this.onUpdateCadence,
    required this.onUpdateTarget,
    required this.onToggleDay,
    required this.onAddCustom,
  });

  @override
  Widget build(BuildContext context) {
    final selectedNames = drafts.map((d) => d.name).toSet();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._streakPresets.map(
                (p) => _SelectChip(
                  label: p.name,
                  icon: p.icon,
                  selected: selectedNames.contains(p.name),
                  onTap: () => onToggle(p.name, p.icon),
                ),
              ),
              _AddChip(onTap: onAddCustom),
            ],
          ),
          if (drafts.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Frequency?',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            ...drafts.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _StreakDetailCard(
                  draft: d,
                  onUpdateCadence: (c) => onUpdateCadence(d.name, c),
                  onUpdateTarget: (t) => onUpdateTarget(d.name, t),
                  onToggleDay: (day) => onToggleDay(d.name, day),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _StreakDetailCard extends StatelessWidget {
  final _StreakDraft draft;
  final void Function(StreakCadence) onUpdateCadence;
  final void Function(int) onUpdateTarget;
  final void Function(int) onToggleDay;

  const _StreakDetailCard({
    required this.draft,
    required this.onUpdateCadence,
    required this.onUpdateTarget,
    required this.onToggleDay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(draft.icon, size: 16),
              const SizedBox(width: 8),
              Text(
                draft.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CadencePill(
                  label: 'Daily',
                  selected: draft.cadence == StreakCadence.daily,
                  onTap: () => onUpdateCadence(StreakCadence.daily),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CadencePill(
                  label: 'Weekly',
                  selected: draft.cadence == StreakCadence.weekly,
                  onTap: () => onUpdateCadence(StreakCadence.weekly),
                ),
              ),
            ],
          ),
          if (draft.cadence == StreakCadence.weekly) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '${draft.weeklyTarget}x per week',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.54),
                  ),
                ),
                const Spacer(),
                _StepperButton(
                  icon: Icons.remove,
                  onTap: draft.weeklyTarget > 1
                      ? () => onUpdateTarget(draft.weeklyTarget - 1)
                      : null,
                ),
                const SizedBox(width: 8),
                _StepperButton(
                  icon: Icons.add,
                  onTap: draft.weeklyTarget < 7
                      ? () => onUpdateTarget(draft.weeklyTarget + 1)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Which days?',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children:
                  const [
                    (1, 'Mon'),
                    (2, 'Tue'),
                    (3, 'Wed'),
                    (4, 'Thu'),
                    (5, 'Fri'),
                    (6, 'Sat'),
                    (7, 'Sun'),
                  ].map((day) {
                    final selected = draft.scheduledDays.contains(day.$1);
                    return FilterChip(
                      label: Text(day.$2),
                      selected: selected,
                      onSelected: (_) => onToggleDay(day.$1),
                    );
                  }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Step 2: Checkup history ────────────────────────────────────────────────

class _CheckupsStep extends StatelessWidget {
  final Map<String, String?> checkups;
  final void Function(String key, String? value) onSet;

  const _CheckupsStep({required this.checkups, required this.onSet});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._checkupTypes.map(
            (type) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CheckupRow(
                label: type.label,
                selectedKey: checkups[type.key],
                onSelect: (key) => onSet(type.key, key),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _CheckupRow extends StatelessWidget {
  final String label;
  final String? selectedKey;
  final void Function(String?) onSelect;

  const _CheckupRow({
    required this.label,
    this.selectedKey,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _checkupOptions.map((opt) {
              final key = _checkupOptionKeys[opt];
              final sel = selectedKey == key;
              return GestureDetector(
                onTap: () => onSelect(sel ? null : key),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: sel ? Colors.black : const Color(0xFFF8F5F2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    opt,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: sel ? Colors.white : Colors.black,
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

// ── Custom add sheets ──────────────────────────────────────────────────────

class _AddCustomSelfCareSheet extends StatefulWidget {
  const _AddCustomSelfCareSheet();

  @override
  State<_AddCustomSelfCareSheet> createState() =>
      _AddCustomSelfCareSheetState();
}

class _AddCustomSelfCareSheetState extends State<_AddCustomSelfCareSheet> {
  final _nameCtrl = TextEditingController();
  IconData _icon = Icons.star_outline;
  SelfCareCadence _cadence = SelfCareCadence.weekly;

  static const _iconChoices = [
    Icons.star_outline,
    Icons.spa_outlined,
    Icons.self_improvement,
    Icons.fitness_center,
    Icons.local_laundry_service_outlined,
    Icons.cleaning_services_outlined,
    Icons.shopping_cart_outlined,
    Icons.set_meal_outlined,
    Icons.book_outlined,
    Icons.edit_note,
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      _SelfCareDraft(name: name, icon: _icon, cadence: _cadence),
    );
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
                'Add self-care item',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. Hot bath, Face mask',
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
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
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _iconChoices.map((ic) {
                  final sel = ic == _icon;
                  return GestureDetector(
                    onTap: () => setState(() => _icon = ic),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: sel ? Colors.black : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        ic,
                        size: 18,
                        color: sel ? Colors.white : Colors.black,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              const Text(
                'How often?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children:
                    [
                      (SelfCareCadence.daily, 'Daily'),
                      (SelfCareCadence.weekly, 'Weekly'),
                      (SelfCareCadence.biweekly, 'Every 2 wks'),
                      (SelfCareCadence.monthly, 'Monthly'),
                    ].map((opt) {
                      final sel = _cadence == opt.$1;
                      return GestureDetector(
                        onTap: () => setState(() => _cadence = opt.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: sel ? Colors.black : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            opt.$2,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: sel ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                  ),
                  child: const Text(
                    'Add',
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

class _AddCustomStreakSheet extends StatefulWidget {
  const _AddCustomStreakSheet();

  @override
  State<_AddCustomStreakSheet> createState() => _AddCustomStreakSheetState();
}

class _AddCustomStreakSheetState extends State<_AddCustomStreakSheet> {
  final _nameCtrl = TextEditingController();
  IconData _icon = Icons.star_outline;
  StreakCadence _cadence = StreakCadence.daily;
  int _weeklyTarget = 3;

  static const _iconChoices = [
    Icons.star_outline,
    Icons.fitness_center,
    Icons.menu_book_outlined,
    Icons.edit_note,
    Icons.self_improvement,
    Icons.directions_run,
    Icons.water_drop_outlined,
    Icons.spa_outlined,
    Icons.book_outlined,
    Icons.accessibility_new,
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      _StreakDraft(
        name: name,
        icon: _icon,
        cadence: _cadence,
        weeklyTarget: _weeklyTarget,
      ),
    );
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
                'Add habit streak',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. Cold plunge, Stretching',
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
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
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _iconChoices.map((ic) {
                  final sel = ic == _icon;
                  return GestureDetector(
                    onTap: () => setState(() => _icon = ic),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: sel ? Colors.black : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        ic,
                        size: 18,
                        color: sel ? Colors.white : Colors.black,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _CadencePill(
                      label: 'Daily',
                      selected: _cadence == StreakCadence.daily,
                      onTap: () =>
                          setState(() => _cadence = StreakCadence.daily),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CadencePill(
                      label: 'Weekly',
                      selected: _cadence == StreakCadence.weekly,
                      onTap: () =>
                          setState(() => _cadence = StreakCadence.weekly),
                    ),
                  ),
                ],
              ),
              if (_cadence == StreakCadence.weekly) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '${_weeklyTarget}x per week',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.54),
                      ),
                    ),
                    const Spacer(),
                    _StepperButton(
                      icon: Icons.remove,
                      onTap: _weeklyTarget > 1
                          ? () => setState(() => _weeklyTarget--)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    _StepperButton(
                      icon: Icons.add,
                      onTap: _weeklyTarget < 7
                          ? () => setState(() => _weeklyTarget++)
                          : null,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                  ),
                  child: const Text(
                    'Add',
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

// ── Shared widgets ─────────────────────────────────────────────────────────

class _SelectChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _SelectChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : Colors.black,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : Colors.black,
              ),
            ),
          ],
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.15),
            width: 1.5,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 14),
            SizedBox(width: 4),
            Text(
              'Add',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _CadencePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CadencePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.black : const Color(0xFFF8F5F2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepperButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: onTap != null
              ? Colors.black
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}
