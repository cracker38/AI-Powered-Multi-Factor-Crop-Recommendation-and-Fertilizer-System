import 'package:flutter/foundation.dart';

import '../models/farmer_tip.dart';
import '../models/prediction_history_item.dart';
import 'api_service.dart';

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
      final items = await api.fetchHistory(limit: 50);
      final tipsJson = await api.fetchFarmerTips();
      history = items;
      tips = tipsJson.map(FarmerTip.fromJson).toList();
      error = null;
      lastLoadedAt = DateTime.now();
    } on ApiException catch (e) {
      error = e.message;
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
