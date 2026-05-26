import 'package:firebase_auth/firebase_auth.dart';

/// User-friendly messages for Firebase Auth errors.
String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-not-found':
        return 'No account found for this email. Register first or check the spelling.';
      case 'missing-email':
        return 'Email is required.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a few minutes and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'operation-not-allowed':
        return 'Password reset is disabled in Firebase. Enable Email/Password in Authentication.';
      default:
        return error.message ?? 'Authentication failed (${error.code}).';
    }
  }
  return error.toString().replaceFirst('Exception: ', '');
}
