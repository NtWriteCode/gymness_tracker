import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import '../models/workout.dart';
import '../models/location.dart';
import '../models/exercise.dart';
import '../models/workout_template.dart';
import '../utils/calorie_calculator.dart';

class WorkoutProvider with ChangeNotifier {
  final SharedPreferences _prefs;
  static const String _workoutsKey = 'workout_history';
  static const String _activeWorkoutKey = 'active_workout';
  static const String _locationsKey = 'saved_locations';
  static const String _exercisesKey = 'exercises';
  static const String _exerciseNamesKey = 'exercise_names';
  static const String _achievementsKey = 'earned_achievements';
  static const String _templatesKey = 'workout_templates';

  Workout? _activeWorkout;
  List<Workout> _history = [];
  List<SavedLocation> _locations = [];
  final Map<String, Exercise> _exercises = {}; // All exercises by ID
  List<WorkoutTemplate> _templates = [];
  Set<String> _exerciseNames = {}; // For autocomplete
  double _userWeightKg = 75.0;
  int _userAge = 30;
  double _userHeightCm = 175.0;
  String _userSex = 'male';
  Map<String, DateTime> _earnedAchievements = {};
  String? _highlightedWorkoutId;
  int _weightUpdateCount = 0;
  int _manualCalorieOverrideCount = 0;

  WorkoutProvider(this._prefs) {
    _loadData();
  }

  Workout? get activeWorkout => _activeWorkout;
  List<Workout> get history => _history;
  List<SavedLocation> get locations => _locations;
  List<String> get exerciseNames => _exerciseNames.toList()..sort();
  List<WorkoutTemplate> get templates => _templates;

  Map<String, DateTime> get earnedAchievements => _earnedAchievements;
  String? get highlightedWorkoutId => _highlightedWorkoutId;

  Future<void> updateDemographics({double? weight, int? age, double? height, String? sex}) async {
    bool changed = false;
    if (weight != null && _userWeightKg != weight) {
      _userWeightKg = weight;
      _weightUpdateCount++;
      _prefs.setInt('weight_update_count', _weightUpdateCount);
      changed = true;
    }
    if (age != null && _userAge != age) {
      _userAge = age;
      changed = true;
    }
    if (height != null && _userHeightCm != height) {
      _userHeightCm = height;
      changed = true;
    }
    if (sex != null && _userSex != sex) {
      _userSex = sex;
      changed = true;
    }

    if (changed) {
      if (weight != null) await _prefs.setDouble('user_weight', weight);
      if (age != null) await _prefs.setInt('user_age', age);
      if (height != null) await _prefs.setDouble('user_height', height);
      if (sex != null) await _prefs.setString('user_sex', sex);

      _recalculateCaloriesIfNeeded();
      checkAchievements();
      notifyListeners();
    }
  }

  void updateHighlight(String? workoutId) {
    _highlightedWorkoutId = workoutId;
    notifyListeners();
  }

  void updateRPE(int rpe) {
    if (_activeWorkout == null || _activeWorkout!.rpe == rpe) return;
    _activeWorkout = _activeWorkout!.copyWith(rpe: rpe);
    _recalculateCaloriesIfNeeded();
    _saveActiveWorkout();
    notifyListeners();
  }
  
  void incrementManualCalorieCount() {
    _manualCalorieOverrideCount++;
    _prefs.setInt('manual_calorie_count', _manualCalorieOverrideCount);
    checkAchievements();
    notifyListeners();
  }
  
  // Get exercises for active workout
  List<Exercise> get activeWorkoutExercises {
    if (_activeWorkout == null) return [];
    return _activeWorkout!.exerciseIds
        .map((id) => _exercises[id])
        .whereType<Exercise>()
        .toList();
  }

