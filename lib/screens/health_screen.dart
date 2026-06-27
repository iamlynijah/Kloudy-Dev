import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/streak.dart';
import '../models/self_care_task.dart';
import '../models/appointment.dart';
import '../services/friend_service.dart';
import '../services/supabase_service.dart';
import '../services/calendar_service.dart';
import 'health_onboarding_screen.dart';
import 'tab_gate_screen.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  bool _isLoading = true;
  bool _hasHealthData = false;
  bool? _isUnlocked;

  List<Streak> streaks = [];
  List<SelfCareTask> selfCareTasks = [];
  Map<String, String?> _checkups = {};

  List<Appointment> appointments = [];
  bool _calendarConnected = false;
  bool _calendarLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadCalendar();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      SupabaseService.fetchHealthData(),
      SupabaseService.fetchProfile(),
    ]);
    if (!mounted) return;

    final data = results[0];
    final profile = results[1];

    final hasHealthGoals = profile?['build_healthier_habits'] == true ||
        profile?['improve_sleep'] == true ||
        profile?['stay_on_top_of_healthcare'] == true;

    if (!hasHealthGoals) {
      setState(() {
        _isUnlocked = false;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isUnlocked = true);

    if (data == null) {
      setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openOnboarding();
      });
    } else {
      _populateFromData(data);
    }
  }

  Future<void> _loadCalendar() async {
    final connected = await CalendarService.tryConnectSilently();
    if (!mounted) return;
    if (!connected) {
      setState(() => _calendarConnected = false);
      return;
    }
    setState(() {
      _calendarConnected = true;
      _calendarLoading = true;
    });
    final events = await CalendarService.fetchHealthAppointments();
    if (!mounted) return;
    setState(() {
      appointments = events;
      _calendarLoading = false;
    });
  }

  Future<void> _connectCalendar() async {
    setState(() => _calendarLoading = true);
    final connected = await CalendarService.connect();
    if (!mounted) return;
    if (!connected) {
      setState(() => _calendarLoading = false);
      return;
    }
    setState(() => _calendarConnected = true);
    final events = await CalendarService.fetchHealthAppointments();
    if (!mounted) return;
    setState(() {
      appointments = events;
      _calendarLoading = false;
    });
  }

  Future<void> _openAddAppointment() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddAppointmentSheet(),
    );
    if (result == true && mounted) {
      setState(() => _calendarLoading = true);
      final events = await CalendarService.fetchHealthAppointments();
      if (!mounted) return;
      setState(() {
        appointments = events;
        _calendarLoading = false;
      });
    }
  }

  void _unlock() async {
    await SupabaseService.setGoalFlags({
      'build_healthier_habits': true,
      'improve_sleep': true,
      'stay_on_top_of_healthcare': true,
    });
    if (!mounted) return;
    setState(() {
      _isUnlocked = true;
      _isLoading = false;
    });
    _openOnboarding();
  }

  void _populateFromData(Map<String, dynamic> data) {
    final selfCareList = (data['self_care'] as List<dynamic>? ?? [])
        .map((j) => SelfCareTask.fromJson(j as Map<String, dynamic>))
        .toList();
    final streakList = (data['streaks'] as List<dynamic>? ?? [])
        .map((j) => Streak.fromJson(j as Map<String, dynamic>))
        .toList();
    final rawCheckups = data['checkups'] as Map<String, dynamic>? ?? {};

    setState(() {
      selfCareTasks = selfCareList;
      streaks = streakList;
      _checkups = rawCheckups.map((k, v) => MapEntry(k, v as String?));
      _hasHealthData = true;
      _isLoading = false;
    });
  }

  Future<void> _saveHealthData() async {
    await SupabaseService.saveHealthData({
      'self_care': selfCareTasks.map((t) => t.toJson()).toList(),
      'streaks': streaks.map((s) => s.toJson()).toList(),
      'checkups': _checkups,
    });
  }

  void _openOnboarding() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const HealthOnboardingScreen()),
    );
    if (result != null && mounted) {
      await SupabaseService.saveHealthData(result);
      _populateFromData(result);
    }
  }

  void _checkIn(Streak streak) {
    if (streak.loggedForCurrentPeriod) return;
    setState(() {
      streak.checkIns.add(DateTime.now());
      streak.currentStreak++;
      if (streak.currentStreak > streak.bestStreak) {
        streak.bestStreak = streak.currentStreak;
      }
    });
    _saveHealthData();
  }

  void _openCreateStreak() async {
    final newStreak = await showModalBottomSheet<Streak>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateStreakSheet(),
    );
    if (newStreak != null) {
      setState(() => streaks.add(newStreak));
      _saveHealthData();
    }
  }

  void _openStreakDetail(Streak streak) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StreakDetailSheet(streak: streak),
    );
    if (action == 'delete') {
      setState(() => streaks.removeWhere((s) => s.id == streak.id));
      _saveHealthData();
    } else {
      setState(() {});
    }
  }

  void _openFriends() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FriendsSheet(),
    );
    setState(() {});
  }

  void _toggleSelfCareTask(SelfCareTask task) {
    setState(() {
      task.isDone = !task.isDone;
      if (task.isDone) task.lastCompletedAt = DateTime.now();
    });
    _saveHealthData();
  }

  Future<void> _callCrisisLine() async {
    final uri = Uri.parse('tel:988');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _textCrisisLine() async {
    final uri = Uri.parse('sms:988');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openFindCareSearch(String query) async {
    final uri = Uri.parse(
        'https://www.google.com/search?q=${Uri.encodeComponent(query)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // Computes checkup reminders based on how long ago each visit was.
  List<_CheckupReminder> get _checkupReminders {
    final reminders = <_CheckupReminder>[];

    void check(String key, String label,
        {required List<String> dueSoon, required List<String> overdue}) {
      final val = _checkups[key];
      if (val == null || val == 'na') return;
      if (overdue.contains(val)) {
        reminders.add(_CheckupReminder(label: label, isOverdue: true));
      } else if (dueSoon.contains(val)) {
        reminders.add(_CheckupReminder(label: label, isOverdue: false));
      }
    }

    // Primary care: yearly
    check('primary_care', 'Primary care',
        dueSoon: ['1_2yr'], overdue: ['2plus_yr']);
    // Dental: every 6 months
    check('dental', 'Dental',
        dueSoon: ['6_12mo'], overdue: ['1_2yr', '2plus_yr']);
    // OBGYN: yearly
    check('obgyn', 'OBGYN', dueSoon: ['1_2yr'], overdue: ['2plus_yr']);
    // Optometrist: every 1-2 years
    check('optometrist', 'Optometrist',
        dueSoon: [], overdue: ['2plus_yr']);

    return reminders;
  }

  @override
  Widget build(BuildContext context) {
    if (_isUnlocked == false) {
      return TabGateScreen(
        tabName: 'Health',
        icon: Icons.favorite,
        tagline:
            'Build habits, track streaks, and stay on top of your health.',
        features: [
          (Icons.loop, 'Track daily and weekly streaks'),
          (Icons.spa_outlined, 'Log self-care routines'),
          (Icons.calendar_today_outlined, 'Get checkup reminders'),
        ],
        onSetUp: _unlock,
      );
    }

    final nextAppointment =
        appointments.isNotEmpty ? appointments.first : null;
    final findCareQuery =
        nextAppointment?.findCareQuery ?? 'doctors near me';
    final reminders = _checkupReminders;

    return Scaffold(
      backgroundColor: null, // inherits from theme
      floatingActionButton: _hasHealthData
          ? FloatingActionButton(
              onPressed: _openOnboarding,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: const CircleBorder(),
              child: const Icon(Icons.edit_outlined, size: 20),
            )
          : null,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Health',
                          style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        _FriendsIconButton(onTap: _openFriends),
                      ],
                    ),

                    if (!_hasHealthData) ...[
                      const SizedBox(height: 24),
                      _SetupPrompt(onTap: _openOnboarding),
                    ] else ...[
                      // ── Streaks ──
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Self betterment',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          _AddButton(onTap: _openCreateStreak),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (streaks.isEmpty)
                        _EmptyState(
                          message: 'No streaks yet — tap + to add one',
                          onTap: _openCreateStreak,
                        )
                      else
                        SizedBox(
                          height: 178,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: streaks.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final streak = streaks[index];
                              return Column(
                                children: [
                                  _StreakCard(
                                    streak: streak,
                                    onTap: () => _openStreakDetail(streak),
                                  ),
                                  const SizedBox(height: 6),
                                  _CheckInButton(
                                    done: streak.loggedForCurrentPeriod,
                                    onTap: streak.loggedForCurrentPeriod
                                        ? null
                                        : () => _checkIn(streak),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),

                      // ── Self-care checklist ──
                      const SizedBox(height: 24),
                      const Text(
                        'Self-care this week',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      if (selfCareTasks.isEmpty)
                        GestureDetector(
                          onTap: _openOnboarding,
                          child: _EmptyCard(
                            message: 'No self-care items — tap to set up',
                          ),
                        )
                      else
                        ...selfCareTasks.map(
                          (task) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _SelfCareRow(
                              task: task,
                              onToggle: () => _toggleSelfCareTask(task),
                            ),
                          ),
                        ),

                      // ── Checkup reminders ──
                      if (reminders.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Health reminders',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        ...reminders.map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _CheckupReminderCard(reminder: r),
                          ),
                        ),
                      ],

                      // ── Find care ──
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () => _openFindCareSearch(findCareQuery),
                        child: _FindCareBanner(query: findCareQuery),
                      ),

                      // ── Appointments ──
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Upcoming appointments',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          Row(
                            children: [
                              if (_calendarConnected)
                                GestureDetector(
                                  onTap: _openAddAppointment,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.add,
                                            size: 13,
                                            color: Theme.of(context).colorScheme.onPrimary),
                                        const SizedBox(width: 3),
                                        Text('Add',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context).colorScheme.onPrimary)),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                Row(
                                  children: [
                                    Icon(Icons.event_outlined,
                                        size: 14,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Google Calendar',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_calendarLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (!_calendarConnected)
                        _ConnectCalendarBanner(onTap: _connectCalendar)
                      else if (appointments.isEmpty)
                        const _MessageState(
                            message: 'No health appointments in the next 90 days')
                      else
                        ...appointments.map(
                          (appt) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _AppointmentRow(appointment: appt),
                          ),
                        ),

                      // ── Crisis card ──
                      const SizedBox(height: 24),
                      _CrisisCard(
                          onCall: _callCrisisLine, onText: _textCrisisLine),
                    ],

                    const SizedBox(height: 80), // FAB clearance
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Setup prompt ───────────────────────────────────────────────────────────

class _SetupPrompt extends StatelessWidget {
  final VoidCallback onTap;

  const _SetupPrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08), width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite_outline, size: 24),
            ),
            const SizedBox(height: 14),
            const Text(
              'Set up your health profile',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Tell us your self-care routine, habits to track, and when you last saw a doctor.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
            ),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "Let's do it",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Checkup reminder ───────────────────────────────────────────────────────

class _CheckupReminder {
  final String label;
  final bool isOverdue;
  _CheckupReminder({required this.label, required this.isOverdue});
}

class _CheckupReminderCard extends StatelessWidget {
  final _CheckupReminder reminder;

  const _CheckupReminderCard({required this.reminder});

  String get _searchQuery {
    final label = reminder.label.toLowerCase();
    if (label.contains('dental')) return 'dentist near me';
    if (label.contains('obgyn') || label.contains('ob/gyn')) return 'OBGYN near me';
    if (label.contains('eye')) return 'eye doctor near me';
    if (label.contains('derm')) return 'dermatologist near me';
    return '${reminder.label} doctor near me';
  }

  Future<void> _launch() async {
    final query = Uri.encodeComponent(_searchQuery);
    final url = Uri.parse('https://www.google.com/maps/search/$query');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final color = reminder.isOverdue
        ? const Color(0xFFFFEBEB)
        : const Color(0xFFFFF8E1);
    final iconColor =
        reminder.isOverdue ? const Color(0xFFD32F2F) : const Color(0xFFF57F17);

    return GestureDetector(
      onTap: _launch,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              reminder.isOverdue
                  ? Icons.warning_amber_rounded
                  : Icons.schedule_outlined,
              size: 20,
              color: iconColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.label,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    reminder.isOverdue
                        ? 'Overdue — tap to find one near you'
                        : 'Coming up — tap to book soon',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55)),
                  ),
                ],
              ),
            ),
            Icon(Icons.north_east,
                size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55)),
          ],
        ),
      ),
    );
  }
}

