import 'dart:async';
import 'package:flutter/material.dart';
import '../demo/demo_profile.dart';
import '../services/supabase_service.dart';
import 'auth_screen.dart';
import 'demo_setup_screen.dart';
import 'main_nav_screen.dart';

/// Routes signed-in users into setup or the app, while keeping a local demo
/// available when users want to explore without creating an account.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<dynamic>? _authSubscription;
  bool _ready = false;
  bool _backendAvailable = false;
  bool _isDemo = false;
  bool _authenticated = false;
  bool _needsSetup = false;
  bool _resolving = false;
  String? _backendError;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _boot() async {
    _backendError = null;
    _backendAvailable = false;
    _ready = false;
    await _authSubscription?.cancel();
    await DemoProfile.load();
    try {
      await SupabaseService.initialize();
      DemoProfile.isDemo = false;
      _backendAvailable = true;
      _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen(
        (event) => _resolveAccount(event.session?.user),
      );
      await _resolveAccount(SupabaseService.client.auth.currentUser);
    } catch (error) {
      _backendError = error.toString();
      debugPrint('[AuthGate] account service initialization failed: $error');
      DemoProfile.isDemo = true;
      if (mounted)
        setState(() {
          _backendAvailable = false;
          _ready = true;
        });
    }
  }

  Future<void> _resolveAccount(user) async {
    if (!mounted) return;
    if (user == null) {
      DemoProfile.isDemo = false;
      setState(() {
        _authenticated = false;
        _needsSetup = false;
        _resolving = false;
        _ready = true;
      });
      return;
    }
    DemoProfile.isDemo = false;
    setState(() => _resolving = true);
    Map<String, dynamic>? profile;
    try {
      profile = await SupabaseService.fetchProfile();
    } catch (_) {
      // A first account has no profile row yet; onboarding will create it.
    }
    if (!mounted) return;
    if (profile != null) {
      DemoProfile.name = (profile['name'] as String?)?.trim().isNotEmpty == true
          ? profile['name'] as String
          : (user.email?.split('@').first ?? 'friend');
      DemoProfile.goals = {
        if (profile['save_money'] == true) 'save_money',
        if (profile['pay_off_debt'] == true) 'pay_off_debt',
        if (profile['spend_more_intentionally'] == true)
          'spend_more_intentionally',
        if (profile['improve_nutrition'] == true) 'improve_nutrition',
        if (profile['stay_on_top_of_healthcare'] == true)
          'stay_on_top_of_healthcare',
        if (profile['build_healthier_habits'] == true) 'build_healthier_habits',
        if (profile['improve_sleep'] == true) 'improve_sleep',
      };
    }
    setState(() {
      _authenticated = true;
      _needsSetup = profile == null;
      _resolving = false;
      _ready = true;
    });
  }

  Future<void> _enterDemo() async {
    DemoProfile.isDemo = true;
    final ready = await DemoProfile.load();
    if (!mounted) return;
    setState(() {
      _isDemo = true;
      _needsSetup = !ready;
      _authenticated = ready;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _resolving) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isDemo) {
      if (_needsSetup)
        return DemoSetupScreen(
          onComplete: () => setState(() {
            _needsSetup = false;
            _authenticated = true;
          }),
        );
      return MainNavScreen(userName: DemoProfile.name);
    }
    if (_authenticated && _needsSetup) {
      return DemoSetupScreen(
        saveToAccount: true,
        onComplete: () => setState(() => _needsSetup = false),
      );
    }
    if (_authenticated) return MainNavScreen(userName: DemoProfile.name);
    return AuthScreen(
      backendAvailable: _backendAvailable,
      backendError: _backendError,
      onRetry: _boot,
      onDemoMode: _enterDemo,
    );
  }
}