  void _loadData() {
    // Load history
    final historyJson = _prefs.getStringList(_workoutsKey) ?? [];
    _history = historyJson
        .map((j) => Workout.fromJson(jsonDecode(j)))
        .toList();
    _history.sort((a, b) => b.startDateTime.compareTo(a.startDateTime));

    // Load active workout
    final activeJson = _prefs.getString(_activeWorkoutKey);
    if (activeJson != null) {
      _activeWorkout = Workout.fromJson(jsonDecode(activeJson));
    }

    // Load locations
    final locationsJson = _prefs.getStringList(_locationsKey) ?? [];
    _locations = locationsJson
        .map((j) => SavedLocation.fromJson(jsonDecode(j)))
        .toList();

    // Load exercises
    final exercisesJson = _prefs.getStringList(_exercisesKey) ?? [];
    for (var json in exercisesJson) {
      final exercise = Exercise.fromJson(jsonDecode(json));
      _exercises[exercise.id] = exercise;
    }

    // Load exercise names
    final names = _prefs.getStringList(_exerciseNamesKey) ?? [];
    _exerciseNames = Set<String>.from(names);

    // Load achievements
    final achJson = _prefs.getString(_achievementsKey);
    if (achJson != null) {
      final Map<String, dynamic> decoded = jsonDecode(achJson);
      _earnedAchievements = decoded.map((key, value) => MapEntry(key, DateTime.parse(value)));
    }

    // Load templates
    final templatesJson = _prefs.getStringList(_templatesKey) ?? [];
    _templates = templatesJson
        .map((j) => WorkoutTemplate.fromJson(jsonDecode(j)))
        .toList();

    // Load metadata counts
    _weightUpdateCount = _prefs.getInt('weight_update_count') ?? 0;
    _manualCalorieOverrideCount = _prefs.getInt('manual_calorie_count') ?? 0;
    
    // Load demographics (sync with SettingsProvider keys)
    _userWeightKg = _prefs.getDouble('user_weight') ?? 75.0;
    _userAge = _prefs.getInt('user_age') ?? 30;
    _userHeightCm = _prefs.getDouble('user_height') ?? 175.0;
    _userSex = _prefs.getString('user_sex') ?? 'male';

    checkAchievements(); // Initial scan
    notifyListeners();
  }

  Future<void> _saveTemplates() async {
    final templatesJson = _templates.map((t) => jsonEncode(t.toJson())).toList();
    await _prefs.setStringList(_templatesKey, templatesJson);
  }

  Future<void> startWorkout() async {
    final newWorkout = Workout(
      id: const Uuid().v4(),
      startDateTime: DateTime.now(),
    );
    _activeWorkout = newWorkout;
    await _saveActiveWorkout();
    notifyListeners();
  }

  Future<void> startWorkoutFromTemplate(WorkoutTemplate template) async {
    final List<String> newExerciseIds = [];
    
    for (var templateExercise in template.exercises) {
      // Create a fresh copy of the exercise with a new ID for this specific workout instance
      final newExercise = templateExercise.copyWith(id: const Uuid().v4());
      _exercises[newExercise.id] = newExercise;
      newExerciseIds.add(newExercise.id);
    }
    
    final newWorkout = Workout(
      id: const Uuid().v4(),
      startDateTime: DateTime.now(),
      exerciseIds: newExerciseIds,
      customTitle: template.name, // Pre-fill title with template name
    );
    
    _activeWorkout = newWorkout;
    _recalculateCaloriesIfNeeded();
    await _saveExercises();
    await _saveActiveWorkout();
    notifyListeners();
  }

  Future<void> updateActiveWorkout(Workout updated) async {
    _activeWorkout = updated;
    _recalculateCaloriesIfNeeded();
    await _saveActiveWorkout();
    notifyListeners();
  }

  Future<void> addExerciseToWorkout(Exercise exercise) async {
    if (_activeWorkout == null) return;
    
    _exercises[exercise.id] = exercise;
    _exerciseNames.add(exercise.name);
    
    final updatedExerciseIds = List<String>.from(_activeWorkout!.exerciseIds)
      ..add(exercise.id);
    
    _activeWorkout = _activeWorkout!.copyWith(exerciseIds: updatedExerciseIds);
    
    // Recalculate calories if not manually set
    _recalculateCaloriesIfNeeded();
    
    await _saveExercises();
    await _saveExerciseNames();
    await _saveActiveWorkout();
    notifyListeners();
  }

  Future<void> updateExercise(Exercise updated) async {
    _exercises[updated.id] = updated;
    _exerciseNames.add(updated.name);
    
    // Recalculate calories if not manually set (for active workout)
    _recalculateCaloriesIfNeeded();
    
    await _saveExercises();
    await _saveExerciseNames();
    await _saveActiveWorkout();
    notifyListeners();
  }

  Future<void> removeExerciseFromWorkout(String exerciseId) async {
    if (_activeWorkout == null) return;
    
    final updatedExerciseIds = List<String>.from(_activeWorkout!.exerciseIds)
      ..remove(exerciseId);
    
    _activeWorkout = _activeWorkout!.copyWith(exerciseIds: updatedExerciseIds);
    
    // Recalculate calories if not manually set
    _recalculateCaloriesIfNeeded();
    
    await _saveActiveWorkout();
    notifyListeners();
  }

  /// Save an exercise to the global store without linking to active workout
  Future<void> saveExercise(Exercise exercise) async {
    _exercises[exercise.id] = exercise;
    _exerciseNames.add(exercise.name);
    
    await _saveExercises();
    await _saveExerciseNames();
    notifyListeners();
  }

