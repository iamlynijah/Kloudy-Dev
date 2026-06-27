import 'package:flutter/material.dart';

import '../models/user_onboarding_data.dart';
import 'personalized_plan_intro_screen.dart';

class GoalsScreen extends StatefulWidget {
  final UserOnboardingData onboardingData;

  const GoalsScreen({
    super.key,
    required this.onboardingData,
  });

  @override
  State<GoalsScreen> createState() =>
      _GoalsScreenState();
}

class _GoalsScreenState
    extends State<GoalsScreen> {

  late bool loseWeight;
  late bool buildMuscle;
  late bool improveNutrition;
  late bool buildHealthierHabits;

  late bool saveMoney;
  late bool payOffDebt;
  late bool spendMoreIntentionally;
  late bool increaseIncome;

  late bool improveMentalHealth;
  bool improveFocus = false;
  bool reduceStress = false;

  late bool stayOnTopOfHealthcare;
  late bool improveSleep;

  @override
  void initState() {
    super.initState();

    loseWeight =
        widget.onboardingData.loseWeight;

    buildMuscle =
        widget.onboardingData.buildMuscle;

    improveNutrition =
        widget.onboardingData.improveNutrition;

    buildHealthierHabits =
        widget.onboardingData
            .buildHealthierHabits;

    saveMoney =
        widget.onboardingData.saveMoney;

    payOffDebt =
        widget.onboardingData.payOffDebt;

    spendMoreIntentionally =
        widget.onboardingData
            .spendMoreIntentionally;

    increaseIncome =
        widget.onboardingData.increaseIncome;

    improveMentalHealth =
        widget.onboardingData
            .improveMentalHealth;

    stayOnTopOfHealthcare =
        widget.onboardingData
            .stayOnTopOfHealthcare;

    improveSleep =
        widget.onboardingData.improveSleep;
  }

  int get selectedGoalCount =>
      [
        loseWeight,
        buildMuscle,
        improveNutrition,
        buildHealthierHabits,
        saveMoney,
        payOffDebt,
        spendMoreIntentionally,
        increaseIncome,
        improveMentalHealth,
        improveFocus,
        reduceStress,
        stayOnTopOfHealthcare,
        improveSleep,
      ].where((e) => e).length;

  void continueToNextScreen() {
    if (selectedGoalCount == 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please select at least one goal.',
          ),
        ),
      );
      return;
    }

    widget.onboardingData.loseWeight =
        loseWeight;

    widget.onboardingData.buildMuscle =
        buildMuscle;

    widget.onboardingData.improveNutrition =
        improveNutrition;

    widget.onboardingData
            .buildHealthierHabits =
        buildHealthierHabits;

    widget.onboardingData.saveMoney =
        saveMoney;

    widget.onboardingData.payOffDebt =
        payOffDebt;

    widget.onboardingData
            .spendMoreIntentionally =
        spendMoreIntentionally;

    widget.onboardingData.increaseIncome =
        increaseIncome;

    widget.onboardingData
            .improveMentalHealth =
        improveMentalHealth;

    widget.onboardingData
            .stayOnTopOfHealthcare =
        stayOnTopOfHealthcare;

    widget.onboardingData.improveSleep =
        improveSleep;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PersonalizedPlanIntroScreen(
          onboardingData:
              widget.onboardingData,
        ),
      ),
    );
  }

  Widget goalTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool?) onChanged,
  }) {
    return CheckboxListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
      ),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF8F5F2),

      appBar: AppBar(
        backgroundColor:
            const Color(0xFFF8F5F2),
        elevation: 0,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [

              Text(
                "What are your goals, ${widget.onboardingData.name}?",
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                "$selectedGoalCount selected",
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                "Health & Wellness",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              goalTile(
                title: "Lose Weight",
                subtitle:
                    "Reduce body fat and improve health",
                value: loseWeight,
                onChanged: (v) =>
                    setState(() =>
                        loseWeight = v!),
              ),

              goalTile(
                title:
                    "Build Muscle & Fitness",
                subtitle:
                    "Become stronger and more active",
                value: buildMuscle,
                onChanged: (v) =>
                    setState(() =>
                        buildMuscle = v!),
              ),

              goalTile(
                title:
                    "Improve Nutrition",
                subtitle:
                    "Make healthier food choices",
                value: improveNutrition,
                onChanged: (v) =>
                    setState(() =>
                        improveNutrition =
                            v!),
              ),

              goalTile(
                title:
                    "Build Healthier Habits",
                subtitle:
                    "Create routines that stick",
                value:
                    buildHealthierHabits,
                onChanged: (v) =>
                    setState(() =>
                        buildHealthierHabits =
                            v!),
              ),

              const SizedBox(height: 24),

              const Text(
                "Financial Growth",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              goalTile(
                title: "Save Money",
                subtitle:
                    "Build savings and financial security",
                value: saveMoney,
                onChanged: (v) =>
                    setState(() =>
                        saveMoney = v!),
              ),

              goalTile(
                title: "Pay Off Debt",
                subtitle:
                    "Eliminate debt faster",
                value: payOffDebt,
                onChanged: (v) =>
                    setState(() =>
                        payOffDebt = v!),
              ),

              goalTile(
                title:
                    "Spend More Intentionally",
                subtitle:
                    "Control spending and reduce waste",
                value:
                    spendMoreIntentionally,
                onChanged: (v) =>
                    setState(() =>
                        spendMoreIntentionally =
                            v!),
              ),

              goalTile(
                title:
                    "Increase Income",
                subtitle:
                    "Earn more through work or side income",
                value: increaseIncome,
                onChanged: (v) =>
                    setState(() =>
                        increaseIncome =
                            v!),
              ),

              const SizedBox(height: 24),

              const Text(
                "Mental Wellbeing",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              goalTile(
                title:
                    "Improve Mental Health",
                subtitle:
                    "Feel happier and emotionally healthier",
                value:
                    improveMentalHealth,
                onChanged: (v) =>
                    setState(() =>
                        improveMentalHealth =
                            v!),
              ),

              goalTile(
                title:
                    "Improve Focus & Productivity",
                subtitle:
                    "Get more done with less stress",
                value: improveFocus,
                onChanged: (v) =>
                    setState(() =>
                        improveFocus = v!),
              ),

              goalTile(
                title:
                    "Reduce Stress & Burnout",
                subtitle:
                    "Manage overwhelm and recharge",
                value: reduceStress,
                onChanged: (v) =>
                    setState(() =>
                        reduceStress = v!),
              ),

              const SizedBox(height: 24),

              const Text(
                "Healthcare",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              goalTile(
                title:
                    "Stay On Top of Healthcare",
                subtitle:
                    "Keep up with appointments and wellness",
                value:
                    stayOnTopOfHealthcare,
                onChanged: (v) =>
                    setState(() =>
                        stayOnTopOfHealthcare =
                            v!),
              ),

              goalTile(
                title:
                    "Improve Sleep",
                subtitle:
                    "Get better quality rest",
                value: improveSleep,
                onChanged: (v) =>
                    setState(() =>
                        improveSleep = v!),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 68,
                child: ElevatedButton(
                  onPressed:
                      continueToNextScreen,
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                              34),
                    ),
                  ),
                  child: const Text(
                    "Continue",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}