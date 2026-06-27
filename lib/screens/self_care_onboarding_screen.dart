import 'package:flutter/material.dart';
import '../models/self_care_task.dart';

/// First-time onboarding for the Health screen's self-care checklist.
///
/// Asks what the user routinely does for self-care — laundry, haircuts,
/// nails, etc — and at what cadence, so HealthScreen can show a
/// checklist tailored to them instead of generic placeholder tasks.
/// Returns the chosen list of SelfCareTask via Navigator.pop.
class SelfCareOnboardingScreen extends StatefulWidget {
  const SelfCareOnboardingScreen({super.key});

  @override
  State<SelfCareOnboardingScreen> createState() =>
      _SelfCareOnboardingScreenState();
}

class _SelfCareOnboardingScreenState extends State<SelfCareOnboardingScreen> {
  // name -> cadence, for everything the user has added (preset or custom).
  final Map<String, SelfCareCadence> selected = {};
  final Map<String, IconData> iconsByName = {};

  final TextEditingController customNameController = TextEditingController();

  @override
  void dispose() {
    customNameController.dispose();
    super.dispose();
  }

  void _toggle(SelfCarePreset preset) {
    setState(() {
      if (selected.containsKey(preset.name)) {
        selected.remove(preset.name);
        iconsByName.remove(preset.name);
      } else {
        selected[preset.name] = SelfCareCadence.weekly;
        iconsByName[preset.name] = preset.icon;
      }
    });
  }

  void _setCadence(String name, SelfCareCadence cadence) {
    setState(() => selected[name] = cadence);
  }

  void _addCustom() {
    final name = customNameController.text.trim();
    if (name.isEmpty || selected.containsKey(name)) return;

    setState(() {
      selected[name] = SelfCareCadence.weekly;
      iconsByName[name] = Icons.task_alt;
      customNameController.clear();
    });
  }

  void _finish() {
    final tasks = selected.entries
        .map(
          (entry) => SelfCareTask(
            id: 'sc-${entry.key.toLowerCase().replaceAll(' ', '-')}',
            name: entry.key,
            icon: iconsByName[entry.key] ?? Icons.task_alt,
            cadence: entry.value,
          ),
        )
        .toList();

    Navigator.pop(context, tasks);
  }

  void _skip() {
    Navigator.pop(context, <SelfCareTask>[]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: null, // inherits from theme
      appBar: AppBar(
        backgroundColor: null, // inherits from theme
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _skip,
            child: Text(
              'Skip',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 15),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "What's on your self-care list?",
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Tap the things you do regularly — laundry, haircuts, "
                      "nails — and we'll remind you to keep up with them.",
                      style: TextStyle(
                          fontSize: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), height: 1.4),
                    ),

                    const SizedBox(height: 28),

                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: selfCarePresets.map((preset) {
                        final isSelected = selected.containsKey(preset.name);
                        return GestureDetector(
                          onTap: () => _toggle(preset),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.black : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  preset.icon,
                                  size: 16,
                                  color: isSelected ? Colors.white : Colors.black,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  preset.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected ? Colors.white : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: customNameController,
                            decoration: InputDecoration(
                              hintText: 'Add something else…',
                              filled: true,
                              fillColor: Theme.of(context).cardColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                            onSubmitted: (_) => _addCustom(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _addCustom,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add,
                                size: 20, color: Colors.white),
                          ),
                        ),
                      ],
                    ),

                    if (selected.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      const Text(
                        'How often?',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Some things you'll want every week, others every "
                        "couple weeks.",
                        style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
                      ),
                      const SizedBox(height: 16),
                      ...selected.entries.map((entry) {
                        final name = entry.key;
                        final cadence = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  iconsByName[name] ?? Icons.task_alt,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                _CadenceToggle(
                                  cadence: cadence,
                                  onChanged: (c) => _setCadence(name, c),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: selected.isEmpty ? null : _finish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    disabledBackgroundColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
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

class _CadenceToggle extends StatelessWidget {
  final SelfCareCadence cadence;
  final ValueChanged<SelfCareCadence> onChanged;

  const _CadenceToggle({required this.cadence, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(context, 'Weekly', SelfCareCadence.weekly),
          _segment(context, '2 wks', SelfCareCadence.biweekly),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, String label, SelfCareCadence value) {
    final isSelected = cadence == value;
    final th = Theme.of(context);
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? th.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected ? th.colorScheme.onPrimary : th.colorScheme.onSurface.withOpacity(0.54),
          ),
        ),
      ),
    );
  }
}