/// Product branding — use across splash, auth, and dashboards.
abstract final class Brand {
  static const String productName = 'AgriSmart RW';
  static const String productFullName =
      'AI-Powered Multi-Factor Crop & Fertilizer System';
  static const String tagline = 'Precision agriculture for Rwanda';
  static const String versionLabel = 'v1.2 · Production';
  static const String region = 'Republic of Rwanda';

  static String greeting(String? displayName) {
    final hour = DateTime.now().hour;
    final period = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return '$period, $name';
    return period;
  }
}
