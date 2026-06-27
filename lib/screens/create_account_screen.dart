import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../models/user_onboarding_data.dart';
import '../services/supabase_service.dart';

// ── Brand SVG logos ──

const String _kGoogleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <path fill="#EA4335" d="M24 9.5c3.1 0 5.9 1.1 8.1 2.9l6-6C34.5 3.1 29.6 1 24 1 14.8 1 7 6.7 3.7 14.6l7 5.4C12.4 13.9 17.7 9.5 24 9.5z"/>
  <path fill="#4285F4" d="M46.5 24.5c0-1.6-.1-3.1-.4-4.5H24v8.5h12.7c-.6 3-2.3 5.5-4.8 7.2l7.4 5.7c4.3-4 6.8-9.9 6.8-16.9z"/>
  <path fill="#FBBC05" d="M10.7 28.6A14.5 14.5 0 0 1 9.5 24c0-1.6.3-3.2.7-4.6l-7-5.4A23.5 23.5 0 0 0 .5 24c0 3.8.9 7.3 2.5 10.5l7.7-5.9z"/>
  <path fill="#34A853" d="M24 47c6.5 0 11.9-2.1 15.9-5.8l-7.4-5.7c-2.2 1.5-5 2.4-8.5 2.4-6.3 0-11.6-4.2-13.5-10l-7.7 5.9C6.9 41.2 14.8 47 24 47z"/>
