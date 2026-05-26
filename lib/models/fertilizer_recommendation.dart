class FertilizerRecommendation {
  const FertilizerRecommendation({
    required this.name,
    required this.type,
    required this.applicationRate,
    required this.timing,
    required this.purpose,
    required this.priority,
    this.npk = '—',
  });

  final String name;
  final String type;
  final String applicationRate;
  final String timing;
  final String purpose;
  final String priority;
  final String npk;

  factory FertilizerRecommendation.fromJson(Map<String, dynamic> json) {
    return FertilizerRecommendation(
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      applicationRate: json['application_rate'] as String? ?? '',
      timing: json['timing'] as String? ?? '',
      purpose: json['purpose'] as String? ?? '',
      priority: json['priority'] as String? ?? 'medium',
      npk: json['npk'] as String? ?? '—',
    );
  }
}

class NutrientAnalysis {
  const NutrientAnalysis({
    required this.current,
    required this.optimal,
    required this.gapsKgPerHa,
    required this.soilPh,
    required this.soilType,
    required this.season,
    this.district,
  });

  final Map<String, double> current;
  final Map<String, double> optimal;
  final Map<String, double> gapsKgPerHa;
  final double soilPh;
  final String soilType;
  final String season;
  final String? district;

  factory NutrientAnalysis.fromJson(Map<String, dynamic> json) {
    Map<String, double> toMap(dynamic m) {
      if (m is! Map) return {};
      return m.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
    }

    return NutrientAnalysis(
      current: toMap(json['current']),
      optimal: toMap(json['optimal']),
      gapsKgPerHa: toMap(json['gaps_kg_per_ha']),
      soilPh: (json['soil_ph'] as num?)?.toDouble() ?? 0,
      soilType: json['soil_type'] as String? ?? 'loam',
      season: json['season'] as String? ?? 'season_a',
      district: json['district'] as String?,
    );
  }
}

class ForecastDay {
  const ForecastDay({
    required this.date,
    this.precipitationMm = 0,
    this.tempMaxC,
    this.tempMinC,
  });

  final String date;
  final double precipitationMm;
  final double? tempMaxC;
  final double? tempMinC;

  factory ForecastDay.fromJson(Map<String, dynamic> json) => ForecastDay(
        date: json['date'] as String? ?? '',
        precipitationMm: (json['precipitation_mm'] as num?)?.toDouble() ?? 0,
        tempMaxC: (json['temp_max_c'] as num?)?.toDouble(),
        tempMinC: (json['temp_min_c'] as num?)?.toDouble(),
      );
}

class WeatherInsight {
  const WeatherInsight({
    required this.seasonName,
    required this.seasonMonths,
    required this.seasonalRainfall,
    required this.seasonalAdvice,
    this.districtNote = '',
    this.alerts = const [],
    this.forecastNote = '',
    this.liveAvailable = false,
    this.liveTemperatureC,
    this.liveHumidityPct,
    this.forecastPrecipitationMm7d,
    this.forecastDaily = const [],
    this.liveDataSource = '',
  });

  final String seasonName;
  final String seasonMonths;
  final String seasonalRainfall;
  final String seasonalAdvice;
  final String districtNote;
  final List<String> alerts;
  final String forecastNote;
  final bool liveAvailable;
  final double? liveTemperatureC;
  final double? liveHumidityPct;
  final double? forecastPrecipitationMm7d;
  final List<ForecastDay> forecastDaily;
  final String liveDataSource;

  factory WeatherInsight.fromJson(Map<String, dynamic> json) {
    return WeatherInsight(
      seasonName: json['season_name'] as String? ?? '',
      seasonMonths: json['season_months'] as String? ?? '',
      seasonalRainfall: json['seasonal_rainfall'] as String? ?? '',
      seasonalAdvice: json['seasonal_advice'] as String? ?? '',
      districtNote: json['district_note'] as String? ?? '',
      alerts: (json['alerts'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      forecastNote: json['forecast_note'] as String? ?? '',
      liveAvailable: json['live_available'] as bool? ?? false,
      liveTemperatureC: (json['live_temperature_c'] as num?)?.toDouble(),
      liveHumidityPct: (json['live_humidity_pct'] as num?)?.toDouble(),
      forecastPrecipitationMm7d: (json['forecast_precipitation_mm_7d'] as num?)?.toDouble(),
      forecastDaily: (json['forecast_daily'] as List<dynamic>?)
              ?.map((e) => ForecastDay.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      liveDataSource: json['live_data_source'] as String? ?? '',
    );
  }
}
