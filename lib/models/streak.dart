import 'package:flutter/material.dart';

/// How often a streak needs to be logged to stay alive.
enum StreakCadence { daily, weekly }

/// A single self-betterment streak (gym, reading, journaling, etc).
///
/// Cadence is set per-streak rather than per-category, since two people
/// (or the same person, for two different habits) may want the same
/// kind of streak tracked at different rates — e.g. reading nightly
/// vs. reading 3x/week.
class Streak {
  final String id;
  String name;
  IconData icon;
  String? emoji;
  StreakCadence cadence;

  /// For weekly streaks: how many times per week counts as "on track"
  /// (e.g. gym 4x/week). Ignored for daily streaks.
  int weeklyTarget;

  /// Weekday numbers (1=Monday … 7=Sunday) the user expects this habit.
  List<int> scheduledDays;

  /// Current consecutive streak count (days or weeks, depending on cadence).
  int currentStreak;

  /// Longest streak ever reached, kept for a small "personal best" flourish.
  int bestStreak;

  /// Dates the user has checked in. For weekly streaks, only the count
  /// within the current week matters toward `weeklyTarget`; the full
  /// history is kept for the activity graph and recalculating streaks.
  List<DateTime> checkIns;

  /// Whether this streak is visible to friends with whom it's shared.
  /// Off by default — sharing is opt-in per streak, never implied by
  /// just having a connected friend.
  bool sharedWithFriends;

  /// True for streaks whose status is computed from data (e.g. "stayed
  /// under budget this week", derived from transactions) rather than
  /// manually checked in by the user (e.g. gym, reading). Auto-evaluated
  /// streaks render as a read-only status badge instead of a tappable
  /// log button, since there's nothing for the user to "check in" — the
  /// app already knows whether they hit it.
  bool autoEvaluated;

  Streak({
    required this.id,
    required this.name,
    required this.icon,
    this.emoji,
    required this.cadence,
    this.weeklyTarget = 3,
    List<int>? scheduledDays,
    this.currentStreak = 0,
    this.bestStreak = 0,
    List<DateTime>? checkIns,
    this.sharedWithFriends = false,
    this.autoEvaluated = false,
  }) : checkIns = checkIns ?? [],
       scheduledDays = scheduledDays ?? [1, 3, 5];

  bool get isDaily => cadence == StreakCadence.daily;

  /// How many check-ins fall within the current calendar week (Mon–Sun).
  int get checkInsThisWeek {
    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    return checkIns.where((d) => !d.isBefore(startOfWeek)).length;
  }

  /// Whether today's (or this week's) check-in has already happened —
  /// used to disable the log button and show a "done" state on the card.
  bool get loggedForCurrentPeriod {
    final now = DateTime.now();
    if (isDaily) {
      return checkIns.any(
        (d) => d.year == now.year && d.month == now.month && d.day == now.day,
      );
    }
    return checkInsThisWeek >= weeklyTarget;
  }

  bool get loggedToday {
    final now = DateTime.now();
    return checkIns.any(
      (d) => d.year == now.year && d.month == now.month && d.day == now.day,
    );
  }

  bool get scheduledToday =>
      isDaily || scheduledDays.contains(DateTime.now().weekday);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon_code_point': icon.codePoint,
    'emoji': emoji,
    'cadence': cadence.name,
    'weekly_target': weeklyTarget,
    'scheduled_days': scheduledDays,
    'current_streak': currentStreak,
    'best_streak': bestStreak,
    'check_ins': checkIns.map((d) => d.toIso8601String()).toList(),
    'shared_with_friends': sharedWithFriends,
    'auto_evaluated': autoEvaluated,
  };

  factory Streak.fromJson(Map<String, dynamic> json) => Streak(
    id: json['id'] as String,
    name: json['name'] as String,
    // NOTE: reconstructing IconData from a raw code point like this
    // works at runtime, but Flutter's icon tree-shaker (on by default
    // in release builds) can't verify a non-const IconData like this
    // is actually used, and may either strip needed icon data or
    // require --no-tree-shake-icons. If release builds show blank/
    // wrong icons here, build with `flutter build ... --no-tree-shake-icons`
    // or switch to storing an icon *name* string and mapping it
    // through a fixed const lookup table instead.
    icon: IconData(json['icon_code_point'] as int, fontFamily: 'MaterialIcons'),
    emoji: json['emoji'] as String?,
    cadence: StreakCadence.values.firstWhere((c) => c.name == json['cadence']),
    weeklyTarget: json['weekly_target'] as int? ?? 3,
    scheduledDays: (json['scheduled_days'] as List<dynamic>? ?? [1, 3, 5])
        .map((day) => (day as num).toInt())
        .toList(),
    currentStreak: json['current_streak'] as int? ?? 0,
    bestStreak: json['best_streak'] as int? ?? 0,
    checkIns: (json['check_ins'] as List<dynamic>? ?? [])
        .map((s) => DateTime.parse(s as String))
        .toList(),
    sharedWithFriends: json['shared_with_friends'] as bool? ?? false,
    autoEvaluated: json['auto_evaluated'] as bool? ?? false,
  );
}

/// A short, easy-to-read-aloud code a friend can enter to connect.
/// Kept separate from full auth/account IDs so connecting a friend never
/// requires exposing emails or user IDs directly in the UI.
class StreakInvite {
  final String code;
  final String ownerName;

  StreakInvite({required this.code, required this.ownerName});
}

/// A connected friend, scoped only to the streaks they've each chosen
/// to share — there is no broader "friends list" or social graph here.
class StreakFriend {
  final String id;
  final String name;

  /// Streak names this friend has chosen to share with the current user.
  /// Mirrors `Streak.sharedWithFriends` but is per-friend so a user could
  /// (in a future pass) share different streaks with different friends.
  final List<String> sharedStreakNames;

  StreakFriend({
    required this.id,
    required this.name,
    required this.sharedStreakNames,
  });
}
