import '../models/exercise.dart';

/// Calorie Calculator for Workout Exercises
/// 
/// This calculator estimates calories burned during strength training exercises
/// based on exercise parameters (sets, reps, weight, duration).
class CalorieCalculator {
  // MET values for different intensity levels
  static const double _metLight = 3.5;        // Bodyweight exercises
  static const double _metModerate = 5.0;     // Light weights (1-20kg)
  static const double _metVigorous = 6.0;     // Medium weights (21-50kg)
  static const double _metVeryVigorous = 8.0; // Heavy weights (50+kg)
  
  // Time estimates
  static const double _secondsPerRep = 3.5;   // Average time per repetition
  static const double _restBetweenSets = 60.0; // Rest time between sets (seconds)
  
  /// Calculate total estimated calories for a list of exercises
  static int calculateTotalCalories(
    List<Exercise> exercises, 
    double userWeightKg, {
    int age = 30,
    double heightCm = 175.0,
    String sex = 'male',
    int rpe = 5,
  }) {
    if (exercises.isEmpty) return 0;
    
    double totalCalories = 0.0;
    
    for (var exercise in exercises) {
      totalCalories += _calculateExerciseCalories(
        exercise, 
        userWeightKg, 
        age: age, 
        heightCm: heightCm, 
        sex: sex,
      );
    }

    // Apply RPE multiplier: RPE 5 is neutral (1.0)
    // Formula: 0.5 + (rpe / 10)
    // RPE 1 => 0.6x
    // RPE 5 => 1.0x
    // RPE 10 => 1.5x
    final multiplier = 0.5 + (rpe / 10.0);
    
    return (totalCalories * multiplier).round();
  }
  
  /// Calculate calories for a single exercise
  static double _calculateExerciseCalories(
    Exercise exercise, 
    double userWeightKg, {
    int age = 30,
    double heightCm = 175.0,
    String sex = 'male',
  }) {
    if (exercise.sets.isEmpty) return 0.0;

    // BMR using Mifflin-St Jeor Equation
    double bmr;
    if (sex.toLowerCase() == 'male') {
      bmr = (10 * userWeightKg) + (6.25 * heightCm) - (5 * age) + 5;
    } else if (sex.toLowerCase() == 'female') {
      bmr = (10 * userWeightKg) + (6.25 * heightCm) - (5 * age) - 161;
    } else {
      // Average for 'other'
      bmr = (10 * userWeightKg) + (6.25 * heightCm) - (5 * age) - 78;
    }

    // Calories burned per minute per MET = (BMR / 24 / 60) * MET
    // This is more accurate than the generic (3.5 * weight) / 200
    final caloriesPerMetMinute = bmr / (24 * 60);

    // If total duration is specified for the exercise, use that first
    if (exercise.durationMinutes > 0) {
      final avgWeight = exercise.sets.map((s) => s.weightKg).reduce((a, b) => a + b) / exercise.sets.length;
      final met = _getMETFromWeight(avgWeight);
      return met * caloriesPerMetMinute * exercise.durationMinutes;
    }
    
    double weightedMETSum = 0;

    for (int i = 0; i < exercise.sets.length; i++) {
      final set = exercise.sets[i];
      final setWorkTime = set.reps * _secondsPerRep;
      final setRestTime = (i < exercise.sets.length - 1) ? _restBetweenSets : 0.0;
      final setTotalTimeMinutes = (setWorkTime + setRestTime) / 60.0;
      
      final met = _getMETFromWeight(set.weightKg);
      weightedMETSum += met * setTotalTimeMinutes;
    }
    
    return weightedMETSum * caloriesPerMetMinute;
  }
  
  
  
  /// Determine MET value based on weight being lifted
  static double _getMETFromWeight(double weightKg) {
    if (weightKg == 0) return _metLight;
    if (weightKg <= 20) return _metModerate;
    if (weightKg <= 50) return _metVigorous;
    return _metVeryVigorous;
  }
}
