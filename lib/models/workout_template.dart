import 'exercise.dart';

class WorkoutTemplate {
  final String id;
  final String name;
  final List<Exercise> exercises;

  WorkoutTemplate({
    required this.id,
    required this.name,
    required this.exercises,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };
  }

  factory WorkoutTemplate.fromJson(Map<String, dynamic> json) {
    return WorkoutTemplate(
      id: json['id'],
      name: json['name'],
      exercises: (json['exercises'] as List)
          .map((e) => Exercise.fromJson(e))
          .toList(),
    );
  }

  WorkoutTemplate copyWith({
    String? id,
    String? name,
    List<Exercise>? exercises,
  }) {
    return WorkoutTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      exercises: exercises ?? this.exercises,
    );
  }
}
