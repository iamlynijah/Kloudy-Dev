// Models and TDEE helpers for the Nutrition tab.

enum NutritionGoalType { loseFat, buildMuscle, recomposition, maintain }

extension NutritionGoalTypeX on NutritionGoalType {
  String get label => switch (this) {
        NutritionGoalType.loseFat => 'Lose fat',
        NutritionGoalType.buildMuscle => 'Build muscle',
        NutritionGoalType.recomposition => 'Recomposition',
        NutritionGoalType.maintain => 'Maintain',
      };
  bool get hasWeightGoal => this != NutritionGoalType.maintain;
}

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

extension ActivityLevelX on ActivityLevel {
  String get label => switch (this) {
        ActivityLevel.sedentary => 'Sedentary',
        ActivityLevel.light => 'Lightly active',
        ActivityLevel.moderate => 'Moderately active',
        ActivityLevel.active => 'Very active',
        ActivityLevel.veryActive => 'Athlete',
      };
  String get description => switch (this) {
        ActivityLevel.sedentary => 'Desk job, little exercise',
        ActivityLevel.light => '1-3 workouts/week',
        ActivityLevel.moderate => '3-5 workouts/week',
        ActivityLevel.active => '6-7 workouts/week',
        ActivityLevel.veryActive => '2x/day or physical job',
      };
  double get tdeeMultiplier => switch (this) {
        ActivityLevel.sedentary => 1.2,
        ActivityLevel.light => 1.375,
        ActivityLevel.moderate => 1.55,
        ActivityLevel.active => 1.725,
        ActivityLevel.veryActive => 1.9,
      };
}

enum GlpMed { none, ozempic, wegovy, mounjaro, tirzepatide, phentermine, metformin, other }

extension GlpMedX on GlpMed {
  String get label => switch (this) {
        GlpMed.none => 'None',
        GlpMed.ozempic => 'Ozempic',
        GlpMed.wegovy => 'Wegovy',
        GlpMed.mounjaro => 'Mounjaro',
        GlpMed.tirzepatide => 'Tirzepatide',
        GlpMed.phentermine => 'Phentermine',
        GlpMed.metformin => 'Metformin',
        GlpMed.other => 'Other',
      };
}

// ── Profile model ──────────────────────────────────────────────────────────

class NutritionProfile {
  final NutritionGoalType goalType;
  final double paceLbsPerWeek;
  final double startWeightLbs;
  final double goalWeightLbs;
  final double heightInches;
  final String sex; // 'male', 'female', 'other'
  final int age;
  final ActivityLevel activityLevel;
  final List<String> dietStyles;
  final List<String> foodSensitivities;
  final int mealsPerDay;
  final int flexDaysPerWeek;
  final bool trackAlcohol;
  final List<String> medications;
  final bool medicationReminders;
  final String reminderFrequency; // 'daily', 'twice_daily', 'as_needed'
  final List<String> reminderTimes; // e.g. ['08:00'] or ['08:00', '20:00']
  final List<String> supplements;
  final String motivation;
  // Macro targets (computed + user-overridable)
  final int calorieGoal;
  final int proteinGoal;
  final int carbGoal;
  final int fatGoal;
  final int waterCupsGoal;

  const NutritionProfile({
    required this.goalType,
    this.paceLbsPerWeek = 1.0,
    required this.startWeightLbs,
    this.goalWeightLbs = 0,
    required this.heightInches,
    required this.sex,
    required this.age,
    required this.activityLevel,
    this.dietStyles = const [],
    this.foodSensitivities = const [],
    this.mealsPerDay = 3,
    this.flexDaysPerWeek = 0,
    this.trackAlcohol = false,
    this.medications = const [],
    this.medicationReminders = false,
    this.reminderFrequency = 'daily',
    this.reminderTimes = const ['08:00'],
    this.supplements = const [],
    this.motivation = 'all',
    required this.calorieGoal,
    required this.proteinGoal,
    required this.carbGoal,
    required this.fatGoal,
    this.waterCupsGoal = 8,
  });