// ── Check-in button ────────────────────────────────────────────────────────

class _CheckInButton extends StatelessWidget {
  final bool done;
  final VoidCallback? onTap;

  const _CheckInButton({required this.done, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 112,
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: done ? Theme.of(context).colorScheme.onSurface.withOpacity(0.06) : Colors.black,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            done ? 'Logged ✓' : '+ Log today',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: done ? Theme.of(context).colorScheme.onSurface.withOpacity(0.4) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty states ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String message;
  final VoidCallback? onTap;

  const _EmptyState({required this.message, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            message,
            style: TextStyle(
                fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45)),
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;

  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          message,
          style:
              TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45)),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final String message;

  const _MessageState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          message,
          style:
              TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45)),
        ),
      ),
    );
  }
}

// ── Streak card (tap → detail, no toggle) ─────────────────────────────────

class _StreakCard extends StatelessWidget {
  final Streak streak;
  final VoidCallback onTap;

  const _StreakCard({required this.streak, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final done = streak.loggedForCurrentPeriod;
    final th = Theme.of(context);
    final doneBg = th.colorScheme.primary;
    final doneFg = th.colorScheme.onPrimary;
    final notDoneBg = th.cardColor;
    final notDoneFg = th.colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 112,
        height: 132,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: done ? doneBg : notDoneBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  streak.icon,
                  size: 20,
                  color: done ? doneFg : notDoneFg,
                ),
                if (streak.sharedWithFriends)
                  Icon(
                    Icons.people_alt,
                    size: 13,
                    color: done
                        ? doneFg.withOpacity(0.5)
                        : notDoneFg.withOpacity(0.35),
                  ),
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${streak.currentStreak}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: done ? doneFg : notDoneFg,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  streak.isDaily ? 'days' : 'wks',
                  style: TextStyle(
                    fontSize: 12,
                    color: done
                        ? doneFg.withOpacity(0.6)
                        : notDoneFg.withOpacity(0.45),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              streak.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: done ? doneFg : notDoneFg,
              ),
            ),
            if (!streak.isDaily) ...[
              const SizedBox(height: 2),
              Text(
                '${streak.checkInsThisWeek}/${streak.weeklyTarget} this wk',
                style: TextStyle(
                  fontSize: 10,
                  color: done
                      ? doneFg.withOpacity(0.55)
                      : notDoneFg.withOpacity(0.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Add / friends buttons ──────────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
        child: const Icon(Icons.add, size: 16, color: Colors.white),
      ),
    );
  }
}

class _FriendsIconButton extends StatelessWidget {
  final VoidCallback onTap;

