import '../../core/json.dart';
import 'workout_plan.dart';

/// One performed set. For timed exercises [seconds] is used, otherwise
/// [reps] (and optionally [weightKg]).
class SetLog {
  const SetLog({
    this.reps = 0,
    this.weightKg = 0,
    this.seconds = 0,
    this.done = false,
  });

  static const maxReps = 200;
  static const maxWeightKg = 500.0;
  static const maxSeconds = 7200;

  final int reps;
  final double weightKg;
  final int seconds;
  final bool done;

  SetLog copyWith({int? reps, double? weightKg, int? seconds, bool? done}) =>
      SetLog(
        reps: reps ?? this.reps,
        weightKg: weightKg ?? this.weightKg,
        seconds: seconds ?? this.seconds,
        done: done ?? this.done,
      );

  /// Error message when the set cannot be marked done, or null.
  String? validate({required bool timed}) {
    if (timed) {
      if (seconds <= 0) return 'Enter how many seconds you held it';
      if (seconds > maxSeconds) return 'That is more than 2 hours';
    } else {
      if (reps <= 0) return 'Enter the reps you did';
      if (reps > maxReps) return 'Reps must be $maxReps or fewer';
    }
    if (weightKg < 0 || weightKg > maxWeightKg) {
      return 'Weight must be 0–${maxWeightKg.round()} kg';
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'r': reps,
    'w': weightKg,
    's': seconds,
    'd': done,
  };

  factory SetLog.fromJson(Map<String, dynamic> json) => SetLog(
    reps: asInt(json['r']),
    weightKg: asDouble(json['w']),
    seconds: asInt(json['s']),
    done: json['d'] == true,
  );
}

class ExerciseLog {
  const ExerciseLog({required this.planned, required this.sets});

  /// A fresh log pre-filled with the plan's targets.
  factory ExerciseLog.fromPlan(PlannedExercise planned) => ExerciseLog(
    planned: planned,
    sets: List.generate(
      planned.sets,
      (_) => SetLog(reps: planned.targetReps, seconds: planned.targetSeconds),
    ),
  );

  final PlannedExercise planned;
  final List<SetLog> sets;

  String get exerciseId => planned.exerciseId;
  int get completedSets => sets.where((s) => s.done).length;
  bool get started => completedSets > 0;

  ExerciseLog withSet(int index, SetLog set) {
    final next = [...sets];
    next[index] = set;
    return ExerciseLog(planned: planned, sets: next);
  }

  ExerciseLog withExtraSet() => ExerciseLog(
    planned: planned,
    sets: [
      ...sets,
      SetLog(reps: planned.targetReps, seconds: planned.targetSeconds),
    ],
  );

  Map<String, dynamic> toJson() => {
    'planned': planned.toJson(),
    'sets': sets.map((s) => s.toJson()).toList(),
  };

  factory ExerciseLog.fromJson(Map<String, dynamic> json) => ExerciseLog(
    planned: PlannedExercise.fromJson(asMap(json['planned'])),
    sets: asMapList(json['sets']).map(SetLog.fromJson).toList(),
  );
}

/// A workout in progress. Saved so closing the app mid-workout loses nothing.
class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.dayName,
    required this.startedAt,
    required this.exercises,
  });

  final String id;
  final String dayName;
  final DateTime startedAt;
  final List<ExerciseLog> exercises;

  int get plannedSets => exercises.fold(0, (sum, e) => sum + e.planned.sets);
  int get completedSets => exercises.fold(0, (sum, e) => sum + e.completedSets);

  /// Share of planned sets completed. Extra sets beyond the plan do not
  /// push this above 1.0 (see Balance.maxCompletion).
  double get completion {
    if (plannedSets == 0) return 0;
    var counted = 0;
    for (final e in exercises) {
      counted += e.completedSets.clamp(0, e.planned.sets);
    }
    return counted / plannedSets;
  }

  WorkoutSession withExercise(int index, ExerciseLog log) {
    final next = [...exercises];
    next[index] = log;
    return WorkoutSession(
      id: id,
      dayName: dayName,
      startedAt: startedAt,
      exercises: next,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'dayName': dayName,
    'startedAt': startedAt.toIso8601String(),
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
    id: asString(json['id']),
    dayName: asString(json['dayName']),
    startedAt: DateTime.tryParse(asString(json['startedAt'])) ?? DateTime.now(),
    exercises: asMapList(json['exercises']).map(ExerciseLog.fromJson).toList(),
  );
}