  Map<String, dynamic> toJson() => {
        'goal_type': goalType.name,
        'pace_lbs_per_week': paceLbsPerWeek,
        'start_weight_lbs': startWeightLbs,
        'goal_weight_lbs': goalWeightLbs,
        'height_inches': heightInches,
        'sex': sex,
        'age': age,
        'activity_level': activityLevel.name,
        'diet_styles': dietStyles,
        'food_sensitivities': foodSensitivities,
        'meals_per_day': mealsPerDay,
        'flex_days_per_week': flexDaysPerWeek,
        'track_alcohol': trackAlcohol,
        'medications': medications,
        'medication_reminders': medicationReminders,
        'reminder_frequency': reminderFrequency,
        'reminder_times': reminderTimes,
        'supplements': supplements,
        'motivation': motivation,
        'calorie_goal': calorieGoal,
        'protein_goal': proteinGoal,
        'carb_goal': carbGoal,
        'fat_goal': fatGoal,
        'water_cups_goal': waterCupsGoal,
      };

  factory NutritionProfile.fromJson(Map<String, dynamic> j) => NutritionProfile(
        goalType: NutritionGoalType.values.firstWhere(
            (e) => e.name == j['goal_type'],
            orElse: () => NutritionGoalType.loseFat),
        paceLbsPerWeek: (j['pace_lbs_per_week'] as num?)?.toDouble() ?? 1.0,
        startWeightLbs: (j['start_weight_lbs'] as num).toDouble(),
        goalWeightLbs: (j['goal_weight_lbs'] as num?)?.toDouble() ?? 0,
        heightInches: (j['height_inches'] as num).toDouble(),
        sex: j['sex'] as String? ?? 'other',
        age: j['age'] as int? ?? 25,
        activityLevel: ActivityLevel.values.firstWhere(
            (e) => e.name == j['activity_level'],
            orElse: () => ActivityLevel.moderate),
        dietStyles: List<String>.from(j['diet_styles'] as List? ?? []),
        foodSensitivities:
            List<String>.from(j['food_sensitivities'] as List? ?? []),
        mealsPerDay: j['meals_per_day'] as int? ?? 3,
        flexDaysPerWeek: j['flex_days_per_week'] as int? ?? 0,
        trackAlcohol: j['track_alcohol'] as bool? ?? false,
        medications: j['medications'] != null
            ? List<String>.from(j['medications'] as List)
            : j['glp_med'] != null && j['glp_med'] != 'none'
                ? [j['glp_med'] as String]
                : [],
        medicationReminders: j['medication_reminders'] as bool? ?? false,
        reminderFrequency: j['reminder_frequency'] as String? ?? 'daily',
        reminderTimes: List<String>.from(j['reminder_times'] as List? ?? ['08:00']),
        supplements: List<String>.from(j['supplements'] as List? ?? []),
        motivation: j['motivation'] as String? ?? 'all',
        calorieGoal: j['calorie_goal'] as int? ?? 2000,
        proteinGoal: j['protein_goal'] as int? ?? 150,
        carbGoal: j['carb_goal'] as int? ?? 200,
        fatGoal: j['fat_goal'] as int? ?? 65,
        waterCupsGoal: j['water_cups_goal'] as int? ?? 8,
      );
}

// ── Log models ─────────────────────────────────────────────────────────────

class FoodEntry {
  final String id;
  final String name;
  final String meal; // breakfast / lunch / dinner / snack / dessert / drinks
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  const FoodEntry({
    required this.id,
    required this.name,
    required this.meal,
    required this.calories,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'meal': meal,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };

  factory FoodEntry.fromJson(Map<String, dynamic> j) => FoodEntry(
        id: j['id'] as String,
        name: j['name'] as String,
        meal: j['meal'] as String,
        calories: j['calories'] as int,
        protein: (j['protein'] as num?)?.toDouble() ?? 0,
        carbs: (j['carbs'] as num?)?.toDouble() ?? 0,
        fat: (j['fat'] as num?)?.toDouble() ?? 0,
      );
}

class WeightEntry {
  final String date;
  final double weightLbs;

  const WeightEntry({required this.date, required this.weightLbs});

  Map<String, dynamic> toJson() => {'date': date, 'weight_lbs': weightLbs};

