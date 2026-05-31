import 'fertilizer_recommendation.dart';

class CropRank {
  const CropRank({required this.crop, required this.confidence});
  final String crop;
  final double confidence;

  factory CropRank.fromJson(Map<String, dynamic> json) => CropRank(
        crop: json['crop'] as String,
        confidence: (json['confidence'] as num).toDouble(),
      );
}

class CropPrediction {
  const CropPrediction({
    required this.topCrop,
    required this.topConfidence,
    required this.explanation,
    required this.fullRanking,
    required this.modelVersion,
    this.predictionId,
    this.soilHealthScore = 0,
    this.soilHealthLabel = '',
    this.fertilizers = const [],
    this.nutrientAnalysis,
    this.weatherInsight,
    this.precisionNotes = const [],
    this.seasonUsed = '',
    this.seasonLabel = '',
    this.improvementActions = const [],
  });

  final String topCrop;
  final double topConfidence;
  final String explanation;
  final List<CropRank> fullRanking;
  final String modelVersion;
  final String? predictionId;
  final double soilHealthScore;
  final String soilHealthLabel;
  final List<FertilizerRecommendation> fertilizers;
  final NutrientAnalysis? nutrientAnalysis;
  final WeatherInsight? weatherInsight;
  final List<String> precisionNotes;
  final String seasonUsed;
  final String seasonLabel;
  final List<String> improvementActions;

  bool get isLowConfidence => topConfidence < 0.5;

  factory CropPrediction.fromJson(Map<String, dynamic> json) {
    final ranking = (json['full_ranking'] as List<dynamic>)
        .map((e) => CropRank.fromJson(e as Map<String, dynamic>))
        .toList();
    final fertList = (json['fertilizers'] as List<dynamic>?)
            ?.map((e) => FertilizerRecommendation.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final na = json['nutrient_analysis'];
    final wi = json['weather_insight'];
    return CropPrediction(
      topCrop: json['top_crop'] as String,
      topConfidence: (json['top_confidence'] as num).toDouble(),
      explanation: json['explanation'] as String,
      fullRanking: ranking,
      modelVersion: json['model_version'] as String,
      predictionId: json['prediction_id']?.toString(),
      soilHealthScore: (json['soil_health_score'] as num?)?.toDouble() ?? 0,
      soilHealthLabel: json['soil_health_label'] as String? ?? '',
      fertilizers: fertList,
      nutrientAnalysis: na != null ? NutrientAnalysis.fromJson(na as Map<String, dynamic>) : null,
      weatherInsight: wi != null ? WeatherInsight.fromJson(wi as Map<String, dynamic>) : null,
      precisionNotes: (json['precision_notes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      seasonUsed: json['season_used'] as String? ?? '',
      seasonLabel: json['season_label'] as String? ?? '',
      improvementActions:
          (json['improvement_actions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
