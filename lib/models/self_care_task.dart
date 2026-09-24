import 'package:flutter/material.dart';

/// How often a self-care task recurs.
enum SelfCareCadence { daily, weekly, biweekly, monthly }

/// A recurring self-care task shown on the Health screen
/// (laundry, haircut, nails, skincare, etc).
class SelfCareTask {
  final String id;
  String name;
  IconData icon;
  SelfCareCadence cadence;

  /// Weekday numbers (1=Monday … 7=Sunday) for weekly routines.
  List<int> scheduledDays;
  bool isDone;

  /// The date this task was last marked done — used to know when it's
  /// due again based on `cadence`, and to auto-reset `isDone` once the
  /// next period starts.
  DateTime? lastCompletedAt;

  SelfCareTask({
    required this.id,
    required this.name,
    required this.icon,
    required this.cadence,
    List<int>? scheduledDays,
    this.isDone = false,
    this.lastCompletedAt,
  }) : scheduledDays = scheduledDays ?? [1];

  /// A short status label for the checklist row, e.g. "Done", "Today",
  /// "Overdue" — mirrors the labels already used on HealthScreen.
  String get statusLabel {
    if (isDone) return 'Done';
    if (lastCompletedAt == null) return 'Due now';
    if (cadence == SelfCareCadence.weekly &&
        !scheduledDays.contains(DateTime.now().weekday)) {
      return 'Next scheduled day';
    }
    final daysSince = DateTime.now().difference(lastCompletedAt!).inDays;
    final cadenceDays = switch (cadence) {
      SelfCareCadence.daily => 1,
      SelfCareCadence.weekly => 7,
      SelfCareCadence.biweekly => 14,
      SelfCareCadence.monthly => 30,
    };
    return daysSince >= cadenceDays ? 'Due now' : 'Done';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon_code_point': icon.codePoint,
    'cadence': cadence.name,
    'scheduled_days': scheduledDays,
    'is_done': isDone,
    'last_completed_at': lastCompletedAt?.toIso8601String(),
  };

  factory SelfCareTask.fromJson(Map<String, dynamic> json) => SelfCareTask(
    id: json['id'] as String,
    name: json['name'] as String,
    // See the matching note in models/streak.dart re: icon tree-shaking.
    icon: IconData(json['icon_code_point'] as int, fontFamily: 'MaterialIcons'),
    cadence: SelfCareCadence.values.firstWhere(
      (c) => c.name == json['cadence'],
    ),
    scheduledDays: (json['scheduled_days'] as List<dynamic>? ?? [1])
        .map((day) => (day as num).toInt())
        .toList(),
    isDone: json['is_done'] as bool? ?? false,
    lastCompletedAt: json['last_completed_at'] != null
        ? DateTime.parse(json['last_completed_at'] as String)
        : null,
  );
}

/// A preset option shown on the self-care onboarding screen, so the user
/// can tap to add rather than typing everything from scratch.
class SelfCarePreset {
  final String name;
  final IconData icon;

  const SelfCarePreset({required this.name, required this.icon});
}

const List<SelfCarePreset> selfCarePresets = [
  SelfCarePreset(name: 'Haircut', icon: Icons.content_cut),
  SelfCarePreset(name: 'Nails', icon: Icons.back_hand_outlined),
  SelfCarePreset(name: 'Skincare', icon: Icons.face_retouching_natural),
  SelfCarePreset(name: 'Laundry', icon: Icons.local_laundry_service_outlined),
  SelfCarePreset(name: 'Meal prep', icon: Icons.set_meal_outlined),
  SelfCarePreset(name: 'Grocery run', icon: Icons.shopping_cart_outlined),
  SelfCarePreset(name: 'Clean room', icon: Icons.cleaning_services_outlined),
  SelfCarePreset(name: 'Prayer', icon: Icons.self_improvement),
  SelfCarePreset(name: 'Meditation', icon: Icons.spa_outlined),
  SelfCarePreset(name: 'Journaling', icon: Icons.edit_note),
  SelfCarePreset(name: 'Bible study', icon: Icons.book_outlined),
  SelfCarePreset(name: 'Hair styling', icon: Icons.auto_awesome),
];