  Future<List<String>> finishWorkout() async {
    if (_activeWorkout == null) return [];
    
    final finishedWorkout = _activeWorkout!.copyWith(
      isFinished: true,
      endDateTime: _activeWorkout!.endDateTime ?? DateTime.now(),
    );
    
    _history.add(finishedWorkout);
    _activeWorkout = null;
    
    await _prefs.remove(_activeWorkoutKey);
    await _saveHistory();

    final preAchievements = Set<String>.from(_earnedAchievements.keys);
    await checkAchievements();
    final postAchievements = Set<String>.from(_earnedAchievements.keys);

    final newIds = postAchievements.difference(preAchievements).toList();
    
    notifyListeners();
    return newIds;
  }

  Future<void> saveAsTemplate(Workout workout, String name) async {
    final workoutExercises = workout.exerciseIds
        .map((id) => _exercises[id])
        .whereType<Exercise>()
        .toList();
        
    // Deep copy exercises for the template
    final templateExercises = workoutExercises.map((e) => e.copyWith(id: const Uuid().v4())).toList();
    
    final newTemplate = WorkoutTemplate(
      id: const Uuid().v4(),
      name: name,
      exercises: templateExercises,
    );
    
    _templates.add(newTemplate);
    await _saveTemplates();
    await checkAchievements();
    notifyListeners();
  }

  Future<void> deleteTemplate(String templateId) async {
    _templates.removeWhere((t) => t.id == templateId);
    await _saveTemplates();
    await checkAchievements();
    notifyListeners();
  }

  Future<void> cancelWorkout() async {
    if (_activeWorkout == null) return;
    
    _activeWorkout = null;
    await _prefs.remove(_activeWorkoutKey);
    notifyListeners();
  }

  void jumpToWorkout(String workoutId) {
    _highlightedWorkoutId = workoutId;
    notifyListeners();
  }

  void clearHighlight() {
    _highlightedWorkoutId = null;
    notifyListeners();
  }

  /// FOR DEBUGGING: Generates 20 random workouts in the current year
  Future<void> debugGenerateRandomHistory() async {
    final rand = Random();
    final names = [
      'Bench Press', 'Squat', 'Deadlift', 'Pull-up', 'Push-up', 
      'Overhead Press', 'Barbell Row', 'Lunges', 'Plank', 'Bicep Curl',
      'Lateral Raise', 'Leg Extension', 'Tricep Extension', 'Skullcrushers'
    ];
    
    final now = DateTime.now();
    
    // Generate 25 workouts over the last 6 months
    for (int i = 0; i < 25; i++) {
        // Spread back in time
        final daysAgo = i * 7 + rand.nextInt(3); // Rough weekly rhythm
        final start = now.subtract(Duration(days: daysAgo)).subtract(Duration(hours: rand.nextInt(5)));
        final end = start.add(Duration(minutes: 45 + rand.nextInt(60)));
        
        List<String> exerciseIds = [];
        final numExercises = 4 + rand.nextInt(4);
        
        for (int j = 0; j < numExercises; j++) {
            final setsCount = 3 + rand.nextInt(3);
            final reps = 8 + rand.nextInt(8);
            final weight = (5 + rand.nextInt(25) * 5).toDouble();
            final exercise = Exercise(
                id: const Uuid().v4(),
                name: names[rand.nextInt(names.length)],
                sets: List.generate(setsCount, (_) => ExerciseSet(reps: reps, weightKg: weight)),
            );
            _exercises[exercise.id] = exercise;
            _exerciseNames.add(exercise.name);
            exerciseIds.add(exercise.id);
        }
        
        final workout = Workout(
            id: const Uuid().v4(),
            startDateTime: start,
            endDateTime: end,
            exerciseIds: exerciseIds,
            isFinished: true,
            customTitle: rand.nextInt(5) == 0 ? 'Debug Session ${25-i}' : null,
        );
        
        _history.add(recalculateWorkoutCalories(workout));
    }
    
    await _saveHistory();
    await _saveExercises();
    await _saveExerciseNames();
    await checkAchievements();
    notifyListeners();
  }

  Future<void> clearAllHistory() async {
    _history = [];
    _exercises.clear();
    _exerciseNames.clear();
    _earnedAchievements.clear();
    _weightUpdateCount = 0;
    _manualCalorieOverrideCount = 0;
    
    await _prefs.remove(_workoutsKey);
    await _prefs.remove(_exercisesKey);
    await _prefs.remove(_exerciseNamesKey);
    await _prefs.remove(_achievementsKey);
    await _prefs.remove('weight_update_count');
    await _prefs.remove('manual_calorie_count');
    
    await checkAchievements();
    notifyListeners();
  }

