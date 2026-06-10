import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/rwanda_districts.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/auth/auth_form_card.dart';
import '../../widgets/auth/auth_gradient_background.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/shared/modern_auth_decor.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.onRegistered});

  final Future<void> Function() onRegistered;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _farmSize = TextEditingController();
  final _confirm = TextEditingController();
  final _auth = AuthService();
  String? _district;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _phone.dispose();
    _farmSize.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (AuthService.isAdminEmail(_email.text)) {
      setState(() => _error = 'This email is reserved for administration and cannot be used for registration.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final farmSize = double.tryParse(_farmSize.text.replaceAll(',', '.'));
    if (farmSize == null || farmSize <= 0) {
      setState(() => _error = 'Enter a valid farm size in hectares');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cred = await _auth.registerFarmer(_email.text, _password.text);
      final user = cred.user ?? FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw FirebaseAuthException(code: 'user-not-found', message: 'Could not create Firebase account');
      }
      await user.getIdToken(true);

      final profile = UserProfile(
        id: user.uid,
        email: (user.email ?? _email.text).trim().toLowerCase(),
        displayName: _name.text.trim(),
        role: 'farmer',
        disabled: false,
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        district: _district != null && _district!.isNotEmpty ? _district : null,
        farmSizeHa: farmSize,
        approvalStatus: 'pending',
      );

      // Save to Firestore first so registration works even if the API/Firestore Admin SDK is slow.
      await FirestoreService().upsertUserProfile(profile);

      var apiSynced = false;
      try {
        final base = await _auth.readApiBase();
        final api = ApiService(baseUrl: base, getToken: _auth.getIdToken);
        final synced = await api
            .registerFarmer(
              displayName: profile.displayName ?? _name.text.trim(),
              farmSizeHa: farmSize,
              phone: profile.phone,
              district: profile.district,
            )
            .timeout(const Duration(seconds: 12));
        await FirestoreService().upsertUserProfile(synced);
        apiSynced = true;
      } on ApiException catch (e) {
        if (e.statusCode == 409 || e.statusCode == 403) {
          rethrow;
        }
        apiSynced = false;
      } on TimeoutException {
        apiSynced = false;
      } catch (_) {
        apiSynced = false;
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Account submitted'),
          content: Text(
            apiSynced
                ? 'Your farmer account is waiting for admin approval. Sign in again after it is activated.'
                : 'Your account is waiting for admin approval. The API is not fully synced yet, but your registration was saved. Sign in again after activation.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Registration failed');
      await _auth.signOut();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
      await _auth.signOut();
    } catch (e) {
      final detail = e.toString();
      final unreachable = detail.contains('Connection refused') ||
          detail.contains('Failed host lookup') ||
          detail.contains('Failed to fetch') ||
          detail.contains('SocketException');
      setState(() => _error = unreachable
          ? 'Could not reach the API. Your Firebase login may still work — ensure scripts/start-api.ps1 is running on port 8000.'
          : detail);
      await _auth.signOut();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthGradientBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                  SafeArea(
                    bottom: false,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: _busy ? null : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      ),
                    ),
                  ),
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
                              children: [
                                      const Text(
                                        'Create account',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Register for crop and fertilizer recommendations tailored to your district.',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 28),
                                      AuthTextField(
                                        controller: _name,
                                        label: 'Full name',
                                        hint: 'Your name',
                                        icon: Icons.person_outline_rounded,
                                        textInputAction: TextInputAction.next,
                                        validator: (v) =>
                                            v == null || v.trim().length < 2 ? 'Enter your full name' : null,
                                      ),
                                      const SizedBox(height: 18),
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
                                        controller: _phone,
                                        label: 'Phone (optional)',
                                        hint: '+250 7XX XXX XXX',
                                        icon: Icons.phone_outlined,
                                        keyboardType: TextInputType.phone,
                                        textInputAction: TextInputAction.next,
                                      ),
                                      const SizedBox(height: 18),
                                      _DistrictField(
                                        value: _district,
                                        onChanged: (v) => setState(() => _district = v),
                                      ),
                                      const SizedBox(height: 18),
                                      AuthTextField(
                                        controller: _farmSize,
                                        label: 'Farm size (hectares)',
                                        hint: 'e.g. 2.5',
                                        icon: Icons.landscape_outlined,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        textInputAction: TextInputAction.next,
                                        validator: (v) {
                                          final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                                          if (n == null || n <= 0) return 'Enter farm size in hectares';
                                          if (n > 10000) return 'Enter a realistic farm size';
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 18),
                                      AuthTextField(
                                        controller: _password,
                                        label: 'Password',
                                        hint: 'At least 6 characters',
                                        icon: Icons.lock_outline_rounded,
                                        obscureText: true,
                                        textInputAction: TextInputAction.next,
                                        validator: (v) =>
                                            v == null || v.length < 6 ? 'Password must be at least 6 characters' : null,
                                      ),
                                      const SizedBox(height: 18),
                                      AuthTextField(
                                        controller: _confirm,
                                        label: 'Confirm password',
                                        hint: 'Repeat password',
                                        icon: Icons.lock_outline_rounded,
                                        obscureText: true,
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: (_) => _register(),
                                        validator: (v) => v != _password.text ? 'Passwords do not match' : null,
                                      ),
                                      if (_error != null) ...[
                                        const SizedBox(height: 16),
                                        _ErrorBanner(message: _error!),
                                      ],
                                      const SizedBox(height: 24),
                                      GradientPrimaryButton(
                                        onPressed: _busy ? null : _register,
                                        busy: _busy,
                                        label: 'Create farmer account',
                                        icon: Icons.person_add_rounded,
                                      ),
                                      const SizedBox(height: 24),
                                      Row(
                                        children: [
                                          Expanded(child: Divider(color: Colors.grey.shade300)),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            child: Text(
                                              'Already registered?',
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
                                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'Back to sign in',
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
            );
          },
        ),
      ),
    );
  }
}

class _DistrictField extends StatelessWidget {
  const _DistrictField({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'District (recommended)',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            hintText: 'Select district',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w400),
            filled: true,
            fillColor: const Color(0xFFF8FAF8),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            prefixIcon: Container(
              margin: const EdgeInsets.only(left: 12, right: 8, top: 10, bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('Select district')),
            ...RwandaDistricts.list.map((d) => DropdownMenuItem(value: d, child: Text(d))),
          ],
          onChanged: onChanged,
        ),
      ],
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
