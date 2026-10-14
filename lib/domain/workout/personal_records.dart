import '../../config/balance.dart';
import '../../core/json.dart';
import 'workout_session.dart';

enum RecordKind { estimatedMax, reps, seconds }

/// Best performance for one exercise and metric.
class PersonalRecord {
  const PersonalRecord({
    required this.exerciseId,
    required this.kind,
    required this.value,
    required this.achievedAt,
  });

  final String exerciseId;
  final RecordKind kind;

  /// kg (estimated one-rep max), reps, or seconds depending on [kind].
  final double value;
  final DateTime achievedAt;

  String get key => keyFor(exerciseId, kind);

  static String keyFor(String exerciseId, RecordKind kind) =>
      '$exerciseId:${kind.name}';

  String get valueLabel => switch (kind) {
    RecordKind.estimatedMax => '${value.toStringAsFixed(1)} kg est. 1RM',
    RecordKind.reps => '${value.round()} reps',
    RecordKind.seconds => '${value.round()} s',
  };

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'kind': kind.name,
    'value': value,
    'at': achievedAt.toIso8601String(),
  };

  factory PersonalRecord.fromJson(Map<String, dynamic> json) => PersonalRecord(
    exerciseId: asString(json['exerciseId']),
    kind: enumByName(RecordKind.values, json['kind'], RecordKind.reps),
    value: asDouble(json['value']),
    achievedAt: DateTime.tryParse(asString(json['at'])) ?? DateTime.now(),
  );
}

/// A record beaten in a workout. [previous] is null for a first baseline.
class RecordHit {
  const RecordHit({required this.record, required this.previous});

  final PersonalRecord record;
  final double? previous;

  /// Only improvements over an existing record count for rewards; the
  /// first time an exercise is logged just sets the baseline.
  bool get isImprovement => previous != null;

  Map<String, dynamic> toJson() => {
    'record': record.toJson(),
    'previous': previous,
  };

  factory RecordHit.fromJson(Map<String, dynamic> json) => RecordHit(
    record: PersonalRecord.fromJson(asMap(json['record'])),
    previous: json['previous'] == null ? null : asDouble(json['previous']),
  );
}

class PersonalRecords {
  const PersonalRecords._();

  /// Epley estimated one-rep max.
  static double estimatedMax(double weightKg, int reps) =>
      reps <= 1 ? weightKg : weightKg * (1 + reps / 30);

  /// Best metric of a logged exercise, or null if nothing was completed.
  static ({RecordKind kind, double value})? best(
    ExerciseLog log, {
    required bool timed,
  }) {
    final done = log.sets.where((s) => s.done).toList();
    if (done.isEmpty) return null;
    if (timed) {
      final seconds = done
          .map((s) => s.seconds)
          .reduce((a, b) => a > b ? a : b);
      return seconds > 0
          ? (kind: RecordKind.seconds, value: seconds.toDouble())
          : null;
    }
    final weighted = done.where((s) => s.weightKg > 0 && s.reps > 0).toList();
    if (weighted.isNotEmpty) {
      final best = weighted
          .map((s) => estimatedMax(s.weightKg, s.reps))
          .reduce((a, b) => a > b ? a : b);
      return (kind: RecordKind.estimatedMax, value: best);
    }
    final reps = done.map((s) => s.reps).reduce((a, b) => a > b ? a : b);
    return reps > 0 ? (kind: RecordKind.reps, value: reps.toDouble()) : null;
  }

  /// True when [value] beats [previous] by the configured margin.
  static bool beats(RecordKind kind, double value, double previous) =>
      switch (kind) {
        RecordKind.estimatedMax =>
          value >= previous * (1 + Balance.prMinWeightImprovement) &&
              value > previous,
        RecordKind.reps => value >= previous + Balance.prMinRepImprovement,
        RecordKind.seconds =>
          value >= previous + Balance.prMinSecondsImprovement,
      };

  /// Compares a finished workout against [existing] records. Returns the
  /// hits (baselines and improvements) and the updated record map.
  static ({List<RecordHit> hits, Map<String, PersonalRecord> records})
  evaluate({
    required Map<String, PersonalRecord> existing,
    required List<ExerciseLog> logs,
    required bool Function(String exerciseId) isTimed,
    required DateTime at,
  }) {
    final records = Map<String, PersonalRecord>.from(existing);
    final hits = <RecordHit>[];
    for (final log in logs) {
      final result = best(log, timed: isTimed(log.exerciseId));
      if (result == null) continue;
      final key = PersonalRecord.keyFor(log.exerciseId, result.kind);
      final previous = records[key];
      final record = PersonalRecord(
        exerciseId: log.exerciseId,
        kind: result.kind,
        value: result.value,
        achievedAt: at,
      );
      if (previous == null) {
        records[key] = record;
        hits.add(RecordHit(record: record, previous: null));
      } else if (beats(result.kind, result.value, previous.value)) {
        records[key] = record;
        hits.add(RecordHit(record: record, previous: previous.value));
      }
    }
    return (hits: hits, records: records);
  }
}
