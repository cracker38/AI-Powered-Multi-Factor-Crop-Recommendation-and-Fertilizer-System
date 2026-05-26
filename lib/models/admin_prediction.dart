class AdminPrediction {
  const AdminPrediction({
    required this.id,
    required this.userUid,
    required this.topCrop,
    required this.topConfidence,
    required this.modelVersion,
    this.farmerEmail,
    this.farmerName,
    this.createdAt,
    this.district,
    this.season,
    this.soilType,
    this.soilHealthScore = 0,
    this.soilPh,
    this.nitrogen,
    this.phosphorus,
    this.potassium,
  });

  final String id;
  final String userUid;
  final String topCrop;
  final double topConfidence;
  final String modelVersion;
  final String? farmerEmail;
  final String? farmerName;
  final DateTime? createdAt;
  final String? district;
  final String? season;
  final String? soilType;
  final double soilHealthScore;
  final double? soilPh;
  final double? nitrogen;
  final double? phosphorus;
  final double? potassium;

  factory AdminPrediction.fromJson(Map<String, dynamic> json) {
    DateTime? created;
    final raw = json['created_at'];
    if (raw is String) {
      created = DateTime.tryParse(raw);
    }
    double? numOrNull(dynamic v) => v == null ? null : (v as num).toDouble();

    return AdminPrediction(
      id: json['id'].toString(),
      userUid: json['user_uid'] as String? ?? '',
      topCrop: json['top_crop'] as String? ?? '',
      topConfidence: (json['top_confidence'] as num?)?.toDouble() ?? 0,
      modelVersion: json['model_version'] as String? ?? '',
      farmerEmail: json['farmer_email'] as String?,
      farmerName: json['farmer_name'] as String?,
      createdAt: created,
      district: json['district'] as String?,
      season: json['season'] as String?,
      soilType: json['soil_type'] as String?,
      soilHealthScore: (json['soil_health_score'] as num?)?.toDouble() ?? 0,
      soilPh: numOrNull(json['soil_ph']),
      nitrogen: numOrNull(json['nitrogen']),
      phosphorus: numOrNull(json['phosphorus']),
      potassium: numOrNull(json['potassium']),
    );
  }

  String get seasonLabel {
    if (season == null || season!.isEmpty) return '—';
    return season!.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1)}';
    }).join(' ');
  }
}
