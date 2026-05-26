import 'package:flutter/foundation.dart';

import '../models/admin_analytics.dart';
import '../models/admin_prediction.dart';
import 'api_service.dart';

/// Shared admin state: analytics cache + API health for dashboard status.
class AdminController extends ChangeNotifier {
  AdminController(this.api);

  final ApiService api;

  AdminAnalytics? analytics;
  bool analyticsLoading = false;
  String? analyticsError;
  DateTime? analyticsLoadedAt;

  bool apiOnline = false;
  bool healthChecking = false;
  DateTime? healthCheckedAt;

  Future<AdminAnalytics?> loadAnalytics({bool force = false}) async {
    if (!force && analytics != null && analyticsLoadedAt != null) {
      final age = DateTime.now().difference(analyticsLoadedAt!);
      if (age.inSeconds < 45) return analytics;
    }
    analyticsLoading = true;
    analyticsError = null;
    notifyListeners();
    try {
      final j = await api.adminAnalytics();
      analytics = AdminAnalytics.fromJson(j);
      analyticsLoadedAt = DateTime.now();
      analyticsError = null;
      apiOnline = true;
      healthCheckedAt = DateTime.now();
      return analytics;
    } on ApiException catch (e) {
      analyticsError = e.message;
      apiOnline = false;
      return null;
    } finally {
      analyticsLoading = false;
      notifyListeners();
    }
  }

  Future<bool> checkApiHealth() async {
    healthChecking = true;
    notifyListeners();
    try {
      apiOnline = await api.healthCheck();
      healthCheckedAt = DateTime.now();
      return apiOnline;
    } catch (_) {
      apiOnline = false;
      return false;
    } finally {
      healthChecking = false;
      notifyListeners();
    }
  }

  Future<List<AdminPrediction>> loadRecentPredictions({int limit = 8}) async {
    final raw = await api.adminListPredictions(limit: limit);
    return raw.map(AdminPrediction.fromJson).toList();
  }

  void invalidate() {
    analytics = null;
    analyticsLoadedAt = null;
    notifyListeners();
  }
}
