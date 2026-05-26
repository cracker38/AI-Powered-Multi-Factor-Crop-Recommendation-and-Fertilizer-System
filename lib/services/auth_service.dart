import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/constants.dart';

class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return user.getIdToken(forceRefresh);
  }

  /// Platform default API URL (web/desktop: localhost, Android emulator: 10.0.2.2).
  Future<String> readApiBase() async => kDefaultApiBase;

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<UserCredential> registerFarmer(String email, String password) async {
    final normalized = email.trim().toLowerCase();
    if (normalized == kAdminEmail.toLowerCase()) {
      throw FirebaseAuthException(
        code: 'admin-email-reserved',
        message:
            'This email is reserved for system administration and cannot be used for farmer registration.',
      );
    }
    return _auth.createUserWithEmailAndPassword(email: normalized, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordResetEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || !normalized.contains('@')) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Enter a valid email address',
      );
    }

    if (kIsWeb) {
      // Continue URL must be listed under Firebase Auth → Authorized domains.
      final continueUrl = Uri.base.origin;
      await _auth.sendPasswordResetEmail(
        email: normalized,
        actionCodeSettings: ActionCodeSettings(
          url: continueUrl.endsWith('/') ? continueUrl : '$continueUrl/',
          handleCodeInApp: false,
        ),
      );
      return;
    }

    await _auth.sendPasswordResetEmail(email: normalized);
  }

  static bool isAdminEmail(String email) =>
      email.trim().toLowerCase() == kAdminEmail.toLowerCase();
}
