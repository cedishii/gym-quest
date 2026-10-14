import '../../core/json.dart';
import '../rewards/reward.dart';
import 'personal_records.dart';
import 'workout_session.dart';

/// A finished workout, kept in history.
class WorkoutRecord {
  const WorkoutRecord({
    required this.id,
    required this.dayName,
    required this.startedAt,
    required this.finishedAt,
    required this.exercises,
    required this.completion,
    required this.estimatedKcal,
    required this.recordHits,
    required this.reward,
  });

  /// Same id as the session it came from. Rewards are keyed by this id so
  /// one workout can never be rewarded twice.
  final String id;
  final String dayName;
  final DateTime startedAt;
  final DateTime finishedAt;
  final List<ExerciseLog> exercises;
  final double completion;

  /// MET-based estimate, not a measurement.
  final double estimatedKcal;
  final List<RecordHit> recordHits;
  final Reward reward;

  Duration get duration => finishedAt.difference(startedAt);
  int get completedSets => exercises.fold(0, (sum, e) => sum + e.completedSets);
  int get improvements => recordHits.where((h) => h.isImprovement).length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'dayName': dayName,
    'startedAt': startedAt.toIso8601String(),
    'finishedAt': finishedAt.toIso8601String(),
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'completion': completion,
    'kcal': estimatedKcal,
    'records': recordHits.map((h) => h.toJson()).toList(),
    'reward': reward.toJson(),
  };

  factory WorkoutRecord.fromJson(Map<String, dynamic> json) => WorkoutRecord(
    id: asString(json['id']),
    dayName: asString(json['dayName']),
    startedAt: DateTime.tryParse(asString(json['startedAt'])) ?? DateTime.now(),
    finishedAt:
        DateTime.tryParse(asString(json['finishedAt'])) ?? DateTime.now(),
    exercises: asMapList(json['exercises']).map(ExerciseLog.fromJson).toList(),
    completion: asDouble(json['completion']),
    estimatedKcal: asDouble(json['kcal']),
    recordHits: asMapList(json['records']).map(RecordHit.fromJson).toList(),
    reward: Reward.fromJson(asMap(json['reward'])),
  );
}
