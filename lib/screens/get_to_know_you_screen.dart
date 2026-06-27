import 'package:flutter/material.dart';
import '../models/user_onboarding_data.dart';
import 'goals_screen.dart';

class GetToKnowYouScreen extends StatefulWidget {
  const GetToKnowYouScreen({
    super.key,
  });

  @override
  State<GetToKnowYouScreen> createState() =>
      _GetToKnowYouScreenState();
}

class _GetToKnowYouScreenState
    extends State<GetToKnowYouScreen> {
  final TextEditingController nameController =
      TextEditingController();

  final TextEditingController ageController =
      TextEditingController();

  String? lifestyle;

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    super.dispose();
  }

  void continueToNextScreen() {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please enter your name.",
          ),
        ),
      );
      return;
    }

    if (ageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please enter your age.",
          ),
        ),
      );
      return;
    }

    if (lifestyle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please select your current situation.",
          ),
        ),
      );
      return;
    }

    final onboardingData = UserOnboardingData(
      name: nameController.text.trim(),
      age: int.tryParse(
        ageController.text.trim(),
      ),
      lifestyle: lifestyle,

      loseWeight: false,
      buildMuscle: false,
      improveNutrition: false,
      buildHealthierHabits: false,

      saveMoney: false,
      payOffDebt: false,
      spendMoreIntentionally: false,
      increaseIncome: false,

      improveMentalHealth: false,
      stayOnTopOfHealthcare: false,
      improveSleep: false,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GoalsScreen(
          onboardingData: onboardingData,
        ),
      ),
    );
  }

  Widget buildLifestyleOption(
    String value,
  ) {
    return RadioListTile<String>(
      title: Text(value),
      value: value,
      groupValue: lifestyle,
      onChanged: (selected) {
        setState(() {
          lifestyle = selected;
        });
      },
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
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                "Let's get to know you",
                style: TextStyle(
                  fontSize: 34,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                "We'll personalize Kloudy based on your goals and lifestyle.",
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
                ),
              ),

              const SizedBox(height: 30),

              TextField(
                controller:
                    nameController,
                decoration:
                    const InputDecoration(
                  labelText:
                      "What should Kloudy call you?",
                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                controller:
                    ageController,
                keyboardType:
                    TextInputType.number,
                decoration:
                    const InputDecoration(
                  labelText: "Age",
                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                "What best describes your current situation?",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: ListView(
                  children: [
                    buildLifestyleOption(
                      "Student",
                    ),
                    buildLifestyleOption(
                      "Working Professional",
                    ),
                    buildLifestyleOption(
                      "Student + Working",
                    ),
                    buildLifestyleOption(
                      "Self-Employed / Business Owner",
                    ),
                    buildLifestyleOption(
                      "Between Jobs",
                    ),
                    buildLifestyleOption(
                      "Retired",
                    ),
                    buildLifestyleOption(
                      "Other",
                    ),
                  ],
                ),
              ),

              SizedBox(
                width:
                    double.infinity,
                height: 68,
                child: ElevatedButton(
                  onPressed:
                      continueToNextScreen,
                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        34,
                      ),
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

              const SizedBox(
                height: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}