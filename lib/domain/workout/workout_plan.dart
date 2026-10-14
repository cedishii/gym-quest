import '../../core/json.dart';

/// One exercise slot in a planned workout day.
class PlannedExercise {
  const PlannedExercise({
    required this.exerciseId,
    required this.sets,
    required this.targetReps,
    required this.targetSeconds,
    required this.restSeconds,
  });

  final String exerciseId;
  final int sets;

  /// Reps per set for rep-based exercises (0 for timed ones).
  final int targetReps;

  /// Seconds per set for timed exercises (0 for rep-based ones).
  final int targetSeconds;
  final int restSeconds;

  bool get isTimed => targetSeconds > 0;

  String get targetLabel => isTimed
      ? '$sets × ${_duration(targetSeconds)}'
      : '$sets × $targetReps reps';

  static String _duration(int seconds) => seconds >= 60 && seconds % 60 == 0
      ? '${seconds ~/ 60} min'
      : '$seconds s';

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'sets': sets,
    'reps': targetReps,
    'seconds': targetSeconds,
    'rest': restSeconds,
  };

  factory PlannedExercise.fromJson(Map<String, dynamic> json) =>
      PlannedExercise(
        exerciseId: asString(json['exerciseId']),
        sets: asInt(json['sets'], 3),
        targetReps: asInt(json['reps']),
        targetSeconds: asInt(json['seconds']),
        restSeconds: asInt(json['rest'], 60),
      );
}

class WorkoutDay {
  const WorkoutDay({
    required this.name,
    required this.focus,
    required this.exercises,
  });

  final String name;
  final String focus;
  final List<PlannedExercise> exercises;

  int get totalSets => exercises.fold(0, (sum, e) => sum + e.sets);

  Map<String, dynamic> toJson() => {
    'name': name,
    'focus': focus,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };

  factory WorkoutDay.fromJson(Map<String, dynamic> json) => WorkoutDay(
    name: asString(json['name']),
    focus: asString(json['focus']),
    exercises: asMapList(json['exercises'])
        .map(PlannedExercise.fromJson)
        .toList(),
  );
}

class WorkoutPlan {
  const WorkoutPlan({
    required this.days,
    required this.createdAt,
    required this.tier,
    required this.reasons,
  });

  final List<WorkoutDay> days;
  final DateTime createdAt;

  /// Training tier the plan was generated for.
  final int tier;

  /// Why the plan looks the way it does (shown to the user).
  final List<String> reasons;

  Map<String, dynamic> toJson() => {
    'days': days.map((d) => d.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'tier': tier,
    'reasons': reasons,
  };

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) => WorkoutPlan(
    days: asMapList(json['days']).map(WorkoutDay.fromJson).toList(),
    createdAt: DateTime.tryParse(asString(json['createdAt'])) ?? DateTime.now(),
    tier: asInt(json['tier'], 1),
    reasons: List<String>.from(json['reasons'] ?? const []),
  );
}
