class FarmInput {
  const FarmInput({
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.soilMoisture,
    required this.temperatureC,
    required this.humidityPct,
    required this.soilPh,
    required this.rainfallMm,
    this.soilType = 'loam',
    this.season = 'season_a',
    this.district,
    this.persist = true,
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
  final String season;
  final String? district;
  final bool persist;

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
        'season': season,
        if (district != null && district!.isNotEmpty) 'district': district,
        'persist': persist,
      };
}
