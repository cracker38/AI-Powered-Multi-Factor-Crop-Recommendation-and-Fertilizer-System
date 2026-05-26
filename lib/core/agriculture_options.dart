/// Soil types and Rwanda growing seasons for multi-factor evaluation.
class AgricultureOptions {
  static const soilTypes = [
    ('loam', 'Loam'),
    ('clay', 'Clay'),
    ('sandy', 'Sandy'),
    ('silt', 'Silt'),
    ('volcanic', 'Volcanic ash'),
    ('peat', 'Peat / organic'),
  ];

  static const seasons = [
    ('season_a', 'Season A — Short rains (Sep–Jan)'),
    ('season_b', 'Season B — Long rains (Feb–Jun)'),
    ('season_c', 'Season C — Dry season (Jul–Aug)'),
  ];

  static String soilLabel(String value) {
    for (final e in soilTypes) {
      if (e.$1 == value) return e.$2;
    }
    return value;
  }

  static String seasonLabel(String value) {
    for (final e in seasons) {
      if (e.$1 == value) return e.$2;
    }
    return value.replaceAll('_', ' ');
  }
}
