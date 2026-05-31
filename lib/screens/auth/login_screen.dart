import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/session_bootstrap.dart';
import '../../widgets/auth/auth_form_card.dart';
import '../../widgets/auth/auth_gradient_background.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../utils/auth_messages.dart';
import '../../widgets/auth/forgot_password_helper.dart';
import '../../widgets/shared/modern_auth_decor.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onAuthenticated, this.initialError});

  final void Function() onAuthenticated;
  final String? initialError;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.initialError;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.signIn(_email.text, _password.text);
      final base = await _auth.readApiBase();
      final api = ApiService(baseUrl: base, getToken: _auth.getIdToken);
      final profile = await SessionBootstrap.loadProfile(api);
      await FirestoreService().syncCurrentAuthUser(profile);
      widget.onAuthenticated();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = authErrorMessage(e));
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        setState(() => _error = 'No farmer profile found. Please register first.');
      } else if (e.statusCode == 403 && e.message.contains('provisioned')) {
        setState(() => _error = 'Admin not in Firestore. Run seed_admin.py or add users/{uid} in Firebase Console.');
      } else if (e.statusCode == 503 || e.message.toLowerCase().contains('firestore')) {
        setState(() => _error = e.message);
      } else {
        setState(() => _error = e.message);
      }
      await _auth.signOut();
    } catch (e) {
      final detail = e.toString();
      final unreachable = detail.contains('Connection refused') ||
          detail.contains('Failed host lookup') ||
          detail.contains('Failed to fetch') ||
          detail.contains('SocketException');
      setState(() => _error = unreachable
          ? 'Could not reach the API. Run scripts/start-api.ps1 (port 8000), then press R to restart the app.'
          : 'Sign-in failed: $detail');
      await _auth.signOut();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthGradientBackground(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            children: [
              const AuthHeroHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: AuthFormCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                                      const Text(
                                        'Welcome back',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Sign in to your farm workspace',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 28),
                                      AuthTextField(
                                        controller: _email,
                                        label: 'Email',
                                        hint: 'name@example.com',
                                        icon: Icons.mail_outline_rounded,
                                        keyboardType: TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) return 'Email is required';
                                          if (!v.contains('@')) return 'Enter a valid email';
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 18),
                                      AuthTextField(
                                        controller: _password,
                                        label: 'Password',
                                        hint: '••••••••',
                                        icon: Icons.lock_outline_rounded,
                                        obscureText: true,
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: (_) => _login(),
                                        validator: (v) =>
                                            v == null || v.isEmpty ? 'Password is required' : null,
                                      ),
                                      if (_error != null) ...[
                                        const SizedBox(height: 16),
                                        _ErrorBanner(message: _error!),
                                      ],
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: _busy ? null : _forgotPassword,
                                          child: const Text(
                                            'Forgot password?',
                                            style: TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      GradientPrimaryButton(
                                        onPressed: _busy ? null : _login,
                                        busy: _busy,
                                        label: 'Sign in',
                                        icon: Icons.login_rounded,
                                      ),
                                      const SizedBox(height: 24),
                                      Row(
                                        children: [
                                          Expanded(child: Divider(color: Colors.grey.shade300)),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            child: Text(
                                              'New to the platform?',
                                              style: TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Expanded(child: Divider(color: Colors.grey.shade300)),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      OutlinedButton(
                                        onPressed: _busy
                                            ? null
                                            : () => Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        RegisterScreen(onRegistered: widget.onAuthenticated),
                                                  ),
                                                ),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size.fromHeight(52),
                                          side: const BorderSide(color: AppColors.primary, width: 1.5),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: const Text(
                                          'Create farmer account',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _forgotPassword() async {
    await ForgotPasswordHelper.promptAndSend(
      context,
      initialEmail: _email.text,
      auth: _auth,
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.errorText.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.errorText, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.errorText, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
