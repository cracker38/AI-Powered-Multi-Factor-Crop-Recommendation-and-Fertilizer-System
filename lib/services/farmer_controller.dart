import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/farmer_tip.dart';
import '../models/prediction_history_item.dart';
import 'api_service.dart';
import 'firestore_service.dart';

class FarmerController extends ChangeNotifier {
  FarmerController(this.api);

  final ApiService api;

  List<PredictionHistoryItem> history = [];
  List<FarmerTip> tips = [];
  bool loading = false;
  String? error;
  bool apiOnline = false;
  DateTime? lastLoadedAt;

  int get evaluationCount => history.length;

  double? get avgSoilHealth {
    final scores = history.where((h) => h.soilHealthScore > 0).map((h) => h.soilHealthScore);
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  PredictionHistoryItem? get latestEvaluation => history.isEmpty ? null : history.first;

  int get pendingFeedbackCount {
    // History items don't include feedback flag; count recent for CTA visibility.
    return history.length;
  }

  Future<void> refresh({bool force = false}) async {
    if (!force && lastLoadedAt != null) {
      final age = DateTime.now().difference(lastLoadedAt!);
      if (age.inSeconds < 30 && history.isNotEmpty) return;
    }

    loading = true;
    error = null;
    notifyListeners();

    try {
      apiOnline = await api.healthCheck();
      try {
        final items = await api.fetchHistory(limit: 50);
        history = items;
        final tipsJson = await api.fetchFarmerTips();
        tips = tipsJson.map(FarmerTip.fromJson).toList();
        error = null;
        lastLoadedAt = DateTime.now();
      } on ApiException catch (e) {
        if (apiOnline) {
          final fallback = await FirestoreService().fetchMyPredictionHistory(limit: 50);
          if (fallback.isNotEmpty) {
            history = fallback;
            error = 'Loaded from Firebase (API: ${e.message})';
            lastLoadedAt = DateTime.now();
          } else {
            error = e.message;
          }
        } else {
          error = 'Cannot reach API on port 8000. Run scripts/start-api.ps1 then Retry.';
        }
      }
    } on ApiException catch (e) {
      error = e.message;
      apiOnline = false;
    } on TimeoutException {
      apiOnline = await api.healthCheck();
      if (apiOnline) {
        final fallback = await FirestoreService().fetchMyPredictionHistory(limit: 50);
        history = fallback;
        error = fallback.isEmpty
            ? 'API is slow. Pull to refresh or try again.'
            : 'Loaded from Firebase while API was slow.';
        lastLoadedAt = DateTime.now();
      } else {
        error = 'Cannot reach API on port 8000. Run scripts/start-api.ps1 then Retry.';
      }
    } catch (e) {
      error = e.toString();
      apiOnline = false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void invalidate() {
    lastLoadedAt = null;
    notifyListeners();
  }
}
