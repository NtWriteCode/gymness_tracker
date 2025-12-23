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

  final SharedPreferences _prefs;

  // Default to dynamic (Material You / System)
  late AppThemeMode _currentTheme;
  late double _gpsRadius;

  SettingsProvider(this._prefs) {
    _loadSettings();
  }

  AppThemeMode get currentTheme => _currentTheme;
  double get gpsRadius => _gpsRadius;

  void _loadSettings() {
    final themeIndex = _prefs.getInt(_themeKey) ?? AppThemeMode.dynamic.index;
    
    if (themeIndex >= 0 && themeIndex < AppThemeMode.values.length) {
      _currentTheme = AppThemeMode.values[themeIndex];
    } else {
      _currentTheme = AppThemeMode.dynamic;
    }
    
    _gpsRadius = _prefs.getDouble(_gpsRadiusKey) ?? 50.0;
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
}
