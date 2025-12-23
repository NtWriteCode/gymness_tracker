import 'package:flutter/material.dart';
import '../providers/settings_provider.dart';

class AppTheme {
  static final _defaultLightScheme = ColorScheme.fromSeed(seedColor: Colors.blue);
  static final _defaultDarkScheme = ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: Brightness.dark,
  );

  static ThemeData getLight(ColorScheme? dynamicContent) {
    return ThemeData(
      colorScheme: dynamicContent ?? _defaultLightScheme,
      useMaterial3: true,
    );
  }

  static ThemeData getDark(ColorScheme? dynamicContent, AppThemeMode mode) {
    final baseScheme = dynamicContent ?? _defaultDarkScheme;
    
    // Handle AMOLED
    if (mode == AppThemeMode.amoled) {
      final amoledScheme = baseScheme.copyWith(
        surface: Colors.black,
      );
      return ThemeData(
        colorScheme: amoledScheme,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          scrolledUnderElevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.black,
        ),
      );
    }

    return ThemeData(
      colorScheme: baseScheme,
      useMaterial3: true,
    );
  }

  static ThemeMode getThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
      case AppThemeMode.amoled:
        return ThemeMode.dark;
      case AppThemeMode.dynamic:
        return ThemeMode.system;
    }
  }
}