  factory WeightEntry.fromJson(Map<String, dynamic> j) => WeightEntry(
        date: j['date'] as String,
        weightLbs: (j['weight_lbs'] as num).toDouble(),
      );
}

// ── TDEE + macro calculation ───────────────────────────────────────────────

int calculateCalorieGoal({
  required double weightLbs,
  required double heightInches,
  required int age,
  required String sex,
  required ActivityLevel activityLevel,
  required NutritionGoalType goalType,
  required double paceLbsPerWeek,
}) {
  final weightKg = weightLbs * 0.453592;
  final heightCm = heightInches * 2.54;
  // Mifflin-St Jeor BMR
  final bmr = sex == 'male'
      ? (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5
      : (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
  final tdee = bmr * activityLevel.tdeeMultiplier;
  // 1 lb of fat ≈ 3,500 cal
  final dailyAdj = (paceLbsPerWeek * 3500 / 7).round();
  return switch (goalType) {
    NutritionGoalType.loseFat => (tdee - dailyAdj).round().clamp(1200, 99999),
    NutritionGoalType.buildMuscle => (tdee + dailyAdj).round(),
    _ => tdee.round(),
  };
}

({int protein, int carbs, int fat}) calculateMacros({
  required int calories,
  required double weightLbs,
  required NutritionGoalType goalType,
  required List<String> dietStyles,
}) {
  if (dietStyles.contains('keto')) {
    return (
      protein: (calories * 0.25 / 4).round(),
      fat: (calories * 0.70 / 9).round(),
      carbs: (calories * 0.05 / 4).round().clamp(20, 50),
    );
  }
  final int protein;
  if (dietStyles.contains('high_protein') ||
      goalType == NutritionGoalType.buildMuscle) {
    protein = weightLbs.round().clamp(120, 400);
  } else if (goalType == NutritionGoalType.loseFat) {
    protein = (weightLbs * 0.85).round();
  } else {
    protein = (weightLbs * 0.75).round();
  }
  final fat = (calories * 0.28 / 9).round();
  final carbs =
      ((calories - (protein * 4) - (fat * 9)) / 4).round().clamp(50, 9999);
  return (protein: protein, carbs: carbs, fat: fat);
}

// ── Quick-add presets per meal ─────────────────────────────────────────────

class QuickAddPreset {
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  const QuickAddPreset(this.name, this.calories, this.protein, this.carbs, this.fat);
}

const Map<String, List<QuickAddPreset>> quickAddPresets = {
  'breakfast': [
    QuickAddPreset('Eggs (2 scrambled)', 180, 14, 1, 13),
    QuickAddPreset('Greek yogurt (6oz)', 150, 17, 15, 3.5),
    QuickAddPreset('Oatmeal (1 cup)', 150, 5, 27, 3),
    QuickAddPreset('Protein shake', 150, 25, 8, 3),
    QuickAddPreset('Banana', 105, 1.3, 27, 0.4),
  ],
  'lunch': [
    QuickAddPreset('Grilled chicken (4oz)', 185, 35, 0, 4),
    QuickAddPreset('Brown rice (1 cup)', 215, 5, 45, 1.8),
    QuickAddPreset('Mixed salad', 80, 4, 12, 2),
    QuickAddPreset('Turkey sandwich', 350, 24, 38, 9),
  ],
  'dinner': [
    QuickAddPreset('Salmon (6oz)', 310, 44, 0, 14),
    QuickAddPreset('Chicken breast (6oz)', 280, 52, 0, 6),
    QuickAddPreset('Ground beef (4oz)', 290, 28, 0, 19),
    QuickAddPreset('Pasta (2 cups cooked)', 400, 14, 80, 3),
  ],
  'snack': [
    QuickAddPreset('Apple', 95, 0.5, 25, 0.3),
    QuickAddPreset('Almonds (1oz)', 165, 6, 6, 14),
    QuickAddPreset('Protein bar', 200, 20, 22, 6),
    QuickAddPreset('String cheese', 80, 8, 0, 5),
  ],
  'dessert': [
    QuickAddPreset('Low-fat ice cream (½ cup)', 150, 3, 24, 5),
    QuickAddPreset('Dark chocolate (1oz)', 170, 2, 13, 12),
    QuickAddPreset('Fruit salad (1 cup)', 75, 1, 19, 0.4),
  ],
  'drinks': [
    QuickAddPreset('Beer (12oz)', 150, 1, 13, 0),
    QuickAddPreset('Wine (5oz)', 125, 0.1, 4, 0),
    QuickAddPreset('Cocktail / mixed drink', 200, 0, 15, 0),
    QuickAddPreset('Hard seltzer', 100, 0, 2, 0),
  ],
};
