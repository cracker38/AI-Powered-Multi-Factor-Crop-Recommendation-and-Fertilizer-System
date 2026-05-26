class PredictionHistoryItem {
  const PredictionHistoryItem({
    required this.id,
    required this.topCrop,
    required this.topConfidence,
    required this.createdAt,
    required this.soilPh,
    required this.nitrogen,
    this.soilType = 'loam',
    this.season = 'season_a',
    this.soilHealthScore = 0,
  });

  final String id;
  final String topCrop;
  final double topConfidence;
  final DateTime createdAt;
  final double soilPh;
  final double nitrogen;
  final String soilType;
  final String season;
  final double soilHealthScore;

  factory PredictionHistoryItem.fromJson(Map<String, dynamic> json) {
    return PredictionHistoryItem(
      id: json['id'].toString(),
      topCrop: json['top_crop'] as String,
      topConfidence: (json['top_confidence'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      soilPh: (json['soil_ph'] as num).toDouble(),
      nitrogen: (json['nitrogen'] as num).toDouble(),
      soilType: json['soil_type'] as String? ?? 'loam',
      season: json['season'] as String? ?? 'season_a',
      soilHealthScore: (json['soil_health_score'] as num?)?.toDouble() ?? 0,
    );
  }
}
