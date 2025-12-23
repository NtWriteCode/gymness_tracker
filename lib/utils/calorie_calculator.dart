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
  static int calculateTotalCalories(List<Exercise> exercises, double userWeightKg) {
    if (exercises.isEmpty) return 0;
    
    double totalCalories = 0.0;
    
    for (var exercise in exercises) {
      totalCalories += _calculateExerciseCalories(exercise, userWeightKg);
    }
    
    return totalCalories.round();
  }
  
  /// Calculate calories for a single exercise
  static double _calculateExerciseCalories(Exercise exercise, double userWeightKg) {
    if (exercise.sets.isEmpty) return 0.0;

    // If total duration is specified for the exercise, use that first
    if (exercise.durationMinutes > 0) {
      // Find average weight used across all sets to determine an average MET
      final avgWeight = exercise.sets.map((s) => s.weightKg).reduce((a, b) => a + b) / exercise.sets.length;
      return _calculateDurationBasedCalories(
        exercise.durationMinutes,
        avgWeight,
        userWeightKg,
      );
    }
    
    // Otherwise calculate total calories by summing the work and rest time for each set
    double weightedMETSum = 0;
    final caloriesConstant = (3.5 * userWeightKg) / 200;

    for (int i = 0; i < exercise.sets.length; i++) {
      final set = exercise.sets[i];
      final setWorkTime = set.reps * _secondsPerRep;
      // No rest after the very last set of the exercise
      final setRestTime = (i < exercise.sets.length - 1) ? _restBetweenSets : 0.0;
      final setTotalTimeMinutes = (setWorkTime + setRestTime) / 60.0;
      
      final met = _getMETFromWeight(set.weightKg);
      weightedMETSum += met * setTotalTimeMinutes;
    }
    
    return weightedMETSum * caloriesConstant;
  }
  
  /// Calculate calories based on exercise duration
  static double _calculateDurationBasedCalories(
    int durationMinutes,
    double exerciseWeightKg,
    double userWeightKg,
  ) {
    final met = _getMETFromWeight(exerciseWeightKg);
    final caloriesPerMinute = (met * 3.5 * userWeightKg) / 200;
    return caloriesPerMinute * durationMinutes;
  }
  
  /// Determine MET value based on weight being lifted
  static double _getMETFromWeight(double weightKg) {
    if (weightKg == 0) return _metLight;
    if (weightKg <= 20) return _metModerate;
    if (weightKg <= 50) return _metVigorous;
    return _metVeryVigorous;
  }
}
