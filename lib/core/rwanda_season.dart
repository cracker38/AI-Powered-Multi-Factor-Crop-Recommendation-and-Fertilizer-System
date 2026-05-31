/// Rwanda growing seasons from the current calendar date.
class RwandaSeason {
  static const seasonA = 'season_a';
  static const seasonB = 'season_b';
  static const seasonC = 'season_c';

  /// Season A: Sep–Jan, B: Feb–Jun, C: Jul–Aug
  static String forDate(DateTime date) {
    final m = date.month;
    if (m == 9 || m == 10 || m == 11 || m == 12 || m == 1) return seasonA;
    if (m >= 2 && m <= 6) return seasonB;
    return seasonC;
  }

  static String current() => forDate(DateTime.now());

  static String label(String seasonId) {
    switch (seasonId) {
      case seasonA:
        return 'Season A — Short rains (Sep–Jan)';
      case seasonB:
        return 'Season B — Long rains (Feb–Jun)';
      case seasonC:
        return 'Season C — Dry season (Jul–Aug)';
      default:
        return seasonId.replaceAll('_', ' ');
    }
  }

  static String shortAdvice(String seasonId) {
    switch (seasonId) {
      case seasonA:
        return 'Plant with the short rains; improve drainage on clay soils.';
      case seasonB:
        return 'Main season — apply basal fertilizer at planting and weed early.';
      case seasonC:
        return 'Dry period — use drought-tolerant crops or irrigation.';
      default:
        return '';
    }
  }
}
