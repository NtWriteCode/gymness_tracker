import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import '../models/workout.dart';
import '../models/location.dart';

class WorkoutProvider with ChangeNotifier {
  final SharedPreferences _prefs;
  static const String _workoutsKey = 'workout_history';
  static const String _activeWorkoutKey = 'active_workout';
  static const String _locationsKey = 'saved_locations';

  Workout? _activeWorkout;
  List<Workout> _history = [];
  List<SavedLocation> _locations = [];

  WorkoutProvider(this._prefs) {
    _loadData();
  }

  Workout? get activeWorkout => _activeWorkout;
  List<Workout> get history => _history;
  List<SavedLocation> get locations => _locations;

  void _loadData() {
    // Load history
    final historyJson = _prefs.getStringList(_workoutsKey) ?? [];
    _history = historyJson
        .map((j) => Workout.fromJson(jsonDecode(j)))
        .toList();

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

    notifyListeners();
  }

  Future<void> startWorkout(WorkoutType type) async {
    final newWorkout = Workout(
      id: const Uuid().v4(),
      type: type,
      startDateTime: DateTime.now(),
    );
    _activeWorkout = newWorkout;
    await _saveActiveWorkout();
    notifyListeners();
  }

  Future<void> updateActiveWorkout(Workout updated) async {
    _activeWorkout = updated;
    await _saveActiveWorkout();
    notifyListeners();
  }

  Future<void> finishWorkout() async {
    if (_activeWorkout == null) return;
    
    final finishedWorkout = _activeWorkout!.copyWith(
      isFinished: true,
      endDateTime: _activeWorkout!.endDateTime ?? DateTime.now(),
    );
    
    _history.add(finishedWorkout);
    _activeWorkout = null;
    
    await _prefs.remove(_activeWorkoutKey);
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
    final historyJson = _history.map((w) => jsonEncode(w.toJson())).toList();
    await _prefs.setStringList(_workoutsKey, historyJson);
  }

  Future<void> _saveLocations() async {
    final locationsJson = _locations.map((l) => jsonEncode(l.toJson())).toList();
    await _prefs.setStringList(_locationsKey, locationsJson);
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
