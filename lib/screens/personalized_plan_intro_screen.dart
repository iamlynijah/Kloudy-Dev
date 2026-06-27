import 'package:flutter/material.dart';
import '../models/user_onboarding_data.dart';
import 'goal_specific_questions_screen.dart';

class PersonalizedPlanIntroScreen extends StatelessWidget {
  final UserOnboardingData onboardingData;

  const PersonalizedPlanIntroScreen({
    super.key,
    required this.onboardingData,
  });

  List<String> getFocusAreas() {
    List<String> areas = [];

    final hasHealthGoals =
        onboardingData.loseWeight ||
        onboardingData.buildMuscle ||
        onboardingData.improveNutrition ||
        onboardingData.buildHealthierHabits ||
        onboardingData.improveSleep ||
        onboardingData.stayOnTopOfHealthcare;

    final hasFinancialGoals =
        onboardingData.saveMoney ||
        onboardingData.payOffDebt ||
        onboardingData.spendMoreIntentionally ||
        onboardingData.increaseIncome;

    final hasMentalHealthGoals =
        onboardingData.improveMentalHealth;

    if (hasHealthGoals) {
      areas.add("Health & Wellness");
    }

    if (hasFinancialGoals) {
      areas.add("Financial Growth");
    }

    if (hasMentalHealthGoals) {
      areas.add("Mental Wellbeing");
    }

    return areas;
  }

  @override
  Widget build(BuildContext context) {
    final areas = getFocusAreas();

    return Scaffold(
      backgroundColor: null, // inherits from theme
      appBar: AppBar(
        backgroundColor: null, // inherits from theme
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Spacer(),

              Text(
                "Perfect, ${onboardingData.name}.",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                "You're looking to improve:",
                style: TextStyle(
                  fontSize: 22,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.87),
                ),
              ),

              const SizedBox(height: 28),

              ...areas.map(
                (area) => Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 18,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          area,
                          style:
                              const TextStyle(
                            fontSize: 22,
                            fontWeight:
                                FontWeight
                                    .w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "I'll create a personalized plan based on your goals and current situation.",
                style: TextStyle(
                  fontSize: 20,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                "This will only take a minute.",
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 68,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            GoalSpecificQuestionsScreen(
                          onboardingData:
                              onboardingData,
                        ),
                      ),
                    );
                  },
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(34),
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

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}