  Exercise? getExerciseById(String id) {
    return _exercises[id];
  }

  double getWorkoutVolume(Workout workout) {
    double totalVolume = 0;
    for (final id in workout.exerciseIds) {
      final exercise = _exercises[id];
      if (exercise != null) {
        totalVolume += exercise.totalWeightLifted;
      }
    }
    return totalVolume;
  }

  static String getWeightEmoji(String name) {
    switch (name) {
      case 'Pineapples': return '🍍';
      case 'Basset Hounds': return '🐶';
      case 'Giant Pandas': return '🐼';
      case 'Refrigerators': return '🧊';
      case 'Vespas': return '🛵';
      case 'Grizzly Bears': return '🐻';
      case 'Grand Pianos': return '🎹';
      case 'Holstein Cows': return '🐄';
      case 'Ford Mustangs': return '🏎️';
      case 'Great White Sharks': return '🦈';
      case 'Hippos': return '🦛';
      case 'African Elephants': return '🐘';
      case 'T-Rexes': return '🦖';
      case 'School Buses': return '🚌';
      case 'Boeing 737s': return '✈️';
      default: return '💪';
    }
  }

  Map<String, dynamic> getFunnyWeightEquivalent(double volume) {
    if (volume <= 0) return {'name': 'a Feather', 'count': 0};

    final List<Map<String, dynamic>> equivalents = [
      {'name': 'Pineapples', 'weight': 1.0, 'min': 0, 'max': 50},
      {'name': 'Basset Hounds', 'weight': 25.0, 'min': 20, 'max': 100},
      {'name': 'Giant Pandas', 'weight': 100.0, 'min': 80, 'max': 300},
      {'name': 'Refrigerators', 'weight': 113.0, 'min': 100, 'max': 500},
      {'name': 'Vespas', 'weight': 115.0, 'min': 110, 'max': 600},
      {'name': 'Grizzly Bears', 'weight': 270.0, 'min': 200, 'max': 1500},
      {'name': 'Grand Pianos', 'weight': 400.0, 'min': 350, 'max': 2000},
      {'name': 'Holstein Cows', 'weight': 700.0, 'min': 600, 'max': 4000},
      {'name': 'Ford Mustangs', 'weight': 1700.0, 'min': 1500, 'max': 10000},
      {'name': 'Great White Sharks', 'weight': 1100.0, 'min': 1000, 'max': 8000},
      {'name': 'Hippos', 'weight': 2000.0, 'min': 1500, 'max': 15000},
      {'name': 'African Elephants', 'weight': 6000.0, 'min': 5000, 'max': 50000},
      {'name': 'T-Rexes', 'weight': 8000.0, 'min': 7000, 'max': 80000},
      {'name': 'School Buses', 'weight': 12000.0, 'min': 10000, 'max': 150000},
      {'name': 'Boeing 737s', 'weight': 41000.0, 'min': 35000, 'max': 1000000},
    ];

    // Filter equivalents that fit the volume range
    final possible = equivalents.where((e) => volume >= e['min']).toList();
    
    // Pick the most appropriate one (usually the one where count is between 1 and 10)
    // or just the last one that fits if it's huge.
    Map<String, dynamic> best = possible.last;
    for (final e in possible) {
      final count = volume / e['weight'];
      if (count >= 0.8 && count <= 5) {
        best = e;
        break;
      }
    }

    final count = volume / best['weight'];
    return {
      'name': best['name'],
      'count': count < 1.0 ? count.toStringAsFixed(1) : count.toStringAsFixed(0),
      'weightPerItem': best['weight'],
    };
  }

  /// Recalculates calories for a specific workout if not manually set.
  /// This is useful when editing historical workouts.
  Workout recalculateWorkoutCalories(Workout workout) {
    if (workout.isCaloriesManuallySet) return workout;

    final workoutExercises = workout.exerciseIds
        .map((id) => _exercises[id])
        .whereType<Exercise>()
        .toList();

    final newCalories = CalorieCalculator.calculateTotalCalories(
      workoutExercises, 
      _userWeightKg,
      age: _userAge,
      heightCm: _userHeightCm,
      sex: _userSex,
      rpe: workout.rpe,
    );
    return workout.copyWith(estimatedCalories: newCalories);
  }

  void _recalculateCaloriesIfNeeded() {
    if (_activeWorkout == null || _activeWorkout!.isCaloriesManuallySet) return;
    _activeWorkout = recalculateWorkoutCalories(_activeWorkout!);
  }

