import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/workout_screen.dart';
import 'screens/history_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_screen.dart';
import 'providers/settings_provider.dart';
import 'providers/workout_provider.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
        ChangeNotifierProxyProvider<SettingsProvider, WorkoutProvider>(
          create: (_) => WorkoutProvider(prefs),
          update: (_, settings, workout) =>
              workout!..updateDemographics(weight: settings.userWeightKg),
        ),
      ],
      child: const BeaverGymTrackerApp(),
    ),
  );
}

class BeaverGymTrackerApp extends StatelessWidget {
  const BeaverGymTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            return MaterialApp(
              title: 'Beaver Gym Tracker',
              theme: AppTheme.getLight(
                settings.currentTheme == AppThemeMode.dynamic ? lightDynamic : null,
              ),
              darkTheme: AppTheme.getDark(
                settings.currentTheme == AppThemeMode.dynamic ? darkDynamic : null,
                settings.currentTheme,
              ),
              themeMode: AppTheme.getThemeMode(settings.currentTheme),
              home: const HomeScaffold(),
            );
          },
        );
      },
    );
  }
}

class HomeScaffold extends StatefulWidget {
  const HomeScaffold({super.key});

  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    WorkoutScreen(),
    HistoryScreen(),
    StatsScreen(),
    SettingsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Listen for requests to jump to history
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<WorkoutProvider>(context, listen: false);
      provider.addListener(() {
        if (provider.highlightedWorkoutId != null && _selectedIndex != 1) {
          setState(() {
            _selectedIndex = 1;
          });
        }
      });
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beaver Tracker'),
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Workout',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        // When in Amoled mode, we might want to manually set selected colors or rely on theme
        // The theme handles backgroundColor, but selectedItemColor is explicit in previous code
        // Let's rely on Theme where possible, but here we previously hardcoded.
        // I will use primary color from context which updates with theme.
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Needed for 4+ items if not handled by style
      ),
    );
  }
}
