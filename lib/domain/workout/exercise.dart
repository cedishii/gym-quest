import '../../core/json.dart';
import '../profile/profile.dart';

/// Movement slots the planner fills. Each exercise in the catalog belongs
/// to exactly one.
enum MovementPattern {
  squat,
  hinge,
  push,
  press,
  pull,
  arms,
  core,
  cardio,
  mobility,
}

extension MovementPatternText on MovementPattern {
  String get label => switch (this) {
    MovementPattern.squat => 'Legs (squat)',
    MovementPattern.hinge => 'Legs (hinge)',
    MovementPattern.push => 'Chest push',
    MovementPattern.press => 'Shoulders',
    MovementPattern.pull => 'Back pull',
    MovementPattern.arms => 'Arms',
    MovementPattern.core => 'Core',
    MovementPattern.cardio => 'Cardio',
    MovementPattern.mobility => 'Mobility',
  };
}

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.equipment,
    required this.level,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.instructions,
    required this.images,
    required this.pattern,
    required this.lowImpact,
    required this.timed,
    required this.met,
  });

  final String id;
  final String name;
  final String category;

  /// free-exercise-db equipment value, e.g. "body only", "dumbbell".
  final String equipment;

  /// beginner / intermediate / expert.
  final String level;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> instructions;

  /// Asset paths of the start/end position photos.
  final List<String> images;
  final MovementPattern pattern;

  /// No jumping or running impact.
  final bool lowImpact;

  /// Logged in seconds instead of reps.
  final bool timed;

  /// MET estimate (Compendium of Physical Activities).
  final double met;

  bool get isExpert => level == 'expert';

  static const _homeEquipment = {
    'body only',
    'dumbbell',
    'kettlebells',
    'bands',
    'exercise ball',
    'foam roll',
    'medicine ball',
  };

  bool availableWith(EquipmentAccess access) => switch (access) {
    EquipmentAccess.bodyweight => equipment == 'body only',
    EquipmentAccess.homeDumbbells => _homeEquipment.contains(equipment),
    EquipmentAccess.fullGym => true,
  };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: asString(json['id']),
    name: asString(json['name']),
    category: asString(json['category'], 'strength'),
    equipment: asString(json['equipment'], 'body only'),
    level: asString(json['level'], 'beginner'),
    primaryMuscles: List<String>.from(json['primaryMuscles'] ?? const []),
    secondaryMuscles: List<String>.from(json['secondaryMuscles'] ?? const []),
    instructions: List<String>.from(json['instructions'] ?? const []),
    images: List<String>.from(json['images'] ?? const []),
    pattern: enumByName(
      MovementPattern.values,
      json['pattern'],
      MovementPattern.core,
    ),
    lowImpact: json['lowImpact'] == true,
    timed: json['timed'] == true,
    met: asDouble(json['met'], 4),
  );
}
