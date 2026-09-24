import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_onboarding_data.dart';
import 'create_account_screen.dart';
import '../widgets/kloudy_mark.dart';

class BuildingPlanScreen extends StatefulWidget {
  final UserOnboardingData onboardingData;

  const BuildingPlanScreen({super.key, required this.onboardingData});

  @override
  State<BuildingPlanScreen> createState() => _BuildingPlanScreenState();
}

class _BuildingPlanScreenState extends State<BuildingPlanScreen>
    with SingleTickerProviderStateMixin {
  int currentStep = 0;

  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  final List<String> steps = [
    'Understanding your goals',
    'Analyzing your habits',
    'Building your health strategy',
    'Creating your financial strategy',
    'Preparing daily coaching',
    'Finalizing your plan',
  ];

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    startAnimation();
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  Future<void> startAnimation() async {
    for (int i = 0; i < steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      setState(() {
        currentStep = i + 1;
      });
    }

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CreateAccountScreen(onboardingData: widget.onboardingData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: null, // inherits from theme
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // Floating mascot
              AnimatedBuilder(
                animation: _floatAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _floatAnimation.value),
                    child: child,
                  );
                },
                child: const KloudyMark(size: 140),
              ),

              const SizedBox(height: 28),

              const Text(
                'Building your personalized plan...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                'Kloudy is learning about your goals and building a plan designed specifically for you.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.54),
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 36),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: List.generate(steps.length, (index) {
                    final completed = index < currentStep;
                    final isActive = index == currentStep;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Row(
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: completed
                                ? Icon(
                                    Icons.check_circle,
                                    key: ValueKey('done'),
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    size: 24,
                                  )
                                : isActive
                                ? SizedBox(
                                    key: ValueKey('loading'),
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                  )
                                : Container(
                                    key: const ValueKey('pending'),
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.black26,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                          ),

                          const SizedBox(width: 14),

                          Expanded(
                            child: Text(
                              steps[index],
                              style: TextStyle(
                                fontSize: 17,
                                color: completed || isActive
                                    ? Colors.black
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.38),
                                fontWeight: completed
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
