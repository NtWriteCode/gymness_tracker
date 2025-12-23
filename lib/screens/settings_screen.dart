// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            'Appearance',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Consumer<SettingsProvider>(
          builder: (context, settings, _) {
            return Column(
              children: AppThemeMode.values.map((mode) {
                String title;
                String subtitle;
                switch (mode) {
                  case AppThemeMode.light:
                    title = 'Light';
                    subtitle = 'Standard light theme';
                    break;
                  case AppThemeMode.dark:
                    title = 'Dark';
                    subtitle = 'Standard dark theme';
                    break;
                  case AppThemeMode.amoled:
                    title = 'Pure Black (AMOLED)';
                    subtitle = 'Battery saver for OLED screens';
                    break;
                  case AppThemeMode.dynamic:
                    title = 'Dynamic Material You';
                    subtitle = 'Adapts to system wallpaper & mode';
                    break;
                }
                return RadioListTile<AppThemeMode>(
                  title: Text(title),
                  subtitle: Text(subtitle),
                  value: mode,
                  groupValue: settings.currentTheme,
                  onChanged: (AppThemeMode? value) {
                    if (value != null) {
                      settings.setTheme(value);
                    }
                  },
                );
              }).toList(),
            );
          },
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Workout Settings',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Consumer<SettingsProvider>(
          builder: (context, settings, _) {
            return Column(
              children: [
                ListTile(
                  title: const Text('GPS Match Radius'),
                  subtitle: Text('Distance to detect a gym: ${settings.gpsRadius.round()} meters'),
                  trailing: Text(
                    '${settings.gpsRadius.round()} m',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Slider(
                    value: settings.gpsRadius,
                    min: 10,
                    max: 500,
                    divisions: 49,
                    label: '${settings.gpsRadius.round()} m',
                    onChanged: (double value) {
                      settings.setGpsRadius(value);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