  Future<void> updateWorkoutInHistory(Workout updated) async {
    final index = _history.indexWhere((w) => w.id == updated.id);
    if (index != -1) {
      _history[index] = recalculateWorkoutCalories(updated);
      await _saveHistory();
      notifyListeners();
    }
  }

  Future<void> deleteWorkout(String workoutId) async {
    _history.removeWhere((w) => w.id == workoutId);
    await _saveHistory();
    notifyListeners();
  }

  Future<void> addLocation(String name, {double? lat, double? lng}) async {
    final newLoc = SavedLocation(
      id: const Uuid().v4(),
      name: name,
      latitude: lat,
      longitude: lng,
    );
    _locations.add(newLoc);
    await _saveLocations();
    notifyListeners();
  }

  Future<void> _saveActiveWorkout() async {
    if (_activeWorkout != null) {
      await _prefs.setString(_activeWorkoutKey, jsonEncode(_activeWorkout!.toJson()));
    }
  }

  Future<void> _saveHistory() async {
    _history.sort((a, b) => b.startDateTime.compareTo(a.startDateTime));
    final historyJson = _history.map((w) => jsonEncode(w.toJson())).toList();
    await _prefs.setStringList(_workoutsKey, historyJson);
  }

  Future<void> _saveLocations() async {
    final locationsJson = _locations.map((l) => jsonEncode(l.toJson())).toList();
    await _prefs.setStringList(_locationsKey, locationsJson);
  }

  Future<void> _saveExercises() async {
    final exercisesJson = _exercises.values.map((e) => jsonEncode(e.toJson())).toList();
    await _prefs.setStringList(_exercisesKey, exercisesJson);
  }

  Future<void> _saveExerciseNames() async {
    await _prefs.setStringList(_exerciseNamesKey, _exerciseNames.toList());
  }

  Future<void> _saveAchievements() async {
    final Map<String, String> toSave = _earnedAchievements.map((key, value) => MapEntry(key, value.toIso8601String()));
    await _prefs.setString(_achievementsKey, jsonEncode(toSave));
  }