  const _FriendsIconButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final count = FriendService.instance.friends.length;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(Icons.people_outline, size: 16, color: Theme.of(context).colorScheme.onSurface),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Text(
                '$count',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Self-care row ──────────────────────────────────────────────────────────

class _SelfCareRow extends StatelessWidget {
  final SelfCareTask task;
  final VoidCallback onToggle;

  const _SelfCareRow({required this.task, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: task.isDone ? Colors.black : Colors.transparent,
                border: task.isDone
                    ? null
                    : Border.all(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.25), width: 1.5),
              ),
              child: task.isDone
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            task.icon,
            size: 17,
            color:
                task.isDone ? Theme.of(context).colorScheme.onSurface.withOpacity(0.35) : Colors.black,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              task.name,
              style: TextStyle(
                fontSize: 14,
                color: task.isDone
                    ? Theme.of(context).colorScheme.onSurface.withOpacity(0.4)
                    : Colors.black,
                decoration:
                    task.isDone ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          Text(
            task.statusLabel,
            style: TextStyle(
                fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
          ),
        ],
      ),
    );
  }
}

// ── Find care banner ───────────────────────────────────────────────────────

class _FindCareBanner extends StatelessWidget {
  final String query;

  const _FindCareBanner({required this.query});

  @override
  Widget build(BuildContext context) {
    final label =
        query.contains('therapist') ? 'a therapist' : 'a doctor';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.search, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Need to find $label?',
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Icon(Icons.north_east,
              size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
        ],
      ),
    );
  }
}

