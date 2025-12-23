enum WorkoutType { gym, fitness }

class Workout {
  final String id;
  final WorkoutType type;
  String? locationId;
  DateTime startDateTime;
  DateTime? endDateTime;
  bool isFinished;

  Workout({
    required this.id,
    required this.type,
    this.locationId,
    required this.startDateTime,
    this.endDateTime,
    this.isFinished = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'locationId': locationId,
        'startDateTime': startDateTime.toIso8601String(),
        'endDateTime': endDateTime?.toIso8601String(),
        'isFinished': isFinished,
      };

  factory Workout.fromJson(Map<String, dynamic> json) => Workout(
        id: json['id'],
        type: WorkoutType.values[json['type']],
        locationId: json['locationId'],
        startDateTime: DateTime.parse(json['startDateTime']),
        endDateTime: json['endDateTime'] != null
            ? DateTime.parse(json['endDateTime'])
            : null,
        isFinished: json['isFinished'] ?? false,
      );

  Workout copyWith({
    String? locationId,
    DateTime? startDateTime,
    DateTime? endDateTime,
    bool? isFinished,
  }) {
    return Workout(
      id: id,
      type: type,
      locationId: locationId ?? this.locationId,
      startDateTime: startDateTime ?? this.startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      isFinished: isFinished ?? this.isFinished,
    );
  }
}
