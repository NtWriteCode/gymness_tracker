class Workout {
  final String id;
  String? locationId;
  DateTime startDateTime;
  DateTime? endDateTime;
  bool isFinished;
  List<String> exerciseIds; // Store exercise IDs
  String? customTitle; // Optional custom title
  int? estimatedCalories; // Estimated calories burned
  bool isCaloriesManuallySet; // Whether user manually set calories
  int rpe; // Rate of Perceived Exertion (1-10)

  Workout({
    required this.id,
    this.locationId,
    required this.startDateTime,
    this.endDateTime,
    this.isFinished = false,
    List<String>? exerciseIds,
    this.customTitle,
    this.estimatedCalories,
    this.isCaloriesManuallySet = false,
    this.rpe = 5,
  }) : exerciseIds = exerciseIds ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'locationId': locationId,
        'startDateTime': startDateTime.toIso8601String(),
        'endDateTime': endDateTime?.toIso8601String(),
        'isFinished': isFinished,
        'exerciseIds': exerciseIds,
        'customTitle': customTitle,
        'estimatedCalories': estimatedCalories,
        'isCaloriesManuallySet': isCaloriesManuallySet,
        'rpe': rpe,
      };

  factory Workout.fromJson(Map<String, dynamic> json) => Workout(
        id: json['id'],
        locationId: json['locationId'],
        startDateTime: DateTime.parse(json['startDateTime']),
        endDateTime: json['endDateTime'] != null
            ? DateTime.parse(json['endDateTime'])
            : null,
        isFinished: json['isFinished'] ?? false,
        exerciseIds: json['exerciseIds'] != null
            ? List<String>.from(json['exerciseIds'])
            : [],
        customTitle: json['customTitle'],
        estimatedCalories: json['estimatedCalories'],
        isCaloriesManuallySet: json['isCaloriesManuallySet'] ?? false,
        rpe: json['rpe'] ?? 5,
      );

  Workout copyWith({
    String? locationId,
    DateTime? startDateTime,
    DateTime? endDateTime,
    bool? isFinished,
    List<String>? exerciseIds,
    String? customTitle,
    int? estimatedCalories,
    bool? isCaloriesManuallySet,
    int? rpe,
  }) {
    return Workout(
      id: id,
      locationId: locationId ?? this.locationId,
      startDateTime: startDateTime ?? this.startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      isFinished: isFinished ?? this.isFinished,
      exerciseIds: exerciseIds ?? this.exerciseIds,
      customTitle: customTitle ?? this.customTitle,
      estimatedCalories: estimatedCalories ?? this.estimatedCalories,
      isCaloriesManuallySet: isCaloriesManuallySet ?? this.isCaloriesManuallySet,
      rpe: rpe ?? this.rpe,
    );
  }

  String getDisplayTitle() {
    if (customTitle != null && customTitle!.isNotEmpty) {
      return customTitle!;
    }
    return 'Workout';
  }
}
