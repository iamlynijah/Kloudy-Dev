class UserOnboardingData {
  String? name;
  int? age;
  String? lifestyle;

  bool loseWeight;
  bool buildMuscle;
  bool improveNutrition;
  bool buildHealthierHabits;

  bool saveMoney;
  bool payOffDebt;
  bool spendMoreIntentionally;
  bool increaseIncome;

  bool improveMentalHealth;
  bool stayOnTopOfHealthcare;
  bool improveSleep;

  Map<String, dynamic> answers;

  UserOnboardingData({
    this.name,
    this.age,
    this.lifestyle,

    required this.loseWeight,
    required this.buildMuscle,
    required this.improveNutrition,
    required this.buildHealthierHabits,

    required this.saveMoney,
    required this.payOffDebt,
    required this.spendMoreIntentionally,
    required this.increaseIncome,

    required this.improveMentalHealth,
    required this.stayOnTopOfHealthcare,
    required this.improveSleep,

    Map<String, dynamic>? answers,
  }) : answers = answers ?? {};
}