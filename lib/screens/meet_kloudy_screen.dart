import 'package:flutter/material.dart';
import '../models/user_onboarding_data.dart';
import '../theme/kloudy_theme.dart';
import 'create_account_screen.dart';

class MeetKloudyScreen extends StatefulWidget {
  const MeetKloudyScreen({super.key});

  @override
  State<MeetKloudyScreen> createState() => _MeetKloudyScreenState();
}

class _MeetKloudyScreenState extends State<MeetKloudyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  void _getStarted() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateAccountScreen(
          onboardingData: UserOnboardingData(
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
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: kBackground,
      body: Stack(
        children: [
          // ── Subtle warm gradient top wash ─────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            height: size.height * 0.55,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF0E9DF), kBackground],
                ),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top brand mark
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                  child: const Text(
                    'KLOUDY',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.4,
                      color: kInk,
                    ),
                  ),
                ),

                // ── Floating mascot ──────────────────────────────────────────
                Expanded(
                  flex: 10,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: AnimatedBuilder(
                      animation: _floatAnim,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(0, _floatAnim.value),
                        child: child,
                      ),
                      child: Image.asset(
                        'assets/images/kloudy_mascot.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                // ── Headline copy ─────────────────────────────────────────────
                Expanded(
                  flex: 9,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Hey, I\'m Kloudy!',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.2,
                            color: kInk,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Your personal guide to health, money, sleep,\nand the things nobody ever showed us.',
                          style: TextStyle(
                            fontSize: 15,
                            color: kDimText,
                            height: 1.65,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 36),

                        // ── Pillars ──────────────────────────────────────────
                        Row(
                          children: [
                            _Pillar(label: 'Health'),
                            const SizedBox(width: 8),
                            _Pillar(label: 'Wealth'),
                            const SizedBox(width: 8),
                            _Pillar(label: 'Wellness'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── CTA ───────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _getStarted,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kInk,
                            foregroundColor: kCard,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Get Started',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: _getStarted,
                        child: const Text(
                          'Already have an account?  Sign in',
                          style: TextStyle(
                            fontSize: 14,
                            color: kDimText,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pillar chip ───────────────────────────────────────────────────────────────

class _Pillar extends StatelessWidget {
  final String label;
  const _Pillar({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: kInk,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
