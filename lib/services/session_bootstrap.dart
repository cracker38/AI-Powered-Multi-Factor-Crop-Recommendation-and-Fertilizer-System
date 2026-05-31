import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import 'api_service.dart';
import 'firestore_service.dart';

/// Loads the signed-in user's profile from the API, with Firestore fallback.
class SessionBootstrap {
  static const Duration apiTimeout = Duration(seconds: 15);

  static Future<UserProfile> loadProfile(ApiService api) async {
    try {
      return await api.syncProfile().timeout(apiTimeout);
    } on TimeoutException {
      return _firestoreFallback(
        'The server took too long. Loading your profile from Firebase…',
      );
    } on ApiException catch (e) {
      if (e.statusCode == 503 ||
          e.statusCode == 403 ||
          e.statusCode == 404 ||
          e.message.toLowerCase().contains('firestore')) {
        return _firestoreFallback(e.message);
      }
      rethrow;
    }
  }

  static Future<UserProfile> _firestoreFallback(String hint) async {
    final profile = await FirestoreService().fetchCurrentUserProfile();
    if (profile != null) {
      if (!profile.disabled) return profile;
      throw ApiException('Account disabled');
    }
    throw ApiException(
      '$hint If you are admin, add users/{uid} in Firestore or fix '
      'backend/firebase-service-account.json and run seed_admin.py.',
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
