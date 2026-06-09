class FarmerFieldData {
  const FarmerFieldData({
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.soilMoisture,
    required this.temperatureC,
    required this.humidityPct,
    required this.soilPh,
    required this.rainfallMm,
    this.soilType = 'loam',
  });

  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final double soilMoisture;
  final double temperatureC;
  final double humidityPct;
  final double soilPh;
  final double rainfallMm;
  final String soilType;

  Map<String, dynamic> toJson() => {
        'nitrogen': nitrogen,
        'phosphorus': phosphorus,
        'potassium': potassium,
        'soil_moisture': soilMoisture,
        'temperature_c': temperatureC,
        'humidity_pct': humidityPct,
        'soil_ph': soilPh,
        'rainfall_mm': rainfallMm,
        'soil_type': soilType,
      };

  factory FarmerFieldData.fromJson(Map<String, dynamic> json) {
    return FarmerFieldData(
      nitrogen: (json['nitrogen'] as num).toDouble(),
      phosphorus: (json['phosphorus'] as num).toDouble(),
      potassium: (json['potassium'] as num).toDouble(),
      soilMoisture: (json['soil_moisture'] as num).toDouble(),
      temperatureC: (json['temperature_c'] as num).toDouble(),
      humidityPct: (json['humidity_pct'] as num).toDouble(),
      soilPh: (json['soil_ph'] as num).toDouble(),
      rainfallMm: (json['rainfall_mm'] as num).toDouble(),
      soilType: json['soil_type'] as String? ?? 'loam',
    );
  }

  static FarmerFieldData? tryParse(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    try {
      return FarmerFieldData.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
