import 'package:shared_preferences/shared_preferences.dart';

abstract final class FarmerPreferences {
  static const _showTipsKey = 'farmer_show_tips';

  static Future<bool> showTipsOnDashboard() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showTipsKey) ?? true;
  }

  static Future<void> setShowTipsOnDashboard(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showTipsKey, value);
  }
}
