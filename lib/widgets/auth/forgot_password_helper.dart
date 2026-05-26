import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../services/auth_service.dart';
import '../../utils/auth_messages.dart';

/// Sends a Firebase password reset email with consistent UX across screens.
abstract final class ForgotPasswordHelper {
  static Future<void> promptAndSend(
    BuildContext context, {
    String? initialEmail,
    AuthService? auth,
  }) async {
    final sentTo = await showDialog<String>(
      context: context,
      builder: (ctx) => _ForgotPasswordDialog(
        initialEmail: initialEmail,
        auth: auth,
      ),
    );

    if (sentTo != null && sentTo.isNotEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(
            'If an account exists for $sentTo, a reset link was sent. Check inbox and spam.',
          ),
        ),
      );
    }
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({this.initialEmail, this.auth});

  final String? initialEmail;
  final AuthService? auth;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _emailCtrl;
  final _formKey = GlobalKey<FormState>();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail?.trim() ?? '');
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await (widget.auth ?? AuthService()).sendPasswordResetEmail(_emailCtrl.text);
      if (!mounted) return;
      Navigator.pop(context, _emailCtrl.text.trim());
      return;
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authErrorMessage(e))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Reset password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'We will email you a link to choose a new password.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              enabled: !_sending,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (v) {
                final e = v?.trim() ?? '';
                if (e.isEmpty) return 'Email is required';
                if (!e.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            if (_sending) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: const Text('Send reset link'),
        ),
      ],
    );
  }
}
