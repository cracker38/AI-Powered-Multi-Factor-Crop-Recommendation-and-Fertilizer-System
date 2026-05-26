class OutcomeFeedback {
  const OutcomeFeedback({
    required this.id,
    required this.predictionId,
    required this.recommendedCrop,
    required this.yieldRating,
    required this.followedFertilizer,
    this.cropGrown,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String predictionId;
  final String recommendedCrop;
  final int yieldRating;
  final bool followedFertilizer;
  final String? cropGrown;
  final String? notes;
  final DateTime? createdAt;

  factory OutcomeFeedback.fromJson(Map<String, dynamic> json) {
    DateTime? created;
    final raw = json['created_at'];
    if (raw is String) created = DateTime.tryParse(raw);
    return OutcomeFeedback(
      id: json['id'].toString(),
      predictionId: json['prediction_id'] as String? ?? '',
      recommendedCrop: json['recommended_crop'] as String? ?? '',
      yieldRating: json['yield_rating'] as int? ?? 0,
      followedFertilizer: json['followed_fertilizer'] as bool? ?? false,
      cropGrown: json['crop_grown'] as String?,
      notes: json['notes'] as String?,
      createdAt: created,
    );
  }
}
