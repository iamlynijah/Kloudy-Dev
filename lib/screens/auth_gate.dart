import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../services/supabase_service.dart';
import 'main_nav_screen.dart';
import 'meet_kloudy_screen.dart';

/// Sits at the app root in place of a fixed `home:` screen.
///
/// On launch, and any time auth state changes (sign-in, sign-out, or an
/// email-confirmation deep link resolving), this decides whether to show
/// the onboarding flow (MeetKloudyScreen) or go straight to Home.
///
/// This is also what makes the "tap confirmation link in email" flow work
/// correctly: when that link resolves to a session, onAuthStateChange
/// fires here too, and this widget rebuilds to show Home automatically —
/// no manual navigation needed from the screen that triggered the sign-up.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<supabase.AuthState>(
      stream: SupabaseService.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // While the very first auth check is still resolving, show a
        // simple loading state rather than briefly flashing onboarding.
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _SplashLoading();
        }

        final session = SupabaseService.client.auth.currentSession;

        if (session != null) {
          final user = SupabaseService.currentUser;
          final displayName = (user?.userMetadata?['name'] as String?) ??
              (user?.userMetadata?['full_name'] as String?) ??
              user?.email?.split('@').first ??
              'there';

          return MainNavScreen(userName: displayName);
        }

        return const MeetKloudyScreen();
      },
    );
  }
}

class _SplashLoading extends StatelessWidget {
  const _SplashLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: null,
      body: Center(
        child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}