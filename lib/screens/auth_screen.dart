import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../theme/kloudy_theme.dart';
import '../widgets/kloudy_mark.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onDemoMode;
  final bool backendAvailable;
  final String? backendError;
  final VoidCallback onRetry;
  const AuthScreen({
    super.key,
    required this.onDemoMode,
    required this.backendAvailable,
    this.backendError,
    required this.onRetry,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false;
  bool _working = false;
  bool _hidePassword = true;
  String? _message;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!widget.backendAvailable) {
      _showMessage(
        'Kloudy could not initialize the account service on this device. You can still explore the local demo.',
      );
      return;
    }
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Enter a valid email address.');
      return;
    }
    if (password.length < 8) {
      _showMessage('Use a password with at least 8 characters.');
      return;
    }
    if (_creating && _name.text.trim().isEmpty) {
      _showMessage('Add your name to create your account.');
      return;
    }
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      if (_creating) {
        final response = await SupabaseService.client.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: SupabaseService.authRedirectUrl,
          data: {'display_name': _name.text.trim()},
        );
        if (response.session == null && mounted) {
          setState(
            () => _message =
                'Check your email to confirm your account, then come back to sign in.',
          );
        }
      } else {
        await SupabaseService.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
    } catch (error) {
      if (mounted) _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!widget.backendAvailable) return;
    final email = _email.text.trim();
    if (!email.contains('@')) {
      _showMessage('Enter your email first, and we’ll send a reset link.');
      return;
    }
    setState(() => _working = true);
    try {
      await SupabaseService.client.auth.resetPasswordForEmail(email);
      if (mounted)
        setState(
          () => _message =
              'If an account exists for that email, a reset link is on its way.',
        );
    } catch (error) {
      if (mounted) _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _resendConfirmation() async {
    if (!widget.backendAvailable) return;
    final email = _email.text.trim();
    if (!email.contains('@')) {
      _showMessage(
        'Enter your email first, and we’ll resend the confirmation link.',
      );
      return;
    }
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      await SupabaseService.client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: SupabaseService.authRedirectUrl,
      );
      if (mounted) {
        setState(
          () => _message =
              'If that account still needs email confirmation, a fresh link is on its way.',
        );
      }
    } catch (error) {
      if (mounted) _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _friendlyError(Object error) {
    debugPrint('[AuthScreen] account request failed: $error');
    final message = error.toString();
    if (message.contains('Invalid login credentials'))
      return 'That email and password don’t match. Try again or create an account.';
    if (message.contains('User already registered'))
      return 'An account already exists. Switch to Log in.';
    if (message.contains('SocketException') ||
        message.contains('Failed host lookup')) {
      return 'Kloudy could not reach the account service. Check your connection and try again. ($message)';
    }
    return 'Account request failed: $message';
  }

  void _showMessage(String value) => setState(() => _message = value);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: KloudyMark(size: 66)),
                  const SizedBox(height: 19),
                  Text(
                    _creating ? 'Create your Kloudy account' : 'Welcome back',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: kInk,
                      fontSize: 27,
                      letterSpacing: -.7,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    !widget.backendAvailable
                        ? 'Account sign-in is unavailable right now. Please try again later.'
                        : _creating
                        ? 'Save your path across money, health, and wellbeing.'
                        : 'Log in to pick up where you left off.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: kDimText,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  if (!widget.backendAvailable &&
                      widget.backendError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      widget.backendError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: kDimText, fontSize: 10),
                    ),
                    TextButton.icon(
                      onPressed: widget.onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Try connecting again'),
                    ),
                  ],
                  const SizedBox(height: 25),
                  if (_creating) ...[
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 11),
                  ],
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 11),
                  TextField(
                    controller: _password,
                    obscureText: _hidePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _hidePassword = !_hidePassword),
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  if (!_creating && widget.backendAvailable)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _working ? null : _resetPassword,
                        child: const Text('Forgot password?'),
                      ),
                    ),
                  if (_message != null) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kChipIndigo,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text(
                        _message!,
                        style: const TextStyle(
                          color: kInk,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  if (_creating && widget.backendAvailable)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _working ? null : _resendConfirmation,
                        child: const Text('Resend confirmation email'),
                      ),
                    ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _working || !widget.backendAvailable
                          ? null
                          : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: kKloudyBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _working
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _creating ? 'Create account' : 'Log in',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _working || !widget.backendAvailable
                        ? null
                        : () => setState(() {
                            _creating = !_creating;
                            _message = null;
                          }),
                    child: Text(
                      _creating
                          ? 'Already have an account?  Log in'
                          : 'New to Kloudy?  Create an account',
                      style: const TextStyle(
                        color: kKloudyBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 17),
                  Row(
                    children: [
                      Expanded(child: Divider(color: kBorder)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: kDimText,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: kBorder)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: widget.onDemoMode,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Explore the local demo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kInk,
                      side: const BorderSide(color: kBorder),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
