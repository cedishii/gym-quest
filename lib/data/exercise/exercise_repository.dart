import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/json.dart';
import '../../domain/workout/exercise.dart';

/// Bundled exercise catalog (free-exercise-db subset, see
/// tool/build_exercises.py).
class ExerciseRepository {
  ExerciseRepository(this.exercises)
    : _byId = {for (final e in exercises) e.id: e};

  final List<Exercise> exercises;
  final Map<String, Exercise> _byId;

  static Future<ExerciseRepository> load([AssetBundle? bundle]) async {
    final text = await (bundle ?? rootBundle).loadString(
      'assets/data/exercises.json',
    );
    return ExerciseRepository.fromJsonText(text);
  }

  factory ExerciseRepository.fromJsonText(String text) {
    final json = asMap(jsonDecode(text));
    return ExerciseRepository(
      asMapList(json['exercises']).map(Exercise.fromJson).toList(),
    );
  }

  Exercise? byId(String id) => _byId[id];

  bool isTimed(String id) => _byId[id]?.timed ?? false;
}