</svg>
''';

// ── Google OAuth iOS client ID ──
// From Google Cloud Console -> APIs & Services -> Credentials -> iOS OAuth client.
// This is required on iOS; without it, GoogleSignIn().signIn() can fail silently
// at the native layer before any Dart exception is thrown.
const String _kGoogleIosClientId =
    '229419201107-ric5vi4g9s0o4l31sbutfstp42q10alk.apps.googleusercontent.com';

// ── Google OAuth Web client ID ──
// A separate "Web application" type OAuth client, used as the audience
// for the ID token. Supabase validates against this when we call
// signInWithIdToken, so it must be passed as serverClientId below.
const String _kGoogleWebClientId =
    '229419201107-lqb8h1oo0mbjip1blfikmbjvdiptibb8.apps.googleusercontent.com';

// ── Which button is loading ──
enum _LoadingState { none, google, apple, email }

class CreateAccountScreen extends StatefulWidget {
  final UserOnboardingData onboardingData;

  const CreateAccountScreen({
    super.key,
    required this.onboardingData,
  });

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  _LoadingState _loading = _LoadingState.none;
  bool _showEmailForm = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Navigate to home after any successful sign-in ──
  // Pop back to AuthGate (root). It listens to onAuthStateChange and will
  // automatically rebuild to show MainNavScreen once the session is active.
  // Pushing a new route here would conflict with AuthGate's stream events.
  void _onSuccess(String displayName) {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.87),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Google ──
  Future<void> _handleGoogleSignUp() async {
    setState(() => _loading = _LoadingState.google);
    try {
      debugPrint('[GoogleSignIn] Starting sign-in...');

      final googleUser = await GoogleSignIn(
        clientId: _kGoogleIosClientId,
        serverClientId: _kGoogleWebClientId,
      ).signIn();

      debugPrint('[GoogleSignIn] signIn() returned: $googleUser');

      if (googleUser == null) {
        // User cancelled
        debugPrint('[GoogleSignIn] User cancelled the sign-in flow.');
        setState(() => _loading = _LoadingState.none);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        debugPrint('[GoogleSignIn] No ID token returned.');
        _showError('Google sign-in failed. Please try again.');
        setState(() => _loading = _LoadingState.none);
        return;
      }

      debugPrint('[GoogleSignIn] Got ID token, signing in to Supabase...');

      await SupabaseService.client.auth.signInWithIdToken(
        provider: supabase.OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );

      debugPrint('[GoogleSignIn] Supabase sign-in success. Checking if new user...');

      // Only create profile for new users — never overwrite a returning user's data.
      final existing = await SupabaseService.fetchProfile();
      if (existing == null) {
        await SupabaseService.saveProfile(widget.onboardingData);
        debugPrint('[GoogleSignIn] New user — profile created.');
      } else {
        debugPrint('[GoogleSignIn] Returning user — skipping profile write.');
      }

      _onSuccess(googleUser.displayName ?? googleUser.email);
    } catch (e, stack) {
      debugPrint('[GoogleSignIn] ERROR: $e');
      debugPrint('[GoogleSignIn] STACK: $stack');
      _showError('Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = _LoadingState.none);
    }
  }

  // ── Apple ──
  Future<void> _handleAppleSignUp() async {
    setState(() => _loading = _LoadingState.apple);
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      // TODO: pass credential to your backend / Supabase here
      // e.g. supabase.auth.signInWithIdToken(provider: OAuthProvider.apple, idToken: credential.identityToken!)
      final name = [
        credential.givenName,
        credential.familyName,
      ].whereType<String>().join(' ');
      _onSuccess(name.isNotEmpty ? name : credential.email ?? 'there');
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled) {
        _showError('Apple sign-in failed. Please try again.');
      }
    } catch (e) {
      _showError('Apple sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = _LoadingState.none);
    }
  }

  // ── Email ──
  Future<void> _handleEmailSignUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !email.contains('@')) {
      _showError('Please enter a valid email address.');
      return;
    }
    if (password.length < 8) {
      _showError('Password must be at least 8 characters.');
      return;
    }

    setState(() => _loading = _LoadingState.email);
    try {
      // TODO: wire to Supabase / Firebase
      // e.g. await supabase.auth.signUp(email: email, password: password);
      await Future.delayed(const Duration(seconds: 1)); // remove when real auth added
      _onSuccess(widget.onboardingData.name ?? 'there');
    } catch (e) {
      _showError('Could not create account. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = _LoadingState.none);
    }
  }

  bool get _isLoading => _loading != _LoadingState.none;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: null, // inherits from theme
      appBar: AppBar(
        backgroundColor: null, // inherits from theme
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const SizedBox(height: 12),

              const Text(
                "Create your\naccount.",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                "Create an account to save your plan and start your journey.",
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 48),

              // ── Google ──
              _SocialButton(
                icon: SvgPicture.string(_kGoogleLogoSvg, width: 22, height: 22),
                label: "Continue with Google",
                backgroundColor: Theme.of(context).cardColor,
                foregroundColor: Colors.black,
                border: Border.all(color: Colors.black12, width: 1.5),
                isLoading: _loading == _LoadingState.google,
                disabled: _isLoading,
                onPressed: _handleGoogleSignUp,
              ),

              const SizedBox(height: 14),

              // ── Apple ──
              _SocialButton(
                icon: const _AppleIcon(),
                label: "Continue with Apple",
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                isLoading: _loading == _LoadingState.apple,
                disabled: _isLoading,
                onPressed: _handleAppleSignUp,
              ),

              const SizedBox(height: 14),

              // ── Email toggle ──
              if (!_showEmailForm)
                _SocialButton(
                  icon: Icon(Icons.mail_outline, color: Theme.of(context).colorScheme.onSurface, size: 22),
                  label: "Continue with Email",
                  backgroundColor: Theme.of(context).cardColor,
                  foregroundColor: Colors.black,
                  border: Border.all(color: Colors.black12, width: 1.5),
                  disabled: _isLoading,
                  onPressed: () => setState(() => _showEmailForm = true),
                ),

              // ── Email form ──
              if (_showEmailForm)
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isLoading,
                        decoration: const InputDecoration(
                          labelText: "Email address",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          labelText: "Password",
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Must be at least 8 characters.",
                        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38)),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleEmailSignUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            disabledBackgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(34),
                            ),
                          ),
                          child: _loading == _LoadingState.email
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Create Account",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                      child: Divider(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
                          thickness: 1)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text("Already have an account?",
                        style:
                            TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45))),
                  ),
                  Expanded(
                      child: Divider(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
                          thickness: 1)),
                ],
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          // TODO: navigate to LogInScreen
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: BorderSide(color: Theme.of(context).colorScheme.onSurface, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(34)),
                  ),
                  child: const Text("Log In",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ),

              const SizedBox(height: 32),

              Center(
                child: Text(
                  "By continuing, you agree to Kloudy's\nTerms of Service and Privacy Policy.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
                    height: 1.5,
                  ),
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

// ──────────────────────────────────────────────
// Reusable social button with loading state
// ──────────────────────────────────────────────

class _SocialButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final BoxBorder? border;
  final bool isLoading;
  final bool disabled;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
    this.border,
    this.isLoading = false,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOpacity = disabled && !isLoading ? 0.5 : 1.0;

    return Opacity(
      opacity: effectiveOpacity,
      child: GestureDetector(
        onTap: disabled ? null : onPressed,
        child: Container(
          width: double.infinity,
          height: 62,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(34),
            border: border,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: foregroundColor,
                  ),
                )
              else
                icon,
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: foregroundColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Apple logo — official glyph path via flutter_svg
// ──────────────────────────────────────────────

const String _kAppleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 384 512">
  <path fill="white" d="M318.7 268.7c-.2-36.7 16.4-64.4 50-84.8-18.8-26.9-47.2-41.7-84.7-44.6-35.5-2.8-74.3 20.7-88.5 20.7-15 0-49.4-19.7-76.4-19.7C63.3 141.2 4 184.8 4 273.5q0 39.3 14.4 81.2c12.8 36.7 59 126.7 107.2 125.2 25.2-.6 43-17.9 75.8-17.9 31.8 0 48.3 17.9 76.4 17.9 48.6-.7 90.4-82.5 102.6-119.3-65.2-30.7-61.7-90-61.7-91.9zm-90.5-180.9c27.3-32.4 24.8-61.9 24-72.5-24.1 1.4-52 16.4-67.9 34.9-17.5 19.8-27.8 44.3-25.6 71.9 26-1.9 49.7-14.7 69.5-34.3z"/>
</svg>
''';

class _AppleIcon extends StatelessWidget {
  const _AppleIcon({this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      _kAppleLogoSvg,
      width: size * 0.84,
      height: size,
    );
  }
}