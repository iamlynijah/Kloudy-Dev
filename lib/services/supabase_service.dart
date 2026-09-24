import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_onboarding_data.dart';
import '../demo/demo_profile.dart';

/// Central place for Supabase config + helper methods.
class SupabaseService {
  static const String authRedirectUrl = 'kloudy://login-callback/';
  static const String _supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://aoepanrphyhmtlktftyg.supabase.co',
  );
  static const String _supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_gAMYjifv46LY9D7VdJcrcQ_0ouCz4SI',
  );

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    if (_initialized) return;
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabasePublishableKey,
    );
    _initialized = true;
  }

  static User? get currentUser =>
      DemoProfile.isDemo ? null : client.auth.currentUser;

  // ── Save onboarding data to profiles table ──
  static Future<void> saveProfile(UserOnboardingData data) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('No authenticated user.');

    await client.from('profiles').upsert({
      'id': userId,
      'name': data.name,
      'age': data.age,
      'lifestyle': data.lifestyle,
      'lose_weight': data.loseWeight,
      'build_muscle': data.buildMuscle,
      'improve_nutrition': data.improveNutrition,
      'build_healthier_habits': data.buildHealthierHabits,
      'improve_sleep': data.improveSleep,
      'stay_on_top_of_healthcare': data.stayOnTopOfHealthcare,
      'save_money': data.saveMoney,
      'pay_off_debt': data.payOffDebt,
      'spend_more_intentionally': data.spendMoreIntentionally,
      'increase_income': data.increaseIncome,
      'improve_mental_health': data.improveMentalHealth,
      'answers': data.answers,
    });
  }

  // ── Fetch user profile ──
  static Future<Map<String, dynamic>?> fetchProfile() async {
    final userId = currentUser?.id;
    if (userId == null) return null;

    return await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
  }

  // ── Save mood: logs to mood_logs + updates current_mood on profile ──
  // Both writes happen together so we always have both the history
  // (for future pattern analysis) and the "last known mood" to restore
  // on next app launch without querying the full log.
  static Future<void> saveMood(String mood) async {
    final userId = currentUser?.id;
    if (userId == null) return;

    await Future.wait([
      // Time-series log — never overwritten, accumulates indefinitely.
      // This is what enables the sleep/mood/spending correlation analysis later.
      client.from('mood_logs').insert({'user_id': userId, 'mood': mood}),
      // Current mood on profile — overwrites each time, used purely
      // to restore the highlighted state on next app launch.
      client.from('profiles').update({'current_mood': mood}).eq('id', userId),
    ]);
  }

  // ── Fetch current mood (for restoring highlighted state on launch) ──
  static Future<String?> fetchCurrentMood() async {
    final profile = await fetchProfile();
    return profile?['current_mood'] as String?;
  }

  // ── Save finance onboarding data into answers['finance'] ──
  // Merges with existing answers so onboarding data is preserved.
  static Future<void> saveFinanceData(Map<String, dynamic> data) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    final existing = await fetchProfile();
    final answers = Map<String, dynamic>.from(
      (existing?['answers'] as Map<String, dynamic>?) ?? {},
    );
    answers['finance'] = data;
    await client.from('profiles').upsert({'id': userId, 'answers': answers});
  }

  // ── Fetch saved finance data ──
  static Future<Map<String, dynamic>?> fetchFinanceData() async {
    final profile = await fetchProfile();
    final answers = profile?['answers'] as Map<String, dynamic>?;
    return answers?['finance'] as Map<String, dynamic>?;
  }

  // ── Save health onboarding data into answers['health'] ──
  static Future<void> saveHealthData(Map<String, dynamic> data) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    final existing = await fetchProfile();
    final answers = Map<String, dynamic>.from(
      (existing?['answers'] as Map<String, dynamic>?) ?? {},
    );
    answers['health'] = data;
    await client.from('profiles').upsert({'id': userId, 'answers': answers});
    try {
      await _syncHabitTables(userId, data);
    } catch (error) {
      // The profile JSON remains the compatibility source until the additive
      // streak migration is applied to the Supabase project.
      debugPrint('[SupabaseService] Habit table sync failed: $error');
    }
  }

  static Future<void> _syncHabitTables(
    String userId,
    Map<String, dynamic> healthData,
  ) async {
    final streaks = (healthData['streaks'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final existing = await client
        .from('habits')
        .select('id')
        .eq('user_id', userId);
    final existingIds = (existing as List)
        .map((row) => row['id'] as String)
        .toSet();
    final incomingIds = streaks.map((row) => row['id'] as String).toSet();

    for (final staleId in existingIds.difference(incomingIds)) {
      await client
          .from('habits')
          .delete()
          .eq('user_id', userId)
          .eq('id', staleId);
    }
    if (streaks.isEmpty) return;

    final habitRows = streaks.map((streak) {
      return {
        'id': streak['id'],
        'user_id': userId,
        'name': streak['name'],
        'icon_code_point': streak['icon_code_point'],
        'cadence': streak['cadence'],
        'weekly_target': streak['weekly_target'] ?? 3,
        'scheduled_days': streak['scheduled_days'] ?? [1, 3, 5],
        'current_streak': streak['current_streak'] ?? 0,
        'best_streak': streak['best_streak'] ?? 0,
        'shared_with_friends': streak['shared_with_friends'] ?? false,
        'auto_evaluated': streak['auto_evaluated'] ?? false,
        'is_active': true,
      };
    }).toList();
    await client.from('habits').upsert(habitRows, onConflict: 'user_id,id');

    final checkIns = <Map<String, dynamic>>[];
    for (final streak in streaks) {
      for (final rawDate in (streak['check_ins'] as List<dynamic>? ?? [])) {
        final date = DateTime.parse(rawDate as String);
        checkIns.add({
          'habit_id': streak['id'],
          'user_id': userId,
          'completed_on': date.toIso8601String().split('T').first,
        });
      }
    }
    if (checkIns.isNotEmpty) {
      await client
          .from('habit_check_ins')
          .upsert(
            checkIns,
            onConflict: 'habit_id,user_id,completed_on',
            ignoreDuplicates: true,
          );
    }
  }

  // ── Fetch saved health data ──
  static Future<Map<String, dynamic>?> fetchHealthData() async {
    final profile = await fetchProfile();
    final answers = profile?['answers'] as Map<String, dynamic>?;
    return answers?['health'] as Map<String, dynamic>?;
  }

  static Future<String> createFriendInvite() async {
    final code = await client.rpc('create_friend_invite');
    return code as String;
  }

  static Future<String> createStreakInvite({
    required String streakName,
    required String cadence,
  }) async {
    final code = await client.rpc(
      'create_streak_invite',
      params: {'p_streak_name': streakName, 'p_cadence': cadence},
    );
    return code as String;
  }

  static Future<String> acceptFriendInvite(String code) async {
    final friendId = await client.rpc(
      'accept_friend_invite',
      params: {'p_code': code},
    );
    return friendId.toString();
  }

  static Future<List<Map<String, dynamic>>> fetchFriends() async {
    final rows = await client.rpc('get_my_friends');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  static Future<void> removeFriend(String friendId) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    final pair = [userId, friendId]..sort();
    await client
        .from('friend_connections')
        .delete()
        .eq('member_low', pair.first)
        .eq('member_high', pair.last);
  }

  static Future<Map<String, dynamic>?> fetchSharedHabit(
    String friendId,
    String habitName,
  ) async {
    final rows = await client
        .from('habits')
        .select('id,name,current_streak,best_streak,updated_at')
        .eq('user_id', friendId)
        .eq('name', habitName)
        .eq('shared_with_friends', true)
        .eq('is_active', true)
        .limit(1);
    final habits = rows as List;
    if (habits.isEmpty) return null;
    final habit = Map<String, dynamic>.from(habits.first as Map);
    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final checkIns = await client
        .from('habit_check_ins')
        .select('id')
        .eq('user_id', friendId)
        .eq('habit_id', habit['id'] as String)
        .gte('completed_on', weekStart.toIso8601String().split('T').first)
        .limit(1);
    habit['active_this_week'] = (checkIns as List).isNotEmpty;
    return habit;
  }

  // ── Save nutrition data into answers['nutrition'] ──
  static Future<void> saveNutritionData(Map<String, dynamic> data) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    final existing = await fetchProfile();
    final answers = Map<String, dynamic>.from(
      (existing?['answers'] as Map<String, dynamic>?) ?? {},
    );
    answers['nutrition'] = data;
    await client.from('profiles').upsert({'id': userId, 'answers': answers});
  }

  // ── Fetch saved nutrition data ──
  static Future<Map<String, dynamic>?> fetchNutritionData() async {
    final profile = await fetchProfile();
    final answers = profile?['answers'] as Map<String, dynamic>?;
    return answers?['nutrition'] as Map<String, dynamic>?;
  }

  // ── Save mindset / wellness data into answers['mindset'] ──
  static Future<void> saveMindsetData(Map<String, dynamic> data) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    final existing = await fetchProfile();
    final answers = Map<String, dynamic>.from(
      (existing?['answers'] as Map<String, dynamic>?) ?? {},
    );
    answers['mindset'] = data;
    await client.from('profiles').upsert({'id': userId, 'answers': answers});
  }

  // ── Fetch saved mindset data ──
  static Future<Map<String, dynamic>?> fetchMindsetData() async {
    final profile = await fetchProfile();
    final answers = profile?['answers'] as Map<String, dynamic>?;
    return answers?['mindset'] as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> fetchLearningData() async {
    final profile = await fetchProfile();
    final answers = profile?['answers'] as Map<String, dynamic>?;
    return answers?['learning'] as Map<String, dynamic>?;
  }

  static Future<void> saveLearningData(Map<String, dynamic> data) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    final existing = await fetchProfile();
    final answers = Map<String, dynamic>.from(
      (existing?['answers'] as Map<String, dynamic>?) ?? {},
    );
    answers['learning'] = data;
    await client.from('profiles').upsert({'id': userId, 'answers': answers});
  }

  // ── Set individual goal flags on the profile row ──
  // Used when a user unlocks a tab that wasn't part of their initial goals.
  static Future<void> setGoalFlags(Map<String, bool> flags) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    await client.from('profiles').upsert({'id': userId, ...flags});
  }

  // ── Sleep streak helpers ──
  static int _calcSleepStreak(List<Map<String, dynamic>> logs) {
    if (logs.isEmpty) return 0;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final first = DateTime.parse(logs.first['date'] as String);
    final firstOnly = DateTime(first.year, first.month, first.day);
    if (todayOnly.difference(firstOnly).inDays > 1) return 0;
    int streak = 0;
    DateTime expected = firstOnly;
    for (final log in logs) {
      final d = DateTime.parse(log['date'] as String);
      final dOnly = DateTime(d.year, d.month, d.day);
      if (dOnly != expected) break;
      if ((log['hours'] as num) >= 7) {
        streak++;
        expected = expected.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  static Future<void> saveSleepLog(
    double hours, {
    String? bedTime,
    String? wakeTime,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    final existing = await fetchProfile();
    final answers = Map<String, dynamic>.from(
      (existing?['answers'] as Map<String, dynamic>?) ?? {},
    );
    final sleepMap = Map<String, dynamic>.from(
      (answers['sleep'] as Map<String, dynamic>?) ?? {},
    );
    final logs = List<Map<String, dynamic>>.from(
      (sleepMap['logs'] as List? ?? []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final idx = logs.indexWhere((l) => l['date'] == todayStr);
    if (idx >= 0) {
      logs[idx] = {
        'date': todayStr,
        'hours': hours,
        if (bedTime != null) 'bed_time': bedTime,
        if (wakeTime != null) 'wake_time': wakeTime,
      };
    } else {
      logs.add({
        'date': todayStr,
        'hours': hours,
        if (bedTime != null) 'bed_time': bedTime,
        if (wakeTime != null) 'wake_time': wakeTime,
      });
    }
    logs.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    final trimmed = logs.take(90).toList();
    sleepMap['logs'] = trimmed;
    sleepMap['streak'] = _calcSleepStreak(trimmed);
    answers['sleep'] = sleepMap;
    await client.from('profiles').upsert({'id': userId, 'answers': answers});
  }

  static Future<Map<String, dynamic>?> fetchSleepData() async {
    final profile = await fetchProfile();
    final answers = profile?['answers'] as Map<String, dynamic>?;
    return answers?['sleep'] as Map<String, dynamic>?;
  }

  // ── Save username (stored in answers['profile']) ──
  static Future<void> saveUsername(String username) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    final existing = await fetchProfile();
    final answers = Map<String, dynamic>.from(
      (existing?['answers'] as Map<String, dynamic>?) ?? {},
    );
    final profileSection = Map<String, dynamic>.from(
      (answers['profile'] as Map<String, dynamic>?) ?? {},
    );
    profileSection['username'] = username;
    answers['profile'] = profileSection;
    await client.from('profiles').upsert({'id': userId, 'answers': answers});
  }

  // ── Tutorial shown flag ──
  static Future<bool> fetchTutorialShown() async {
    final profile = await fetchProfile();
    final answers = profile?['answers'] as Map<String, dynamic>?;
    final p = answers?['profile'] as Map<String, dynamic>?;
    return p?['tutorial_shown'] as bool? ?? false;
  }

  static Future<void> saveTutorialShown() async {
    final userId = currentUser?.id;
    if (userId == null) return;
    final existing = await fetchProfile();
    final answers = Map<String, dynamic>.from(
      (existing?['answers'] as Map<String, dynamic>?) ?? {},
    );
    final profileSection = Map<String, dynamic>.from(
      (answers['profile'] as Map<String, dynamic>?) ?? {},
    );
    profileSection['tutorial_shown'] = true;
    answers['profile'] = profileSection;
    await client.from('profiles').upsert({'id': userId, 'answers': answers});
  }

  // ── Save avatar base64 (stored in answers['profile']['avatar_base64']) ──
  static Future<void> saveAvatarBase64(String base64) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    final existing = await fetchProfile();
    final answers = Map<String, dynamic>.from(
      (existing?['answers'] as Map<String, dynamic>?) ?? {},
    );
    final profileSection = Map<String, dynamic>.from(
      (answers['profile'] as Map<String, dynamic>?) ?? {},
    );
    profileSection['avatar_base64'] = base64;
    answers['profile'] = profileSection;
    await client.from('profiles').upsert({'id': userId, 'answers': answers});
  }

  // ── Save theme preference (stored in answers['prefs']) ──
  static Future<void> saveThemePreference(String theme) async {
    await savePreference('theme', theme);
  }

  static Future<void> savePreference(String key, dynamic value) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    final existing = await fetchProfile();
    final answers = Map<String, dynamic>.from(
      (existing?['answers'] as Map<String, dynamic>?) ?? {},
    );
    final prefs = Map<String, dynamic>.from(
      (answers['prefs'] as Map<String, dynamic>?) ?? {},
    );
    prefs[key] = value;
    answers['prefs'] = prefs;
    await client.from('profiles').upsert({'id': userId, 'answers': answers});
  }

  // ── Delete account — removes all profile data then signs out ──
  static Future<void> deleteAccount() async {
    final userId = currentUser?.id;
    if (userId == null) return;
    await Future.wait([
      client.from('profiles').delete().eq('id', userId),
      client.from('mood_logs').delete().eq('user_id', userId),
      client.from('tasks').delete().eq('user_id', userId),
    ]);
    await client.auth.signOut();
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  // ── Chat sessions ──────────────────────────────────────────────────────────

  static Future<String> createChatSession({String title = 'New chat'}) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    final row = await client
        .from('chat_sessions')
        .insert({'user_id': userId, 'title': title})
        .select()
        .single();
    return row['id'] as String;
  }

  static Future<void> updateSessionTitle(String sessionId, String title) async {
    try {
      await client
          .from('chat_sessions')
          .update({
            'title': title,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sessionId);
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> fetchChatSessions() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    try {
      return List<Map<String, dynamic>>.from(
        await client
            .from('chat_sessions')
            .select()
            .eq('user_id', userId)
            .order('updated_at', ascending: false)
            .limit(50),
      );
    } catch (_) {
      return [];
    }
  }

  // ── Chat history ───────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchChatHistory({
    int limit = 40,
    String? sessionId,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    try {
      var query = client.from('chat_messages').select().eq('user_id', userId);
      if (sessionId != null) {
        query = query.eq('session_id', sessionId);
      }
      final rows = await query.order('created_at').limit(limit);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveChatMessage({
    required String role,
    required String content,
    String? sessionId,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    try {
      await client.from('chat_messages').insert({
        'user_id': userId,
        'role': role,
        'content': content,
        if (sessionId != null) 'session_id': sessionId,
      });
    } catch (_) {}
  }

  // ── Build AI user context from all data sources ────────────────────────────

  static Future<Map<String, dynamic>> buildAiContext() async {
    try {
      final results = await Future.wait([
        fetchProfile(),
        fetchNutritionData(),
        fetchSleepData(),
        fetchFinanceData(),
      ]);

      final profile = results[0];
      final nutrition = results[1];
      final sleep = results[2];
      // results[3] is finance — used below via profile answers

      final today = DateTime.now().toIso8601String().split('T').first;
      final context = <String, dynamic>{};

      // Goals from profile
      for (final key in [
        'lose_weight',
        'build_muscle',
        'improve_nutrition',
        'improve_sleep',
        'improve_mental_health',
        'build_healthier_habits',
        'save_money',
        'build_wealth',
      ]) {
        if (profile?[key] == true) context[key] = true;
      }

      // Mood
      context['mood'] = profile?['current_mood'] as String?;
      final answers = profile?['answers'] as Map<String, dynamic>? ?? {};
      final mindsetGoals =
          answers['mindset_goals'] as Map<String, dynamic>? ?? {};
      context['mindset_challenges'] =
          mindsetGoals['mental_challenges'] ?? const <String>[];
      context['mindset_first_to_suffer'] =
          mindsetGoals['mental_first_to_suffer'] ?? const <String>[];

      // Sleep
      final logs = (sleep?['logs'] as List<dynamic>? ?? []);
      context['sleep_streak'] = sleep?['streak'] as int? ?? 0;
      context['logged_sleep_today'] = logs.any(
        (l) => (l as Map)['date'] == today,
      );
      if (logs.isNotEmpty) {
        final recent = logs.reversed.take(7).toList();
        final total = recent.fold<double>(
          0,
          (s, l) => s + ((l as Map)['hours'] as num).toDouble(),
        );
        context['avg_sleep_7d'] = total / recent.length;
      }

      // Nutrition
      final foodLogs = nutrition?['food_logs'] as Map<String, dynamic>?;
      final todayEntries = (foodLogs?[today] as List<dynamic>? ?? []);
      final calsToday = todayEntries.fold<int>(
        0,
        (s, e) => s + ((e as Map)['calories'] as num).toInt(),
      );
      if (calsToday > 0) context['calories_today'] = calsToday;
      final nutritionProfile = nutrition?['profile'] as Map<String, dynamic>?;
      final calorieGoal = nutritionProfile?['calorie_goal'] as int?;
      if (calorieGoal != null) context['calorie_goal'] = calorieGoal;

      // Finance
      final financeAnswers =
          (profile?['answers'] as Map?)?['finance'] as Map<String, dynamic>?;
      final weeklyBudget = (financeAnswers?['weekly_budget'] as num?)
          ?.toDouble();
      if (weeklyBudget != null) {
        context['weekly_budget'] = weeklyBudget;
        // Spending would come from transaction data; placeholder for now
      }

      return context;
    } catch (e) {
      return {};
    }
  }
}
