import 'package:shared_preferences/shared_preferences.dart';

class DemoProfile {
  static const _readyKey = 'kloudy_demo_ready';
  static const _nameKey = 'kloudy_demo_name';
  static const _goalsKey = 'kloudy_demo_goals';

  static String name = 'Jordan';
  static Set<String> goals = {'save_money', 'improve_nutrition'};
  static bool isDemo = true;

  static Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    name = prefs.getString(_nameKey) ?? 'Jordan';
    goals = (prefs.getStringList(_goalsKey) ?? ['save_money', 'improve_nutrition']).toSet();
    return prefs.getBool(_readyKey) ?? false;
  }

  static Future<void> save({required String displayName, required Set<String> selectedGoals}) async {
    final prefs = await SharedPreferences.getInstance();
    name = displayName.trim().isEmpty ? 'friend' : displayName.trim();
    goals = Set.of(selectedGoals);
    await prefs.setString(_nameKey, name);
    await prefs.setStringList(_goalsKey, goals.toList());
    await prefs.setBool(_readyKey, true);
  }
}
