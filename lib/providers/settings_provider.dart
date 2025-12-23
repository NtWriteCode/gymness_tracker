import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  light,
  dark,
  amoled,
  dynamic,
}

class SettingsProvider with ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _gpsRadiusKey = 'gps_radius';
  static const String _weightKey = 'user_weight';

  final SharedPreferences _prefs;

  // Default values
  AppThemeMode _currentTheme = AppThemeMode.dynamic;
  double _gpsRadius = 50.0;
  double _userWeightKg = 75.0;

  SettingsProvider(this._prefs) {
    _loadSettings();
  }

  AppThemeMode get currentTheme => _currentTheme;
  double get gpsRadius => _gpsRadius;
  double get userWeightKg => _userWeightKg;

  void _loadSettings() {
    final themeIndex = _prefs.getInt(_themeKey) ?? AppThemeMode.dynamic.index;
    
    if (themeIndex >= 0 && themeIndex < AppThemeMode.values.length) {
      _currentTheme = AppThemeMode.values[themeIndex];
    } else {
      _currentTheme = AppThemeMode.dynamic;
    }
    
    _gpsRadius = _prefs.getDouble(_gpsRadiusKey) ?? 50.0;
    _userWeightKg = _prefs.getDouble(_weightKey) ?? 75.0;
  }

  Future<void> setTheme(AppThemeMode mode) async {
    _currentTheme = mode;
    notifyListeners();
    await _prefs.setInt(_themeKey, mode.index);
  }

  Future<void> setGpsRadius(double radius) async {
    _gpsRadius = radius;
    notifyListeners();
    await _prefs.setDouble(_gpsRadiusKey, radius);
  }

  Future<void> setUserWeight(double weight) async {
    _userWeightKg = weight;
    notifyListeners();
    await _prefs.setDouble(_weightKey, weight);
  }

}
