import 'building_plan_screen.dart';
import 'package:flutter/material.dart';
import '../models/user_onboarding_data.dart';
import '../models/goal_question.dart';

class GoalSpecificQuestionsScreen extends StatefulWidget {
  final UserOnboardingData onboardingData;

  const GoalSpecificQuestionsScreen({
    super.key,
    required this.onboardingData,
  });

  @override
  State<GoalSpecificQuestionsScreen> createState() =>
      _GoalSpecificQuestionsScreenState();
}

class _GoalSpecificQuestionsScreenState
    extends State<GoalSpecificQuestionsScreen> {

  late List<GoalQuestion> questions;

  int currentQuestionIndex = 0;

  String? selectedAnswer;

  Set<String> selectedAnswers = {};

  double weightSliderValue = 200;
  double sleepSliderValue = 7;
  double moneySliderValue = 0;
  double percentSliderValue = 0;

  @override
  void initState() {
    super.initState();
    questions = buildQuestions();
    _resetSliderForCurrentQuestion();
  }

  // Money/percent sliders are reused across several different questions
  // (savings goal, income, debt amount, APR, etc.), each with its own
  // range and sensible starting point — so unlike the single shared
  // weight/sleep sliders, these need to snap to that question's
  // `initialValue` whenever the current question changes, rather than
  // staying wherever the previous money question left them.
  void _resetSliderForCurrentQuestion() {
    final question = questions[currentQuestionIndex];
    if (question.type == QuestionType.moneySlider) {
      moneySliderValue =
          question.initialValue ?? question.minValue ?? 0;
    } else if (question.type == QuestionType.percentSlider) {
      percentSliderValue =
          question.initialValue ?? question.minValue ?? 0;
    }
  }
  List<GoalQuestion> buildQuestions() {
    List<GoalQuestion> q = [];

    // =====================
    // HEALTH
    // =====================

    if (widget.onboardingData.loseWeight ||
        widget.onboardingData.buildMuscle ||
        widget.onboardingData.improveNutrition ||
        widget.onboardingData.buildHealthierHabits) {

      q.add(
        GoalQuestion(
          id: 'current_weight',
          section: 'Health & Wellness',
          question:
              'What is your current weight?',
          type: QuestionType.weightSlider,
        ),
      );

      q.add(
        GoalQuestion(
          id: 'goal_weight',
          section: 'Health & Wellness',
          question:
              'What is your goal weight?',
          type: QuestionType.weightSlider,
        ),
      );

      q.add(
        GoalQuestion(
          id: 'health_obstacles',
          section: 'Health & Wellness',
          question:
            'What stops you from meeting your fitness goals most often?',
          type: QuestionType.multiChoice,
          options: [
            'Consistency',
            'Stress',
            'Lack of Time',
            'Motivation',
            'Nutrition',
            'Sleep',
          ],
        ),
      );

      q.add(
        GoalQuestion(
        id: 'calorie_tracking',
        section: 'Health & Wellness',
        question:
            'How often do you currently track your calories?',
        type: QuestionType.singleChoice,
        options: [
          '7 Days Per Week',
          '5–6 Days Per Week',
          '1–4 Days Per Week',
          'A Few Times Per Month',
          'Rarely',
          'Never',
          ],
        ),
      );

      
    }    if (widget.onboardingData.saveMoney ||
        widget.onboardingData.payOffDebt ||
        widget.onboardingData.spendMoreIntentionally ||
        widget.onboardingData.increaseIncome) {

      q.add(
        GoalQuestion(
          id: 'financial_goals',
          section: 'Financial Growth',
          question:
              'What financial goals matter most right now?',
          type: QuestionType.multiChoice,
          options: [
            'Build Savings',
            'Pay Off Debt',
            'Emergency Fund',
            'Increase Income',
            'Reduce Spending',
          ],
        ),
      );

      if (widget.onboardingData.saveMoney) {
        q.add(
          GoalQuestion(
            id: 'savings_goal',
            section: 'Financial Growth',
            question:
                'How much would you like to have in savings?',
            type: QuestionType.moneySlider,
            minValue: 0,
            maxValue: 50000,
            divisions: 100,
            initialValue: 5000,
          ),
        );
      }

      if (widget.onboardingData.increaseIncome) {
        q.add(
          GoalQuestion(
            id: 'monthly_income',
            section: 'Financial Growth',
            question:
                'What is your current monthly income?',
            type: QuestionType.moneySlider,
            minValue: 0,
            maxValue: 20000,
            divisions: 100,
            initialValue: 3000,
          ),
        );
      }

          if (widget.onboardingData.payOffDebt) {
            q.add(
              GoalQuestion(
                id: 'debt_types',
                section: 'Financial Growth',
                question:
                    'What types of debt are you currently working to pay off?',
                type: QuestionType.multiChoice,
                options: [
                  'Credit Card',
                  'Student Loans',
                  'Car Loan',
                  'Personal Loan',
                  'Medical Debt',
                  'Mortgage',
                  'Other',
                ],
              ),
            );

            q.add(
              GoalQuestion(
                id: 'debt_amount',
                section: 'Financial Growth',
                question:
                    'Roughly how much total debt are you working to pay off?',
                type: QuestionType.moneySlider,
                minValue: 0,
                maxValue: 100000,
                divisions: 100,
                initialValue: 10000,
              ),
            );

            q.add(
              GoalQuestion(
                id: 'debt_apr',
                section: 'Financial Growth',
                question:
                    "What's the average APR across your debt?",
                type: QuestionType.percentSlider,
                minValue: 0,
                maxValue: 35,
                divisions: 70,
                initialValue: 18,
              ),
            );
          }

      if (widget.onboardingData.spendMoreIntentionally) {
        q.add(
          GoalQuestion(
            id: 'spending_budget',
            section: 'Financial Growth',
            question:
                "What's your ideal monthly spending budget?",
            type: QuestionType.moneySlider,
            minValue: 0,
            maxValue: 10000,
            divisions: 100,
            initialValue: 2000,
          ),
        );
      }

      q.add(
        GoalQuestion(
          id: 'spending_categories',
          section: 'Financial Growth',
          question:
              'Which spending categories are hardest to control?',
          type: QuestionType.multiChoice,
          options: [
            'Dining Out',
            'Shopping',
            'Entertainment',
            'Subscriptions',
            'Travel',
            'Impulse Purchases',
          ],
        ),
      );



    }

    if (widget.onboardingData.improveMentalHealth) {

      q.add(
        GoalQuestion(
          id: 'mental_challenges',
          section: 'Mental Wellbeing',
          question:
      'What has been the biggest challenge on your mental health journey?',
          type: QuestionType.multiChoice,
          options: [
            'Stress',
            'Anxiety',
            'Burnout',
            'Confidence',
            'Motivation',
            'Work-Life Balance',
          ],
        ),
      );

      q.add(
        GoalQuestion(
          id: 'mental_first_to_suffer',
          section: 'Mental Wellbeing',
          question:
              'When life gets busy, what usually suffers first?',
          type: QuestionType.multiChoice,
          options: [
            'Sleep',
            'Exercise',
            'Healthy Eating',
            'Budgeting',
            'Self-Care',
          ],
        ),
      );
    }    if (widget.onboardingData.improveSleep) {

  q.add(
    GoalQuestion(
      id: 'sleep_hours',
      section: 'Sleep',
      question:
          'How many hours of sleep do you usually get each night?',
      type: QuestionType.sleepSlider,
    ),
  );

  q.add(
    GoalQuestion(
      id: 'sleep_feeling',
      section: 'Sleep',
      question:
          'How do you usually feel when you wake up?',
      type: QuestionType.singleChoice,
      options: [
        'Refreshed',
        'Pretty Good',
        'Usually Tired',
        'Exhausted',
      ],
    ),
  );
}

    if (widget.onboardingData.stayOnTopOfHealthcare) {

  
      q.add(
    GoalQuestion(
      id: 'missed_appointments',
      section: 'Healthcare',
      question:
          'What appointments do you most often postpone or miss?',
      type: QuestionType.multiChoice,
      options: [
        'Physicals',
        'OBGYN',
        'Dental',
        'Therapy',
        'Specialists',
        'Other',
      ],
    ),
  );
        q.add(
      GoalQuestion(
        id: 'last_physical',
        section: 'Healthcare',
        question:
            'When was your last primary care appointment or physical?',
        type: QuestionType.singleChoice,
        options: [
          'Within 6 Months',
          '6–12 Months Ago',
          '1–2 Years Ago',
          'More Than 2 Years Ago',
          'I Do Not Remember',
        ],
      ),
    );
    q.add(
  GoalQuestion(
    id: 'therapy_relationship',
    section: 'Healthcare',
    question:
        'What best describes your relationship with therapy?',
    type: QuestionType.singleChoice,
    options: [
      'I Love Therapy',
      'I Actively Attend Therapy',
      'I Attend Occasionally',
      'I Am Interested In Starting',
      'I Have Tried It Before',
      'I Am Unsure About It',
      'I Am Not Open To Therapy',
    ],
  ),
);
      
    }


    return q;
  }  void continueToNextQuestion() {
    final question =
        questions[currentQuestionIndex];

    // =========================
    // SINGLE CHOICE
    // =========================

    if (question.type ==
        QuestionType.singleChoice) {

      if (selectedAnswer == null) {
        return;
      }

      widget.onboardingData.answers[
          question.id] = selectedAnswer;
    }

    // =========================
    // MULTI CHOICE
    // =========================

    if (question.type ==
        QuestionType.multiChoice) {

      if (selectedAnswers.isEmpty) {
        return;
      }

      widget.onboardingData.answers[
          question.id] =
          selectedAnswers.toList();
    }

    // =========================
    // WEIGHT SLIDER
    // =========================

    if (question.type ==
        QuestionType.weightSlider) {

      widget.onboardingData.answers[
          question.id] =
          weightSliderValue.round();
    }

    // =========================
    // SLEEP SLIDER
    // =========================

    if (question.type ==
        QuestionType.sleepSlider) {

      widget.onboardingData.answers[
          question.id] =
          sleepSliderValue.round();
    }

    // =========================
    // MONEY SLIDER
    // =========================

    if (question.type ==
        QuestionType.moneySlider) {

      widget.onboardingData.answers[
          question.id] =
          moneySliderValue.round();
    }

    // =========================
    // PERCENT SLIDER
    // =========================

    if (question.type ==
        QuestionType.percentSlider) {

      widget.onboardingData.answers[
          question.id] =
          percentSliderValue;
    }

    // =========================
    // NEXT QUESTION
    // =========================

    if (currentQuestionIndex <
        questions.length - 1) {

      setState(() {
        currentQuestionIndex++;

        selectedAnswer = null;

        selectedAnswers.clear();

        _resetSliderForCurrentQuestion();
      });

      return;
    }

    // =========================
    // FINISHED
    // =========================

  Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (_) => BuildingPlanScreen(
      onboardingData:
          widget.onboardingData,
    ),
  ),
);
  }
  Widget buildSingleChoiceCard(
    String option,
  ) {
    final isSelected =
        selectedAnswer == option;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedAnswer = option;
        });
      },
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 200),
        margin:
            const EdgeInsets.only(
          bottom: 14,
        ),
        padding:
            const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.black
              : Colors.white,
          borderRadius:
              BorderRadius.circular(
            24,
          ),
          border: Border.all(
            color: isSelected
                ? Colors.black
                : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : Colors.black,
                ),
              ),
            ),

            if (isSelected)
              const Icon(
                Icons.check,
                color: Colors.white,
              ),
          ],
        ),
      ),
    );
  }

  Widget buildMultiChoiceCard(
    String option,
  ) {
    final isSelected =
        selectedAnswers.contains(
      option,
    );

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            selectedAnswers.remove(
              option,
            );
          } else {
            selectedAnswers.add(
              option,
            );
          }
        });
      },
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 200),
        margin:
            const EdgeInsets.only(
          bottom: 14,
        ),
        padding:
            const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.black
              : Colors.white,
          borderRadius:
              BorderRadius.circular(
            24,
          ),
          border: Border.all(
            color: isSelected
                ? Colors.black
                : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : Colors.black,
                ),
              ),
            ),

            if (isSelected)
              const Icon(
                Icons.check,
                color: Colors.white,
              ),
          ],
        ),
      ),
    );
  }

  Widget buildWeightSlider() {
    return Column(
      children: [

        Text(
          '${weightSliderValue.round()} lbs',
          style: const TextStyle(
            fontSize: 60,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(height: 20),

        Slider(
          value: weightSliderValue,
          min: 80,
          max: 600,
          divisions: 520,
          activeColor: Colors.black,
          onChanged: (value) {
            setState(() {
              weightSliderValue = value;
            });
          },
        ),

        const Padding(
          padding:
              EdgeInsets.symmetric(
            horizontal: 8,
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
            children: [
              Text('80 lbs'),
              Text('600+ lbs'),
            ],
          ),
        ),

        const SizedBox(height: 30),

        if (questions[currentQuestionIndex]
                .id ==
            'goal_weight')
          Builder(
            builder: (_) {

              final currentWeight =
                  widget.onboardingData
                          .answers[
                      'current_weight'] as int?;

              if (currentWeight ==
                  null) {
                return const SizedBox();
              }

              final difference =
                  currentWeight -
                      weightSliderValue.round();

              return Column(
                children: [

                  Text(
                    '${difference.abs()} lbs',
                    style:
                        const TextStyle(
                      fontSize: 32,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    difference > 0
                        ? 'to lose'
                        : 'to gain',
                    style:
                        TextStyle(
                      fontSize: 18,
                      color:
                          Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
  Widget buildSleepSlider() {
    return Column(
      children: [

        Text(
          '${sleepSliderValue.round()} hrs',
          style: const TextStyle(
            fontSize: 60,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(height: 20),

        Slider(
          value: sleepSliderValue,
          min: 0,
          max: 12,
          divisions: 24,
          activeColor: Colors.black,
          onChanged: (value) {
            setState(() {
              sleepSliderValue = value;
            });
          },
        ),

        const Padding(
          padding:
              EdgeInsets.symmetric(
            horizontal: 8,
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
            children: [
              Text('0 hrs'),
              Text('12+ hrs'),
            ],
          ),
        ),
      ],
    );
  }

  // Formats e.g. 12500 -> "12,500" so large dollar amounts (debt,
  // income) are readable at a glance.
  String _formatMoney(num value) {
    final wholeNumber = value.round().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < wholeNumber.length; i++) {
      final remaining = wholeNumber.length - i;
      if (i > 0 && remaining % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(wholeNumber[i]);
    }
    return buffer.toString();
  }

  Widget buildMoneySlider() {
    final question = questions[currentQuestionIndex];
    final min = question.minValue ?? 0;
    final max = question.maxValue ?? 10000;
    final divisions = question.divisions ?? 100;

    return Column(
      children: [

        Text(
          '\$${_formatMoney(moneySliderValue)}',
          style: const TextStyle(
            fontSize: 52,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(height: 20),

        Slider(
          value: moneySliderValue.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          activeColor: Colors.black,
          onChanged: (value) {
            setState(() {
              moneySliderValue = value;
            });
          },
        ),

        Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 8,
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
            children: [
              Text('\$${_formatMoney(min)}'),
              Text('\$${_formatMoney(max)}+'),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildPercentSlider() {
    final question = questions[currentQuestionIndex];
    final min = question.minValue ?? 0;
    final max = question.maxValue ?? 100;
    final divisions = question.divisions ?? 100;

    return Column(
      children: [

        Text(
          '${percentSliderValue.toStringAsFixed(1)}%',
          style: const TextStyle(
            fontSize: 52,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(height: 20),

        Slider(
          value: percentSliderValue.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          activeColor: Colors.black,
          onChanged: (value) {
            setState(() {
              percentSliderValue = value;
            });
          },
        ),

        Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 8,
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
            children: [
              Text('${min.toStringAsFixed(0)}%'),
              Text('${max.toStringAsFixed(0)}%'),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildQuestionContent(
    GoalQuestion question,
  ) {

    if (question.type ==
        QuestionType.weightSlider) {
      return buildWeightSlider();
    }
    if (question.type ==
    QuestionType.sleepSlider) {
      return buildSleepSlider();
    }
    if (question.type ==
        QuestionType.moneySlider) {
      return buildMoneySlider();
    }
    if (question.type ==
        QuestionType.percentSlider) {
      return buildPercentSlider();
    }

    if (question.type ==
        QuestionType.singleChoice) {
      return Column(
        children:
            question.options!
                .map(
                  (option) =>
                      buildSingleChoiceCard(
                    option,
                  ),
                )
                .toList(),
      );
    }

    if (question.type ==
        QuestionType.multiChoice) {
      return Column(
        children:
            question.options!
                .map(
                  (option) =>
                      buildMultiChoiceCard(
                    option,
                  ),
                )
                .toList(),
      );
    }

    return const SizedBox();
  }  String _sectionDescription(
    String section,
  ) {
    switch (section) {

      case 'Health & Wellness':
        return 'Let’s understand your current habits, challenges, and how Kloudy can help improve your health.';

      case 'Financial Growth':
        return 'Help Kloudy understand your financial goals so we can build a smarter financial plan together.';

      case 'Mental Wellbeing':
        return 'Tell us about the challenges you face so Kloudy can support you more effectively.';

      case 'Sleep':
        return 'Sleep affects everything. Let’s understand what gets in the way of quality rest.';

      case 'Healthcare':
        return 'Kloudy can help you stay on top of appointments, medications, and wellness routines.';

      case 'Your Coaching Style':
        return 'Everyone responds differently to feedback. Let’s personalize how Kloudy supports you.';

      default:
        return '';
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final question =
        questions[currentQuestionIndex];

    final progress =
        (currentQuestionIndex + 1) /
            questions.length;

    final bool showSectionHeader =
        currentQuestionIndex == 0 ||
        questions[
                    currentQuestionIndex -
                        1]
                .section !=
            question.section;

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

              Text(
                'Question ${currentQuestionIndex + 1} of ${questions.length}',
                style:
                    TextStyle(
                  fontSize: 16,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              ClipRRect(
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
                child:
                    LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor:
                      Colors.grey
                          .shade300,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              if (showSectionHeader)
                Container(
                  width:
                      double.infinity,
                  margin:
                      const EdgeInsets
                          .only(
                    bottom: 24,
                  ),
                  padding:
                      const EdgeInsets
                          .all(20),
                  decoration:
                      BoxDecoration(color: Theme.of(context).cardColor,
                    borderRadius:
                        BorderRadius
                            .circular(
                                24),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [

                      Text(
                        question.section,
                        style:
                            const TextStyle(
                          fontSize: 28,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      Text(
                        _sectionDescription(
                          question
                              .section,
                        ),
                        style:
                            const TextStyle(
                          fontSize: 18,
                          height: 1.4,
                          color:
                              Colors
                                  .black54,
                        ),
                      ),
                    ],
                  ),
                ),

              Text(
                question.question,
                style:
                    const TextStyle(
                  fontSize: 32,
                  fontWeight:
                      FontWeight.bold,
                  height: 1.2,
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              Expanded(
                child:
                    SingleChildScrollView(
                  child:
                      buildQuestionContent(
                    question,
                  ),
                ),
              ),

              SizedBox(
                width:
                    double.infinity,
                height: 68,
                child:
                    ElevatedButton(
                  onPressed:
                      continueToNextQuestion,
                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                                  34),
                    ),
                  ),
                  child: Text(
                    currentQuestionIndex ==
                            questions
                                    .length -
                                1
                        ? 'Finish'
                        : 'Continue',
                    style:
                        const TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight
                              .w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }
}