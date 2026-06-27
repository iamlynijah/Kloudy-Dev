import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_onboarding_data.dart';

/// Central place for Supabase config + helper methods.
class SupabaseService {
  static const String _supabaseUrl = 'https://aoepanrphyhmtlktftyg.supabase.co';
  static const String _supabaseAnonKey =
      'sb_publishable_gAMYjifv46LY9D7VdJcrcQ_0ouCz4SI';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
    );
  }

  static User? get currentUser => client.auth.currentUser;

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
      client.from('mood_logs').insert({
        'user_id': userId,
        'mood': mood,
      }),
      // Current mood on profile — overwrites each time, used purely
      // to restore the highlighted state on next app launch.
      client.from('profiles').update({
        'current_mood': mood,
      }).eq('id', userId),
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
  }

  // ── Fetch saved health data ──
  static Future<Map<String, dynamic>?> fetchHealthData() async {
    final profile = await fetchProfile();
    final answers = profile?['answers'] as Map<String, dynamic>?;
    return answers?['health'] as Map<String, dynamic>?;
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

  static Future<void> saveSleepLog(double hours) async {
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
      (sleepMap['logs'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final idx = logs.indexWhere((l) => l['date'] == todayStr);
    if (idx >= 0) {
      logs[idx] = {'date': todayStr, 'hours': hours};
    } else {
      logs.add({'date': todayStr, 'hours': hours});
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
    final userId = currentUser?.id;
    if (userId == null) return;
    final existing = await fetchProfile();
    final answers = Map<String, dynamic>.from(
      (existing?['answers'] as Map<String, dynamic>?) ?? {},
    );
    final prefs = Map<String, dynamic>.from(
      (answers['prefs'] as Map<String, dynamic>?) ?? {},
    );
    prefs['theme'] = theme;
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
    final row = await client.from('chat_sessions').insert({
      'user_id': userId,
      'title': title,
    }).select().single();
    return row['id'] as String;
  }

  static Future<void> updateSessionTitle(String sessionId, String title) async {
    try {
      await client.from('chat_sessions').update({
        'title': title,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', sessionId);
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
      var query = client
          .from('chat_messages')
          .select()
          .eq('user_id', userId);
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
        'lose_weight', 'build_muscle', 'improve_nutrition',
        'improve_sleep', 'improve_mental_health', 'build_healthier_habits',
        'save_money', 'build_wealth',
      ]) {
        if (profile?[key] == true) context[key] = true;
      }

      // Mood
      context['mood'] = profile?['current_mood'] as String?;

      // Sleep
      final logs = (sleep?['logs'] as List<dynamic>? ?? []);
      context['sleep_streak'] = sleep?['streak'] as int? ?? 0;
      context['logged_sleep_today'] = logs.any((l) => (l as Map)['date'] == today);
      if (logs.isNotEmpty) {
        final recent = logs.reversed.take(7).toList();
        final total = recent.fold<double>(0, (s, l) => s + ((l as Map)['hours'] as num).toDouble());
        context['avg_sleep_7d'] = total / recent.length;
      }

      // Nutrition
      final foodLogs = nutrition?['food_logs'] as Map<String, dynamic>?;
      final todayEntries = (foodLogs?[today] as List<dynamic>? ?? []);
      final calsToday = todayEntries.fold<int>(0, (s, e) => s + ((e as Map)['calories'] as num).toInt());
      if (calsToday > 0) context['calories_today'] = calsToday;
      final nutritionProfile = nutrition?['profile'] as Map<String, dynamic>?;
      final calorieGoal = nutritionProfile?['dailyCalorieTarget'] as int?;
      if (calorieGoal != null) context['calorie_goal'] = calorieGoal;

      // Finance
      final financeAnswers = (profile?['answers'] as Map?)?['finance'] as Map<String, dynamic>?;
      final weeklyBudget = (financeAnswers?['weekly_budget'] as num?)?.toDouble();
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