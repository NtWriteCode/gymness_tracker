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
  static const String _ageKey = 'user_age';
  static const String _heightKey = 'user_height';
  static const String _sexKey = 'user_sex';

  final SharedPreferences _prefs;

  // Default values
  AppThemeMode _currentTheme = AppThemeMode.dynamic;
  double _gpsRadius = 50.0;
  double _userWeightKg = 75.0;
  int _userAge = 30;
  double _userHeightCm = 175.0;
  String _userSex = 'male'; // 'male', 'female', 'apache helicopter'

  SettingsProvider(this._prefs) {
    _loadSettings();
  }

  AppThemeMode get currentTheme => _currentTheme;
  double get gpsRadius => _gpsRadius;
  double get userWeightKg => _userWeightKg;
  int get userAge => _userAge;
  double get userHeightCm => _userHeightCm;
  String get userSex => _userSex;

  void _loadSettings() {
    final themeIndex = _prefs.getInt(_themeKey) ?? AppThemeMode.dynamic.index;
    
    if (themeIndex >= 0 && themeIndex < AppThemeMode.values.length) {
      _currentTheme = AppThemeMode.values[themeIndex];
    } else {
      _currentTheme = AppThemeMode.dynamic;
    }
    
    _gpsRadius = _prefs.getDouble(_gpsRadiusKey) ?? 50.0;
    _userWeightKg = _prefs.getDouble(_weightKey) ?? 75.0;
    _userAge = _prefs.getInt(_ageKey) ?? 30;
    _userHeightCm = _prefs.getDouble(_heightKey) ?? 175.0;
    _userSex = _prefs.getString(_sexKey) ?? 'male';
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

  Future<void> setUserAge(int age) async {
    _userAge = age;
    notifyListeners();
    await _prefs.setInt(_ageKey, age);
  }

  Future<void> setUserHeight(double height) async {
    _userHeightCm = height;
    notifyListeners();
    await _prefs.setDouble(_heightKey, height);
  }

  Future<void> setUserSex(String sex) async {
    _userSex = sex;
    notifyListeners();
    await _prefs.setString(_sexKey, sex);
  }

}
