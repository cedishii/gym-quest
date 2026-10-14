import '../../core/json.dart';

/// Sex used only by the BMR formula (Mifflin-St Jeor has separate
/// constants for male and female bodies).
enum BodySex { male, female }

enum Goal { loseFat, buildMuscle, maintain }

enum Experience { beginner, intermediate, advanced }

/// What the user can train with. Each level includes the ones before it.
enum EquipmentAccess { bodyweight, homeDumbbells, fullGym }

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

extension GoalText on Goal {
  String get label => switch (this) {
    Goal.loseFat => 'Lose fat',
    Goal.buildMuscle => 'Build muscle',
    Goal.maintain => 'Stay fit',
  };
}

extension ExperienceText on Experience {
  String get label => switch (this) {
    Experience.beginner => 'Beginner',
    Experience.intermediate => 'Intermediate',
    Experience.advanced => 'Advanced',
  };
}

extension EquipmentText on EquipmentAccess {
  String get label => switch (this) {
    EquipmentAccess.bodyweight => 'No equipment',
    EquipmentAccess.homeDumbbells => 'Home (dumbbells/bands)',
    EquipmentAccess.fullGym => 'Full gym',
  };
}

extension ActivityText on ActivityLevel {
  String get label => switch (this) {
    ActivityLevel.sedentary => 'Sedentary (desk job, little exercise)',
    ActivityLevel.light => 'Light (exercise 1–3 days/week)',
    ActivityLevel.moderate => 'Moderate (exercise 3–5 days/week)',
    ActivityLevel.active => 'Active (hard exercise 6–7 days/week)',
    ActivityLevel.veryActive => 'Very active (physical job + training)',
  };

  /// Standard TDEE activity multipliers.
  double get factor => switch (this) {
    ActivityLevel.sedentary => 1.2,
    ActivityLevel.light => 1.375,
    ActivityLevel.moderate => 1.55,
    ActivityLevel.active => 1.725,
    ActivityLevel.veryActive => 1.9,
  };
}

class Profile {
  const Profile({
    required this.name,
    required this.sex,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.activity,
    required this.goal,
    required this.experience,
    required this.equipment,
    required this.daysPerWeek,
    this.useAsianBmiCutoffs = true,
  });

  final String name;
  final BodySex sex;
  final int age;
  final double heightCm;
  final double weightKg;
  final ActivityLevel activity;
  final Goal goal;
  final Experience experience;
  final EquipmentAccess equipment;
  final int daysPerWeek;

  /// WHO Asia-Pacific BMI cut-offs (overweight from 23, obese from 25).
  final bool useAsianBmiCutoffs;

  static const minAge = 13;
  static const maxAge = 100;
  static const minHeightCm = 100.0;
  static const maxHeightCm = 250.0;
  static const minWeightKg = 25.0;
  static const maxWeightKg = 350.0;
  static const minDays = 2;
  static const maxDays = 6;

  /// Validation errors for the given raw values, keyed by field name.
  /// An empty map means the profile is valid.
  static Map<String, String> validate({
    required String name,
    required int? age,
    required double? heightCm,
    required double? weightKg,
    required int daysPerWeek,
  }) {
    final errors = <String, String>{};
    if (name.trim().isEmpty) errors['name'] = 'Enter a name';
    if (name.trim().length > 30) errors['name'] = 'Keep it under 30 characters';
    if (age == null) {
      errors['age'] = 'Enter your age';
    } else if (age < minAge || age > maxAge) {
      errors['age'] = 'Age must be $minAge–$maxAge';
    }
    if (heightCm == null) {
      errors['height'] = 'Enter your height';
    } else if (heightCm < minHeightCm || heightCm > maxHeightCm) {
      errors['height'] =
          'Height must be ${minHeightCm.round()}–${maxHeightCm.round()} cm';
    }
    if (weightKg == null) {
      errors['weight'] = 'Enter your weight';
    } else if (weightKg < minWeightKg || weightKg > maxWeightKg) {
      errors['weight'] =
          'Weight must be ${minWeightKg.round()}–${maxWeightKg.round()} kg';
    }
    if (daysPerWeek < minDays || daysPerWeek > maxDays) {
      errors['days'] = 'Choose $minDays–$maxDays days';
    }
    return errors;
  }

  Profile copyWith({
    String? name,
    BodySex? sex,
    int? age,
    double? heightCm,
    double? weightKg,
    ActivityLevel? activity,
    Goal? goal,
    Experience? experience,
    EquipmentAccess? equipment,
    int? daysPerWeek,
    bool? useAsianBmiCutoffs,
  }) => Profile(
    name: name ?? this.name,
    sex: sex ?? this.sex,
    age: age ?? this.age,
    heightCm: heightCm ?? this.heightCm,
    weightKg: weightKg ?? this.weightKg,
    activity: activity ?? this.activity,
    goal: goal ?? this.goal,
    experience: experience ?? this.experience,
    equipment: equipment ?? this.equipment,
    daysPerWeek: daysPerWeek ?? this.daysPerWeek,
    useAsianBmiCutoffs: useAsianBmiCutoffs ?? this.useAsianBmiCutoffs,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'sex': sex.name,
    'age': age,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'activity': activity.name,
    'goal': goal.name,
    'experience': experience.name,
    'equipment': equipment.name,
    'daysPerWeek': daysPerWeek,
    'useAsianBmiCutoffs': useAsianBmiCutoffs,
  };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    name: asString(json['name'], 'Trainer'),
    sex: enumByName(BodySex.values, json['sex'], BodySex.male),
    age: asInt(json['age'], 25).clamp(minAge, maxAge),
    heightCm: asDouble(json['heightCm'], 165).clamp(minHeightCm, maxHeightCm),
    weightKg: asDouble(json['weightKg'], 65).clamp(minWeightKg, maxWeightKg),
    activity: enumByName(
      ActivityLevel.values,
      json['activity'],
      ActivityLevel.light,
    ),
    goal: enumByName(Goal.values, json['goal'], Goal.maintain),
    experience: enumByName(
      Experience.values,
      json['experience'],
      Experience.beginner,
    ),
    equipment: enumByName(
      EquipmentAccess.values,
      json['equipment'],
      EquipmentAccess.bodyweight,
    ),
    daysPerWeek: asInt(json['daysPerWeek'], 3).clamp(minDays, maxDays),
    useAsianBmiCutoffs: json['useAsianBmiCutoffs'] != false,
  );
}
