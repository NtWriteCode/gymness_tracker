enum ExerciseType { gym, cardio }

class ExerciseSet {
  int reps;
  double weightKg;
  int durationMinutes;
  double distanceKm;

  ExerciseSet({
    this.reps = 0,
    this.weightKg = 0.0,
    this.durationMinutes = 0,
    this.distanceKm = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'reps': reps,
        'weightKg': weightKg,
        'durationMinutes': durationMinutes,
        'distanceKm': distanceKm,
      };

  factory ExerciseSet.fromJson(Map<String, dynamic> json) => ExerciseSet(
        reps: json['reps'] ?? 0,
        weightKg: (json['weightKg'] ?? 0.0).toDouble(),
        durationMinutes: json['durationMinutes'] ?? 0,
        distanceKm: (json['distanceKm'] ?? 0.0).toDouble(),
      );

  ExerciseSet copyWith({
    int? reps,
    double? weightKg,
    int? durationMinutes,
    double? distanceKm,
  }) {
    return ExerciseSet(
      reps: reps ?? this.reps,
      weightKg: weightKg ?? this.weightKg,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }
}

class Exercise {
  final String id;
  final ExerciseType type;
  String name;
  final List<ExerciseSet> sets;
  bool isDoubleWeight;

  Exercise({
    required this.id,
    this.type = ExerciseType.gym,
    required this.name,
    required this.sets,
    this.isDoubleWeight = false,
  });

  double get totalWeightLifted => sets.fold(0.0, (sum, set) => sum + (set.reps * set.weightKg)) * (isDoubleWeight ? 2.0 : 1.0);
  double get totalDistance => sets.fold(0.0, (sum, set) => sum + set.distanceKm);
  
  // Convenience getters for backwards compatibility or single-set logic if needed
  int get reps => sets.isNotEmpty ? sets.first.reps : 0;
  int get setsCount => sets.length;
  double get weightKg => sets.isNotEmpty ? sets.first.weightKg : 0.0;
  int get durationMinutes => sets.fold(0, (sum, set) => sum + set.durationMinutes);

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'name': name,
        'sets': sets.map((s) => s.toJson()).toList(),
        'isDoubleWeight': isDoubleWeight,
      };

  factory Exercise.fromJson(Map<String, dynamic> json) {
    if (json['sets'] is List) {
      var setsJson = json['sets'] as List;
      return Exercise(
        id: json['id'],
        type: ExerciseType.values[json['type'] ?? 0],
        name: json['name'],
        sets: setsJson.map((s) => ExerciseSet.fromJson(s)).toList(),
        isDoubleWeight: json['isDoubleWeight'] ?? false,
      );
    } else {
      // Migrate old data structure
      final reps = json['reps'] ?? 0;
      final setsCount = json['sets'] ?? 0;
      final weight = (json['weightKg'] ?? 0.0).toDouble();
      final duration = json['durationMinutes'] ?? 0;
      
      return Exercise(
          id: json['id'],
          type: ExerciseType.gym,
          name: json['name'],
          sets: List.generate(
            setsCount,
            (_) => ExerciseSet(
              reps: reps,
              weightKg: weight,
              durationMinutes: duration ~/ (setsCount > 0 ? setsCount : 1),
            ),
          ));
    }
  }

  Exercise copyWith({
    String? id,
    String? name,
    List<ExerciseSet>? sets,
    ExerciseType? type,
    bool? isDoubleWeight,
  }) {
    return Exercise(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      sets: sets ?? this.sets.map((s) => s.copyWith()).toList(),
      isDoubleWeight: isDoubleWeight ?? this.isDoubleWeight,
    );
  }
}