  Future<void> checkAchievements() async {
    final Map<String, DateTime> newEarned = {};
    
    void earn(String id, DateTime date) {
      if (!newEarned.containsKey(id)) {
        newEarned[id] = date;
      }
    }

    // Chronological history for sequential checks
    final cronHistory = List<Workout>.from(_history)..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    
    Set<String?> uniqueLocations = {};
    Map<String, int> workoutsPerMonth = {};
    Map<DateTime, double> dailyVolumes = {};
    
    Workout? prevWorkout;
    int gapStreak = 0;
    int maxGapStreak = 0;

    int rpe3OrLowerCount = 0;
    int rpe5To7Count = 0;
    int rpe10Count = 0;
    Set<int> seenRpes = {};

    // Daily volume grouping and other per-workout stats
    for (final w in cronHistory) {
      final date = w.startDateTime;
      final dateOnly = DateTime(date.year, date.month, date.day);
      dailyVolumes[dateOnly] = (dailyVolumes[dateOnly] ?? 0) + getWorkoutVolume(w);
    }

    final sortedDays = dailyVolumes.keys.toList()..sort();
    
    // GAP STREAK CALCULATION (no more than 3 days gap)
    if (sortedDays.isNotEmpty) {
      gapStreak = 1;
      maxGapStreak = 1;
      for (int i = 1; i < sortedDays.length; i++) {
        final diff = sortedDays[i].difference(sortedDays[i-1]).inDays;
        if (diff <= 3) {
          gapStreak++;
        } else {
          gapStreak = 1;
        }
        if (gapStreak > maxGapStreak) maxGapStreak = gapStreak;
      }
    }
    
    for (var i = 0; i < cronHistory.length; i++) {
      final workout = cronHistory[i];
      final date = workout.startDateTime;
      
      final volume = getWorkoutVolume(workout);
      if (workout.locationId != null) uniqueLocations.add(workout.locationId);
      
      final monthKey = "${date.year}-${date.month}";
      workoutsPerMonth[monthKey] = (workoutsPerMonth[monthKey] ?? 0) + 1;

      // Basics
      earn('first_step', date);
      if (date.day == 1) {
        earn('new_leaf', date);
      }

      // Tiered Milestones (Wholesome)
      if (i + 1 >= 25) earn('silver_anniversary', date);
      if (i + 1 >= 50) earn('gold_anniversary', date);
      if (i + 1 >= 100) earn('centurion', date);

      // Power Tiers
      if (volume >= 1100) earn('shark_wrangler', date);
      if (volume >= 5000) earn('gravitys_enemy', date);
      if (volume >= 15000) earn('blue_whale', date);
      
      int heavySets = 0;
      bool allUnder10 = true;
      for (final exId in workout.exerciseIds) {
        final ex = _exercises[exId];
        if (ex != null) {
          for (final set in ex.sets) {
            if (set.weightKg >= 100) earn('the_100_club', date);
            if (set.weightKg >= 20) heavySets += 1;
            if (set.weightKg >= 10) allUnder10 = false;
          }
        }
      }
      if (heavySets >= 10) earn('plate_collector', date);
      if (allUnder10 && workout.exerciseIds.isNotEmpty) earn('form_focus', date);

      // Time based
      if (date.hour < 7) earn('early_bird', date);
      if (workout.endDateTime != null) {
        if (workout.endDateTime!.hour >= 22) earn('night_owl', date);
        if (workout.endDateTime!.hour >= 23 && volume >= 2000) earn('heavy_sleeper', date);
      }

      // Funny
      final duration = workout.endDateTime?.difference(workout.startDateTime).inMinutes ?? 0;
      if (workout.exerciseIds.length >= 3 && duration > 0 && duration < 20) earn('the_quickie', date);
      if (duration >= 120) earn('is_this_a_marathon', date);
      if (volume > 0 && volume % 100 == 0) earn('mathematical', date);

      // Intensity Logic
      seenRpes.add(workout.rpe);
      if (workout.rpe <= 3) {
        rpe3OrLowerCount++;
        if (rpe3OrLowerCount >= 5) earn('taking_it_easy', date);
      } else if (workout.rpe >= 5 && workout.rpe <= 7) {
        rpe5To7Count++;
        if (rpe5To7Count >= 10) earn('the_daily_grind', date);
      } else if (workout.rpe == 10) {
        rpe10Count++;
        earn('beast_mode_on', date);
        if (rpe10Count >= 10) earn('absolute_madman', date);
      }

      if (seenRpes.contains(1) && seenRpes.contains(5) && seenRpes.contains(10)) {
        earn('perfect_balance', date);
      }

      // Secret Logic
      if (volume >= _userWeightKg * 10) earn('beast_mode', date);
      if (prevWorkout != null && getWorkoutVolume(prevWorkout) == volume && volume > 0) {
        earn('lightweight_baby', date);
      }
      
      String volStr = volume.toInt().toString();
      // Devils Lift: Only 6s
      if (volStr.isNotEmpty && volStr.runes.every((r) => String.fromCharCode(r) == '6')) earn('devils_lift', date);
      // Lucky Lift: Only 7s
      if (volStr.isNotEmpty && volStr.runes.every((r) => String.fromCharCode(r) == '7')) earn('lucky_lift', date);
      
      // The Answer (42, 4242, 424242...)
      if (volStr.length >= 2 && volStr.length % 2 == 0) {
         bool all42 = true;
         for (int j=0; j < volStr.length; j+=2) {
            if (volStr.substring(j, j+2) != '42') {
              all42 = false; break;
            }
         }
         if (all42) earn('the_answer', date);
      }

      if (duration >= 45 && volume == 0) earn('ghost', date);
      if (date.hour >= 2 && date.hour < 4) earn('insomniac', date);

      // Progressive Overload & Double Time
      if (prevWorkout != null) {
        final prevVol = getWorkoutVolume(prevWorkout);
        final prevDuration = prevWorkout.endDateTime?.difference(prevWorkout.startDateTime).inMinutes ?? 0;
        
        if (prevVol > 0) {
          final diff = (volume - prevVol) / prevVol;
          if (diff >= 0.01 && diff <= 0.05) earn('slow_and_steady', date);
          
          // Double Time: More volume, less time
          if (volume > prevVol && duration < prevDuration && duration > 0 && prevDuration > 0) {
            earn('double_time', date);
          }
        }
        
        // Steady Gains (5 in a row)
        if (i >= 4) {
           bool inc = true;
           for (int j = 0; j < 4; j++) {
             final vPresent = getWorkoutVolume(cronHistory[i-j]);
             final vPrev = getWorkoutVolume(cronHistory[i-j-1]);
             if (vPresent <= vPrev) { inc = false; break; }
           }
           if (inc) earn('steady_gains', date);
        }
      }

      // Time patterns (Lunch Break, After Hours)
      if (workout.endDateTime != null) {
        final start = workout.startDateTime;
        final end = workout.endDateTime!;
        
        // Lunch Break: Whole workout between 12:00 and 13:30
        if (start.hour >= 12 && (end.hour < 13 || (end.hour == 13 && end.minute <= 30))) {
          earn('lunch_break', date);
        }
        
        // After Hours: Spans across midnight
        if (start.day != end.day) {
          earn('after_hours', date);
        }
      }

      // Efficiency & Power Hour
      if (volume >= 3000 && duration > 0 && duration <= 60) earn('power_hour', date);
      if (workout.exerciseIds.length >= 5 && duration > 0 && duration < 30) earn('efficiency_expert', date);
      if (duration >= 12 * 60) earn('hibernation', date);

      prevWorkout = workout;
    }

    // Clockwork: 3 consecutive near-identical durations
    for (int i = 2; i < cronHistory.length; i++) {
      final d1 = cronHistory[i].endDateTime?.difference(cronHistory[i].startDateTime).inMinutes ?? 0;
      final d2 = cronHistory[i-1].endDateTime?.difference(cronHistory[i-1].startDateTime).inMinutes ?? 0;
      final d3 = cronHistory[i-2].endDateTime?.difference(cronHistory[i-2].startDateTime).inMinutes ?? 0;
      
      if (d1 > 0 && d2 > 0 && d3 > 0) {
        if ((d1 - d2).abs() <= 2 && (d2 - d3).abs() <= 2 && (d1 - d3).abs() <= 2) {
          earn('clockwork', cronHistory[i].startDateTime);
        }
      }
    }

    // Lifetime Powers & Durations
    double runningVol = 0;
    double runningDistance = 0;
    int runningDurationMinutes = 0;
    int legWorkoutsCount = 0;
    final legKeywords = ['leg', 'láb', 'squat', 'guggolás', 'quad', 'hamstring', 'vádli', 'calf', 'lunges', 'kitörés'];

    for (var w in cronHistory) {
       runningVol += getWorkoutVolume(w);
       final d = w.endDateTime?.difference(w.startDateTime).inMinutes ?? 0;
       runningDurationMinutes += d;
       
       int cardioCount = 0;
       int gymCount = 0;
       bool isLegDay = false;
       double sessionDistance = 0;

       for (final exId in w.exerciseIds) {
         final ex = _exercises[exId];
         if (ex != null) {
           if (ex.type == ExerciseType.cardio) {
             cardioCount++;
             runningDistance += ex.totalDistance;
             sessionDistance += ex.totalDistance;
             
             // Check individual cardio sets
             for (final set in ex.sets) {
               if (set.durationMinutes > 60) earn('forest_gump', w.startDateTime);
               if (set.distanceKm >= 5 && set.durationMinutes <= 30 && set.durationMinutes > 0) {
                 earn('speed_demon', w.startDateTime);
               }
             }
           } else {
             gymCount++;
           }

           final lowerName = ex.name.toLowerCase();
           if (legKeywords.any((k) => lowerName.contains(k))) {
             isLegDay = true;
           }
         }
       }

       if (cardioCount > 0 && gymCount == 0) earn('pure_hearts', w.startDateTime);
       if (cardioCount > 0 && gymCount > 0) earn('the_hybrid', w.startDateTime);
       if (sessionDistance >= 42.2) earn('marathon_man', w.startDateTime);

       if (isLegDay) {
         legWorkoutsCount++;
         if (legWorkoutsCount >= 1) earn('friends_dont_let_friends', w.startDateTime);
         if (legWorkoutsCount >= 10) earn('chicken_leg_cure', w.startDateTime);
       }

       if (runningDistance >= 50) earn('road_warrior', w.startDateTime);
       if (runningDistance >= 500) earn('cross_country', w.startDateTime);
       
       // Volume
       if (runningVol >= 10000) earn('human_forklift', w.startDateTime);
       if (runningVol >= 50000) earn('moving_day', w.startDateTime);
       if (runningVol >= 100000) earn('the_atlas', w.startDateTime);
       if (runningVol >= 500000) earn('space_elevator', w.startDateTime);
       if (runningVol >= 1000000) earn('small_moon', w.startDateTime);
       
       // Duration Milestones
       if (runningDurationMinutes >= 8 * 60) earn('shift_work', w.startDateTime);
       if (runningDurationMinutes >= 24 * 60) earn('round_the_clock', w.startDateTime);
       if (runningDurationMinutes >= 100 * 60) earn('the_century_club', w.startDateTime);
       if (runningDurationMinutes >= 500 * 60) earn('deep_space', w.startDateTime);
    }

    // Metadata Achievement (The Sculptor, Correctionist, etc)
    if (_weightUpdateCount >= 10) earn('the_sculptor', DateTime.now());
    if (_manualCalorieOverrideCount >= 5) earn('correctionist', DateTime.now());
    for (var w in cronHistory) {
       if (w.customTitle != null && w.customTitle!.isNotEmpty) {
          earn('named_and_shamed', w.startDateTime);
       }
    }

    // Globetrotter
    Set<String?> seenLocs = {};
    for (var w in cronHistory) {
      if (w.locationId != null) seenLocs.add(w.locationId);
      if (seenLocs.length >= 3) earn('social_butterfly', w.startDateTime);
      if (seenLocs.length >= 10) earn('globetrotter', w.startDateTime);
    }

    // Monthly Logic
    workoutsPerMonth.forEach((key, count) {
      final parts = key.split('-');
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);

      if (count >= 20) {
        final monthWorkouts = cronHistory.where((w) => w.startDateTime.year == y && w.startDateTime.month == m).toList();
        if (monthWorkouts.length >= 20) {
          earn('monthly_master', monthWorkouts[19].startDateTime);
        }
      }

      int workoutsThisMonthCount = sortedDays.where((d) => d.year == y && d.month == m).length;
      if (workoutsThisMonthCount >= 26) {
         final targetDay = sortedDays.where((d) => d.year == y && d.month == m).elementAt(25);
         earn('monthly_legend', targetDay);
      }
    });

