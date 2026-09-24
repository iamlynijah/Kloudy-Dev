import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
    _floatAnim = Tween<double>(
      begin: -8,
      end: 8,
    ).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
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
    return _buildNewLanding(context);
  }

  Widget _buildNewLanding(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: kKloudyNavy,
      body: Stack(
        children: [
          Positioned(
            top: -size.height * 0.13,
            right: -size.width * 0.28,
            child: Container(
              width: size.width * 0.92,
              height: size.width * 0.92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: kKloudyCyan.withValues(alpha: 0.12),
                  width: 42,
                ),
              ),
            ),
          ),
          Positioned(
            top: size.height * 0.19,
            left: -80,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kKloudyBlue.withValues(alpha: 0.10),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 38,
                        height: 38,
                        child: SvgPicture.asset(
                          'assets/images/kloudy_mark.svg',
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'KLOUDY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: const Text(
                          'A PLACE TO BEGIN',
                          style: TextStyle(
                            color: Color(0xFFC7EAE9),
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _floatAnim,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(0, _floatAnim.value),
                          child: child,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: size.width * 0.62,
                              height: size.width * 0.62,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    kKloudyCyan.withValues(alpha: 0.18),
                                    kKloudyBlue.withValues(alpha: 0.05),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(
                              width: size.width * 0.64,
                              height: size.width * 0.64,
                              child: SvgPicture.asset(
                                'assets/images/kloudy_mark.svg',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    'ADULTING COMES\nWITH A LEARNING CURVE.',
                    style: TextStyle(
                      color: Color(0xFFBFC8FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 11),
                  const Text(
                    'You don’t have to\nfigure it out alone.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      height: 1.08,
                      letterSpacing: -1.3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 13),
                  const Text(
                    'Money, health, appointments, routines. Kloudy makes the things nobody explained feel easier to understand and manage.',
                    style: TextStyle(
                      color: Color(0xFFD1D4E7),
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 19),
                  Wrap(
                    spacing: 8,
                    children: const [
                      _LandingPill(
                        icon: Icons.payments_outlined,
                        label: 'Money',
                      ),
                      _LandingPill(
                        icon: Icons.favorite_border_rounded,
                        label: 'Health',
                      ),
                      _LandingPill(
                        icon: Icons.calendar_month_outlined,
                        label: 'Everyday life',
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 55,
                    child: FilledButton(
                      onPressed: _getStarted,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7D88FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Find your starting point',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 9),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  TextButton(
                    onPressed: _getStarted,
                    child: const Text(
                      'Already have an account?  Sign in',
                      style: TextStyle(color: Color(0xFFD1D4E7), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _LandingPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: kKloudyCyan, size: 14),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
