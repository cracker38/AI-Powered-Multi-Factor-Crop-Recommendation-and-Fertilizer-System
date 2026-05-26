class AdminAnalytics {
  const AdminAnalytics({
    required this.modelLoaded,
    required this.modelVersion,
    required this.totalFarmers,
    required this.totalPredictions,
    required this.trainingDatasetsCount,
    this.meta,
    this.cropDistribution = const {},
    this.activeFarmers = 0,
    this.disabledFarmers = 0,
    this.avgPredictionsPerFarmer = 0,
    this.modelAccuracy,
    this.modelPrecision,
    this.modelRecall,
    this.modelF1,
    this.lastTrainedAt,
    this.fertilizerUsage = const {},
    this.avgSoilHealthScore = 0,
    this.outcomeFeedbackCount = 0,
    this.avgOutcomeRating,
    this.fertilizerFollowRatePct,
  });

  final bool modelLoaded;
  final String? modelVersion;
  final int totalFarmers;
  final int totalPredictions;
  final int trainingDatasetsCount;
  final Map<String, dynamic>? meta;
  final Map<String, int> cropDistribution;
  final int activeFarmers;
  final int disabledFarmers;
  final double avgPredictionsPerFarmer;
  final double? modelAccuracy;
  final double? modelPrecision;
  final double? modelRecall;
  final double? modelF1;
  final DateTime? lastTrainedAt;
  final Map<String, int> fertilizerUsage;
  final double avgSoilHealthScore;
  final int outcomeFeedbackCount;
  final double? avgOutcomeRating;
  final double? fertilizerFollowRatePct;

  factory AdminAnalytics.fromJson(Map<String, dynamic> json) {
    Map<String, int> parseDist(dynamic raw) {
      final dist = <String, int>{};
      if (raw is Map) {
        raw.forEach((k, v) {
          if (v is num) dist[k.toString()] = v.toInt();
        });
      }
      return dist;
    }

    DateTime? trained;
    final trainedRaw = json['last_trained_at'];
    if (trainedRaw is String) trained = DateTime.tryParse(trainedRaw);

    return AdminAnalytics(
      modelLoaded: json['model_loaded'] as bool? ?? false,
      modelVersion: json['model_version'] as String?,
      totalFarmers: json['total_farmers'] as int? ?? 0,
      totalPredictions: json['total_predictions'] as int? ?? 0,
      trainingDatasetsCount: json['training_datasets_count'] as int? ?? 0,
      meta: json['meta'] as Map<String, dynamic>?,
      cropDistribution: parseDist(json['crop_distribution']),
      activeFarmers: json['active_farmers'] as int? ?? 0,
      disabledFarmers: json['disabled_farmers'] as int? ?? 0,
      avgPredictionsPerFarmer: (json['avg_predictions_per_farmer'] as num?)?.toDouble() ?? 0,
      modelAccuracy: (json['model_accuracy'] as num?)?.toDouble(),
      modelPrecision: (json['model_precision'] as num?)?.toDouble(),
      modelRecall: (json['model_recall'] as num?)?.toDouble(),
      modelF1: (json['model_f1'] as num?)?.toDouble(),
      lastTrainedAt: trained,
      fertilizerUsage: parseDist(json['fertilizer_usage']),
      avgSoilHealthScore: (json['avg_soil_health_score'] as num?)?.toDouble() ?? 0,
      outcomeFeedbackCount: json['outcome_feedback_count'] as int? ?? 0,
      avgOutcomeRating: (json['avg_outcome_rating'] as num?)?.toDouble(),
      fertilizerFollowRatePct: (json['fertilizer_follow_rate_pct'] as num?)?.toDouble(),
    );
  }

  double? get bestAccuracy => modelAccuracy ?? _accuracyFromMeta();

  double? _accuracyFromMeta() {
    final m = meta;
    if (m == null) return null;
    final best = modelVersion;
    if (best == null) return null;
    final metrics = m['all_metrics'] as Map<String, dynamic>?;
    final modelMetrics = metrics?[best] as Map<String, dynamic>?;
    return (modelMetrics?['accuracy'] as num?)?.toDouble();
  }
}