    // Gap Streaks
    int currentGapStreak = 1;
    for (int i = 1; i < sortedDays.length; i++) {
       final diff = sortedDays[i].difference(sortedDays[i-1]).inDays;
       if (diff <= 3) {
         currentGapStreak++;
       } else {
         currentGapStreak = 1;
       }

       if (currentGapStreak >= 3) earn('unstoppable', sortedDays[i]);
       if (currentGapStreak >= 10) earn('iron_will', sortedDays[i]);
       if (currentGapStreak >= 30) earn('immortal', sortedDays[i]);
    }

    // Multi-Workout patterns
    for (int i=1; i < sortedDays.length; i++) {
       if (sortedDays[i] == sortedDays[i-1]) earn('double_down', sortedDays[i]);
    }

    // Weekly patterns
    for (var day in sortedDays) {
       if (day.weekday == 6 && sortedDays.contains(day.add(const Duration(days: 1)))) {
          earn('weekend_warrior', day.add(const Duration(days: 1)));
       }
    }

    // Consistency King & Self Care Sunday
    int sunCount = 0;
    int dailyStreak = 0;
    for (int i = 0; i < sortedDays.length; i++) {
       if (i > 0 && sortedDays[i].difference(sortedDays[i-1]).inDays == 1) {
         dailyStreak++;
       } else {
         dailyStreak = 1;
       }
       if (dailyStreak >= 7) earn('consistency_king', sortedDays[i]);
       
       if (sortedDays[i].weekday == 7) {
          sunCount++;
          if (sunCount >= 4) {
             if (sortedDays.contains(sortedDays[i].subtract(const Duration(days: 7))) &&
                 sortedDays.contains(sortedDays[i].subtract(const Duration(days: 14))) &&
                 sortedDays.contains(sortedDays[i].subtract(const Duration(days: 21)))) {
                earn('self_care_sunday', sortedDays[i]);
             }
          }
       }
    }

