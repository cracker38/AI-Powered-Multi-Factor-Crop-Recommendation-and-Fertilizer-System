import 'crop_prediction.dart';
import 'fertilizer_recommendation.dart';

class PredictionDetail {
  const PredictionDetail({
    required this.id,
    required this.topCrop,
    required this.topConfidence,
    required this.explanation,
    required this.modelVersion,
    required this.createdAt,
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.soilMoisture,
    required this.temperatureC,
    required this.humidityPct,
    required this.soilPh,
    required this.rainfallMm,
    required this.fullRanking,
    this.soilType = 'loam',
    this.season = 'season_a',
    this.district,
    this.soilHealthScore = 0,
    this.soilHealthLabel = '',
    this.fertilizers = const [],
    this.nutrientAnalysis,
    this.weatherInsight,
    this.precisionNotes = const [],
    this.environmentAnalysis = const [],
    this.hasFeedback = false,
    this.feedbackRating,
    this.seasonLabel = '',
    this.improvementActions = const [],
  });

  final String id;
  final String topCrop;
  final double topConfidence;
  final String explanation;
  final String modelVersion;
  final DateTime createdAt;
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final double soilMoisture;
  final double temperatureC;
  final double humidityPct;
  final double soilPh;
  final double rainfallMm;
  final String soilType;
  final String season;
  final String? district;
  final double soilHealthScore;
  final String soilHealthLabel;
  final List<FertilizerRecommendation> fertilizers;
  final NutrientAnalysis? nutrientAnalysis;
  final WeatherInsight? weatherInsight;
  final List<String> precisionNotes;
  final List<String> environmentAnalysis;
  final List<CropRank> fullRanking;
  final bool hasFeedback;
  final int? feedbackRating;
  final String seasonLabel;
  final List<String> improvementActions;

  bool get isLowConfidence => topConfidence < 0.5;

  factory PredictionDetail.fromJson(Map<String, dynamic> json) {
    final ranking = (json['full_ranking'] as List<dynamic>? ?? [])
        .map((e) => CropRank.fromJson(e as Map<String, dynamic>))
        .toList();
    final fertList = (json['fertilizers'] as List<dynamic>?)
            ?.map((e) => FertilizerRecommendation.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final na = json['nutrient_analysis'];
    final wi = json['weather_insight'];
    return PredictionDetail(
      id: json['id'].toString(),
      topCrop: json['top_crop'] as String,
      topConfidence: (json['top_confidence'] as num).toDouble(),
      explanation: json['explanation'] as String? ?? '',
      modelVersion: json['model_version'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      nitrogen: (json['nitrogen'] as num).toDouble(),
      phosphorus: (json['phosphorus'] as num).toDouble(),
      potassium: (json['potassium'] as num).toDouble(),
      soilMoisture: (json['soil_moisture'] as num).toDouble(),
      temperatureC: (json['temperature_c'] as num).toDouble(),
      humidityPct: (json['humidity_pct'] as num).toDouble(),
      soilPh: (json['soil_ph'] as num).toDouble(),
      rainfallMm: (json['rainfall_mm'] as num).toDouble(),
      soilType: json['soil_type'] as String? ?? 'loam',
      season: json['season'] as String? ?? 'season_a',
      district: json['district'] as String?,
      soilHealthScore: (json['soil_health_score'] as num?)?.toDouble() ?? 0,
      soilHealthLabel: json['soil_health_label'] as String? ?? '',
      fertilizers: fertList,
      nutrientAnalysis: na != null ? NutrientAnalysis.fromJson(na as Map<String, dynamic>) : null,
      weatherInsight: wi != null ? WeatherInsight.fromJson(wi as Map<String, dynamic>) : null,
      precisionNotes: (json['precision_notes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      environmentAnalysis:
          (json['environment_analysis'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      fullRanking: ranking,
      hasFeedback: json['has_feedback'] as bool? ?? false,
      feedbackRating: json['feedback_rating'] as int?,
      seasonLabel: json['season_label'] as String? ?? '',
      improvementActions:
          (json['improvement_actions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