// ── Appointment row ────────────────────────────────────────────────────────

class _AppointmentRow extends StatelessWidget {
  final Appointment appointment;

  const _AppointmentRow({required this.appointment});

  IconData get _icon {
    switch (appointment.type) {
      case AppointmentType.doctor:
        return Icons.medical_services_outlined;
      case AppointmentType.therapy:
        return Icons.psychology_outlined;
      case AppointmentType.other:
        return Icons.event_outlined;
    }
  }

  Future<void> _open() async {
    if (appointment.htmlLink == null) return;
    final uri = Uri.parse(appointment.htmlLink!);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: appointment.htmlLink != null ? _open : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon,
                  size: 18, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appointment.summary,
                      style: const TextStyle(fontSize: 14)),
                  Text(
                    appointment.dateLabel,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.45)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}

// ── Connect Calendar banner ────────────────────────────────────────────────

class _ConnectCalendarBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _ConnectCalendarBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.1)),
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
              child: Icon(Icons.event_available_outlined,
                  size: 20, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Connect Google Calendar',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  Text('See your doctor & therapy appointments here',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5))),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}

// ── Add appointment sheet ──────────────────────────────────────────────────

class _AddAppointmentSheet extends StatefulWidget {
  const _AddAppointmentSheet();

  @override
  State<_AddAppointmentSheet> createState() => _AddAppointmentSheetState();
}

class _AddAppointmentSheetState extends State<_AddAppointmentSheet> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String get _dateLabel {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[_date.month - 1]} ${_date.day}, ${_date.year}';
  }

  String get _timeLabel {
    final h = _time.hour % 12 == 0 ? 12 : _time.hour % 12;
    final m = _time.minute.toString().padLeft(2, '0');
    final ampm = _time.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    final start = DateTime(
        _date.year, _date.month, _date.day, _time.hour, _time.minute);
    final ok = await CalendarService.createEvent(
      title: title,
      start: start,
      location: _locationController.text.trim(),
      notes: _notesController.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save to Google Calendar')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('New appointment',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'e.g. Dr. Smith · Annual physical',
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: _PickerChip(
                      icon: Icons.calendar_today_outlined, label: _dateLabel),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: _pickTime,
                  child: _PickerChip(
                      icon: Icons.access_time_outlined, label: _timeLabel),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _locationController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Location (optional)',
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notesController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Notes (optional)',
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _saving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary),
                    )
                  : const Text('Save to Google Calendar',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PickerChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Crisis card ────────────────────────────────────────────────────────────

class _CrisisCard extends StatelessWidget {
  final VoidCallback onCall;
  final VoidCallback onText;

  const _CrisisCard({required this.onCall, required this.onText});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Need to talk to someone now?',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            '988 Suicide & Crisis Lifeline · available 24/7',
            style: TextStyle(
                fontSize: 12, color: Colors.white.withOpacity(0.6)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCall,
                  icon: const Icon(Icons.call, size: 16, color: Colors.white),
                  label: const Text('Call 988',
                      style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onText,
                  icon: const Icon(Icons.message_outlined,
                      size: 16, color: Colors.white),
                  label: const Text('Text 988',
                      style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Create streak sheet ────────────────────────────────────────────────────

class _CreateStreakSheet extends StatefulWidget {
  const _CreateStreakSheet();

  @override
  State<_CreateStreakSheet> createState() => _CreateStreakSheetState();
}

class _CreateStreakSheetState extends State<_CreateStreakSheet> {
  final TextEditingController nameController = TextEditingController();
  IconData selectedIcon = Icons.star_outline;
  StreakCadence cadence = StreakCadence.daily;
  int weeklyTarget = 3;
  bool shareWithFriends = false;

  static const List<IconData> iconChoices = [
    Icons.fitness_center,
    Icons.menu_book_outlined,
    Icons.edit_note,
    Icons.self_improvement,
    Icons.water_drop_outlined,
    Icons.directions_run,
    Icons.local_drink_outlined,
    Icons.star_outline,
  ];

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void _create() {
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      Streak(
        id: 'streak-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        icon: selectedIcon,
        cadence: cadence,
        weeklyTarget: weeklyTarget,
        sharedWithFriends: shareWithFriends,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFriends = FriendService.instance.friends.isNotEmpty;

    return _BottomSheetScaffold(
      title: 'New streak',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: 'e.g. Reading, Gym, Bible study',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Icon',
                style:
                    TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: iconChoices.map((icon) {
                final selected = icon == selectedIcon;
                final th = Theme.of(context);
                return GestureDetector(
                  onTap: () => setState(() => selectedIcon = icon),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? th.colorScheme.primary
                          : th.colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon,
                        size: 20,
                        color: selected ? th.colorScheme.onPrimary : th.colorScheme.onSurface),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text('How often?',
                style:
                    TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _CadenceOption(
                    label: 'Daily',
                    selected: cadence == StreakCadence.daily,
                    onTap: () =>
                        setState(() => cadence = StreakCadence.daily),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CadenceOption(
                    label: 'Weekly',
                    selected: cadence == StreakCadence.weekly,
                    onTap: () =>
                        setState(() => cadence = StreakCadence.weekly),
                  ),
                ),
              ],
            ),
            if (cadence == StreakCadence.weekly) ...[
              const SizedBox(height: 16),
              Text(
                '$weeklyTarget time${weeklyTarget == 1 ? '' : 's'} per week',
                style:
                    TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
              ),
              Slider(
                value: weeklyTarget.toDouble(),
                min: 1,
                max: 7,
                divisions: 6,
                activeColor: Colors.black,
                onChanged: (v) =>
                    setState(() => weeklyTarget = v.round()),
              ),
            ],
            const SizedBox(height: 8),
            if (hasFriends)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: shareWithFriends,
                onChanged: (v) => setState(() => shareWithFriends = v),
                activeColor: Colors.black,
                title: const Text('Share with friends',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: const Text(
                    "They'll see your streak count and can compete",
                    style: TextStyle(fontSize: 12)),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
                child: const Text('Create streak',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CadenceOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CadenceOption(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? th.colorScheme.primary : th.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? th.colorScheme.onPrimary : th.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Streak detail sheet ────────────────────────────────────────────────────

class _StreakDetailSheet extends StatefulWidget {
  final Streak streak;

  const _StreakDetailSheet({required this.streak});

  @override
  State<_StreakDetailSheet> createState() => _StreakDetailSheetState();
}

class _StreakDetailSheetState extends State<_StreakDetailSheet> {
  late bool shareWithFriends = widget.streak.sharedWithFriends;

  @override
  Widget build(BuildContext context) {
    final streak = widget.streak;
    final hasFriends = FriendService.instance.friends.isNotEmpty;

    return _BottomSheetScaffold(
      title: streak.name,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatPill(
                    label: 'Current', value: '${streak.currentStreak}'),
                const SizedBox(width: 10),
                _StatPill(label: 'Best', value: '${streak.bestStreak}'),
              ],
            ),
            const SizedBox(height: 18),
            if (hasFriends)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: shareWithFriends,
                onChanged: (v) {
                  setState(() => shareWithFriends = v);
                  streak.sharedWithFriends = v;
                },
                activeColor: Colors.black,
                title: const Text('Share with friends',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            if (shareWithFriends && hasFriends) ...[
              const SizedBox(height: 8),
              ...FriendService.instance.friends.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _FriendCompareRow(
                    friendName: f.name,
                    myStreak: streak.currentStreak,
                    friendStreak: (streak.currentStreak - 2)
                        .clamp(0, streak.currentStreak + 5),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, 'delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25)),
                ),
                child: const Text('Delete streak'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;

  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
          ],
        ),
      ),
    );
  }
}

class _FriendCompareRow extends StatelessWidget {
  final String friendName;
  final int myStreak;
  final int friendStreak;

  const _FriendCompareRow({
    required this.friendName,
    required this.myStreak,
    required this.friendStreak,
  });

  @override
  Widget build(BuildContext context) {
    final ahead = myStreak >= friendStreak;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(friendName,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          Text(
            '$friendStreak',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: ahead ? Theme.of(context).colorScheme.onSurface.withOpacity(0.54) : Colors.black,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            ahead ? Icons.emoji_events_outlined : Icons.trending_up,
            size: 16,
            color: ahead ? Theme.of(context).colorScheme.onSurface.withOpacity(0.38) : Colors.green,
          ),
        ],
      ),
    );
  }
}

// ── Friends sheet ──────────────────────────────────────────────────────────

class _FriendsSheet extends StatefulWidget {
  const _FriendsSheet();

  @override
  State<_FriendsSheet> createState() => _FriendsSheetState();
}

class _FriendsSheetState extends State<_FriendsSheet> {
  final TextEditingController codeController = TextEditingController();
  String? errorText;

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  void _connect() {
    final friend =
        FriendService.instance.connectWithCode(codeController.text);
    if (friend == null) {
      setState(() => errorText =
          "That code doesn't look right — check and try again");
      return;
    }
    setState(() {
      errorText = null;
      codeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final myCode = FriendService.instance.getOrCreateMyInviteCode();
    final friends = FriendService.instance.friends;

    return _BottomSheetScaffold(
      title: 'Friends',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your invite code',
                style:
                    TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    myCode,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Share this with a friend to connect',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Have a code?',
                style:
                    TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Enter code',
                      errorText: errorText,
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _connect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Connect'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (friends.isEmpty)
              const _MessageState(message: 'No friends connected yet')
            else ...[
              const Text('Connected',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              ...friends.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(f.name,
                                style: const TextStyle(fontSize: 14))),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Bottom sheet scaffold ──────────────────────────────────────────────────

class _BottomSheetScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const _BottomSheetScaffold({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