    // Template Achievements
    if (_templates.isNotEmpty) earn('the_planner', DateTime.now());
    if (_templates.length >= 5) earn('architect_of_gains', DateTime.now());
    if (_templates.length >= 10) earn('grand_designer', DateTime.now());

    // Check if map changed
    bool changed = newEarned.length != _earnedAchievements.length;
    if (!changed) {
      for (var key in newEarned.keys) {
        if (newEarned[key] != _earnedAchievements[key]) {
          changed = true;
          break;
        }
      }
    }

    if (changed) {
      _earnedAchievements = newEarned;
      await _saveAchievements();
      notifyListeners();
    }
  }

  /// Checks and requests location permissions. Returns true if granted.
  Future<bool> checkAndRequestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Finds the closest saved location within the given radius (meters).
  Future<SavedLocation?> findAutoLocation(double radiusMeters) async {
    try {
      if (!await checkAndRequestLocationPermission()) return null;

      final position = await Geolocator.getCurrentPosition();
      
      SavedLocation? closest;
      double minDistance = double.infinity;

      for (var loc in _locations) {
        if (loc.latitude != null && loc.longitude != null) {
          double distance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            loc.latitude!,
            loc.longitude!,
          );
          
          if (distance <= radiusMeters && distance < minDistance) {
            minDistance = distance;
            closest = loc;
          }
        }
      }
      return closest;
    } catch (e) {
      return null;
    }
  }
}
