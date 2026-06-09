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
    this.season = '',
    this.district,
    this.persist = true,
    this.seasonAuto = true,
    this.useLiveClimate = true,
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
  /// Empty = API detects season from current date.
  final String season;
  final String? district;
  final bool persist;
  final bool seasonAuto;
  final bool useLiveClimate;

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
        if (!seasonAuto && season.isNotEmpty) 'season': season,
        if (district != null && district!.isNotEmpty) 'district': district,
        'persist': persist,
        'use_live_climate': useLiveClimate,
      };
}
