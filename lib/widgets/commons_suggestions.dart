import 'package:flutter/material.dart';
import '../demo/demo_profile.dart';
import '../theme/kloudy_theme.dart';

class CommonsSuggestions extends StatelessWidget {
  final ValueChanged<String> onSelect;

  const CommonsSuggestions({super.key, required this.onSelect});

  List<(String, String, IconData, Color)> get _suggestions {
    final goals = DemoProfile.goals;
    final first =
        goals.contains('lose_weight') ||
            goals.contains('build_muscle') ||
            goals.contains('improve_nutrition')
        ? (
            'High-protein dinner idea',
            goals.contains('lose_weight')
                ? 'Suggest an affordable, low-calorie, high-protein dinner recipe.'
                : 'Suggest an affordable, high-protein dinner recipe.',
            Icons.restaurant_outlined,
            kChipGold,
          )
        : goals.contains('stay_on_top_of_healthcare')
        ? (
            'Make a doctor’s appointment',
            'Help me prepare a simple script for calling a clinic.',
            Icons.medical_services_outlined,
            kChipBlush,
          )
        : (
            'Make my money stretch',
            'Help me plan affordable meals and a short grocery list.',
            Icons.account_balance_wallet_outlined,
            kChipSage,
          );
    return [
      first,
      (
        'Understand a budget',
        'Explain a first budget in plain language without judging my spending.',
        Icons.payments_outlined,
        kChipSage,
      ),
      (
        'Build a routine that sticks',
        'Help me make a realistic weekly routine around my energy and commitments.',
        Icons.calendar_month_outlined,
        kChipIndigo,
      ),
      (
        'What should I ask my doctor?',
        'Help me prepare questions for an upcoming doctor appointment.',
        Icons.medical_services_outlined,
        kChipBlush,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: kKloudyBlue,
              ),
              const SizedBox(width: 6),
              Text(
                'SUGGESTED FROM THE COMMONS',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .55),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 58,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _suggestions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final suggestion = _suggestions[index];
              return Material(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => onSelect(suggestion.$2),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(suggestion.$3, size: 17, color: kInk),
                        const SizedBox(width: 7),
                        Text(
                          suggestion.$1,
                          style: const TextStyle(
                            color: kInk,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 7),
      ],
    );
  }
}
