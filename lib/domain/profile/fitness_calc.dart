import 'dart:math';

import 'profile.dart';

/// BMI categories. With [Profile.useAsianBmiCutoffs] the WHO Asia-Pacific
/// thresholds are used (overweight >= 23, obese >= 25); otherwise the
/// standard WHO thresholds (overweight >= 25, obese >= 30).
enum BmiCategory { underweight, normal, overweight, obese }

extension BmiCategoryText on BmiCategory {
  String get label => switch (this) {
    BmiCategory.underweight => 'Underweight',
    BmiCategory.normal => 'Healthy range',
    BmiCategory.overweight => 'Overweight',
    BmiCategory.obese => 'Obese',
  };
}

class MacroTargets {
  const MacroTargets({
    required this.calories,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
  });

  final int calories;
  final int proteinG;
  final int fatG;
  final int carbsG;
}

/// Everything derived from the profile, with the reasoning kept so the UI
/// can show how each number was calculated.
class FitnessSummary {
  const FitnessSummary({
    required this.bmi,
    required this.bmiCategory,
    required this.bmr,
    required this.tdee,
    required this.targets,
    required this.calorieFloor,
    required this.floorApplied,
    required this.notes,
  });

  final double bmi;
  final BmiCategory bmiCategory;
  final double bmr;
  final double tdee;
  final MacroTargets targets;

  /// The lowest daily target the app will ever suggest for this profile.
  final int calorieFloor;

  /// True when the goal adjustment would have gone below [calorieFloor].
  final bool floorApplied;

  /// Safety notes and adjustments to show next to the numbers.
  final List<String> notes;
}

class FitnessCalc {
  const FitnessCalc._();

  /// Absolute minimum daily targets. Common clinical guidance is to avoid
  /// unsupervised diets below ~1,500 kcal (men) / ~1,200 kcal (women).
  static const int minCaloriesMale = 1500;
  static const int minCaloriesFemale = 1200;

  static const int loseFatDeficit = 500;
  static const int buildMuscleSurplus = 300;

  static double bmi({required double weightKg, required double heightCm}) {
    final meters = heightCm / 100;
    return weightKg / (meters * meters);
  }

  static BmiCategory bmiCategory(double bmi, {bool asianCutoffs = true}) {
    if (bmi < 18.5) return BmiCategory.underweight;
    final overweight = asianCutoffs ? 23.0 : 25.0;
    final obese = asianCutoffs ? 25.0 : 30.0;
    if (bmi < overweight) return BmiCategory.normal;
    if (bmi < obese) return BmiCategory.overweight;
    return BmiCategory.obese;
  }

  /// Mifflin-St Jeor resting energy expenditure, kcal/day.
  static double bmr({
    required BodySex sex,
    required double weightKg,
    required double heightCm,
    required int age,
  }) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    return sex == BodySex.male ? base + 5 : base - 161;
  }

  static double tdee(double bmr, ActivityLevel activity) =>
      bmr * activity.factor;

  static FitnessSummary summarize(Profile p) {
    final bmiValue = bmi(weightKg: p.weightKg, heightCm: p.heightCm);
    final category = bmiCategory(bmiValue, asianCutoffs: p.useAsianBmiCutoffs);
    final bmrValue = bmr(
      sex: p.sex,
      weightKg: p.weightKg,
      heightCm: p.heightCm,
      age: p.age,
    );
    final tdeeValue = tdee(bmrValue, p.activity);
    final notes = <String>[];

    var goal = p.goal;
    if (p.age < 18 && goal == Goal.loseFat) {
      goal = Goal.maintain;
      notes.add(
        'Under 18: the app does not set a calorie deficit. '
        'Talk to a doctor or coach before dieting while still growing.',
      );
    }
    if (category == BmiCategory.underweight && goal == Goal.loseFat) {
      goal = Goal.maintain;
      notes.add(
        'Your BMI is in the underweight range, so the target is set '
        'to maintenance instead of a deficit.',
      );
    }

    var target = switch (goal) {
      Goal.loseFat => tdeeValue - loseFatDeficit,
      Goal.buildMuscle => tdeeValue + buildMuscleSurplus,
      Goal.maintain => tdeeValue,
    };

    final sexFloor = p.sex == BodySex.male
        ? minCaloriesMale
        : minCaloriesFemale;
    // Never suggest eating less than the body burns at rest either.
    final floor = max(sexFloor, bmrValue.round());
    final floorApplied = target < floor;
    if (floorApplied) {
      target = floor.toDouble();
      notes.add(
        'Target raised to the safe minimum of $floor kcal '
        '(never below your resting burn or $sexFloor kcal).',
      );
    }

    final calories = target.round();
    final proteinPerKg = switch (goal) {
      Goal.loseFat => 1.8,
      Goal.buildMuscle => 1.8,
      Goal.maintain => 1.4,
    };
    final protein = (p.weightKg * proteinPerKg).round();
    final fat = (calories * 0.25 / 9).round();
    final carbs = max(0, ((calories - protein * 4 - fat * 9) / 4).round());

    notes.add(
      'All values are estimates from standard formulas, not measurements.',
    );

    return FitnessSummary(
      bmi: bmiValue,
      bmiCategory: category,
      bmr: bmrValue,
      tdee: tdeeValue,
      targets: MacroTargets(
        calories: calories,
        proteinG: protein,
        fatG: fat,
        carbsG: carbs,
      ),
      calorieFloor: floor,
      floorApplied: floorApplied,
      notes: notes,
    );
  }

  /// Estimated kcal burned: MET x body weight (kg) x hours.
  /// This is a rough population average, not a measurement of effort.
  static double estimateCalories({
    required double met,
    required double weightKg,
    required Duration duration,
  }) => met * weightKg * duration.inSeconds / 3600;
}
