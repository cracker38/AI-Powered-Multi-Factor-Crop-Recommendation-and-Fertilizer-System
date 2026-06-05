import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import 'api_service.dart';
import 'firestore_service.dart';

/// Loads the signed-in user's profile from the API, with Firestore fallback.
class SessionBootstrap {
  static const Duration apiTimeout = Duration(seconds: 12);

  static Future<UserProfile> loadProfile(ApiService api) async {
    try {
      return await api.syncProfile().timeout(apiTimeout);
    } on TimeoutException {
      return _firestoreFallback(
        'The server took too long.',
      );
    } on ApiException catch (e) {
      if (e.statusCode == 503 ||
          e.statusCode == 403 ||
          e.statusCode == 404 ||
          e.message.toLowerCase().contains('firestore') ||
          e.message.toLowerCase().contains('timed out')) {
        return _firestoreFallback(e.message);
      }
      rethrow;
    }
  }

  static Future<UserProfile> _firestoreFallback(String hint) async {
    try {
      final profile = await FirestoreService()
          .fetchCurrentUserProfile()
          .timeout(const Duration(seconds: 10));
      if (profile != null) {
        if (!profile.disabled) return profile;
        throw ApiException('Account disabled');
      }
    } on TimeoutException {
      // Fall through to error below.
    }
    throw ApiException(
      '$hint Sign in again after the API is running, or complete registration in Firebase.',
    );
  }

  static Future<ApiService> apiForCurrentUser(Future<String> readApiBase) async {
    final base = await readApiBase;
    return ApiService(
      baseUrl: base,
      getToken: () => FirebaseAuth.instance.currentUser?.getIdToken() ?? Future.value(null),
    );
  }
}
