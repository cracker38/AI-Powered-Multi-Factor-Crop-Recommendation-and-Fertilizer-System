class LiveClimate {
  const LiveClimate({
    required this.available,
    this.temperatureC,
    this.humidityPct,
    this.rainfallMm,
    this.district = 'Kigali',
    this.source = '',
    this.secondarySource = '',
    this.note = '',
    this.reason = '',
  });

  final bool available;
  final double? temperatureC;
  final double? humidityPct;
  final double? rainfallMm;
  final String district;
  final String source;
  final String secondarySource;
  final String note;
  final String reason;

  factory LiveClimate.fromJson(Map<String, dynamic> json) {
    double? d(dynamic v) => v == null ? null : (v as num).toDouble();
    return LiveClimate(
      available: json['available'] == true,
      temperatureC: d(json['temperature_c']),
      humidityPct: d(json['humidity_pct']),
      rainfallMm: d(json['rainfall_mm']),
      district: (json['district'] as String?) ?? 'Kigali',
      source: (json['source'] as String?) ?? '',
      secondarySource: (json['secondary_source'] as String?) ?? '',
      note: (json['note'] as String?) ?? '',
      reason: (json['reason'] as String?) ?? '',
    );
  }
}
