import 'package:flutter_test/flutter_test.dart';
import 'package:gym_rpg/domain/profile/fitness_calc.dart';
import 'package:gym_rpg/domain/profile/profile.dart';

import '../helpers.dart';

void main() {
  group('BMI', () {
    test('is weight over height squared', () {
      expect(
        FitnessCalc.bmi(weightKg: 70, heightCm: 175),
        closeTo(22.857, 0.001),
      );
    });

    test('uses Asian cut-offs when asked', () {
      expect(
        FitnessCalc.bmiCategory(24, asianCutoffs: true),
        BmiCategory.overweight,
      );
      expect(
        FitnessCalc.bmiCategory(24, asianCutoffs: false),
        BmiCategory.normal,
      );
      expect(
        FitnessCalc.bmiCategory(26, asianCutoffs: true),
        BmiCategory.obese,
      );
      expect(
        FitnessCalc.bmiCategory(26, asianCutoffs: false),
        BmiCategory.overweight,
      );
      expect(
        FitnessCalc.bmiCategory(17, asianCutoffs: true),
        BmiCategory.underweight,
      );
    });
  });

  group('BMR / TDEE', () {
    test('Mifflin-St Jeor male and female', () {
      // 10*75 + 6.25*175 - 5*30 + 5 = 1698.75
      expect(
        FitnessCalc.bmr(
          sex: BodySex.male,
          weightKg: 75,
          heightCm: 175,
          age: 30,
        ),
        closeTo(1698.75, 0.001),
      );
      // 10*60 + 6.25*165 - 5*28 - 161 = 1330.25
      expect(
        FitnessCalc.bmr(
          sex: BodySex.female,
          weightKg: 60,
          heightCm: 165,
          age: 28,
        ),
        closeTo(1330.25, 0.001),
      );
    });

    test('TDEE multiplies by the activity factor', () {
      expect(
        FitnessCalc.tdee(1000, ActivityLevel.moderate),
        closeTo(1550, 0.001),
      );
      expect(
        FitnessCalc.tdee(1000, ActivityLevel.sedentary),
        closeTo(1200, 0.001),
      );
    });
  });

  group('calorie targets', () {
    test('fat loss subtracts 500 from TDEE', () {
      final s = FitnessCalc.summarize(testProfile.copyWith(goal: Goal.loseFat));
      expect(s.targets.calories, (s.tdee - 500).round());
      expect(s.floorApplied, isFalse);
    });

    test('never goes below the safe floor', () {
      const small = Profile(
        name: 'Small',
        sex: BodySex.female,
        age: 60,
        heightCm: 150,
        weightKg: 50,
        activity: ActivityLevel.sedentary,
        goal: Goal.loseFat,
        experience: Experience.beginner,
        equipment: EquipmentAccess.bodyweight,
        daysPerWeek: 3,
      );
      final s = FitnessCalc.summarize(small);
      expect(
        s.targets.calories,
        greaterThanOrEqualTo(FitnessCalc.minCaloriesFemale),
      );
      expect(s.targets.calories, greaterThanOrEqualTo(s.bmr.round()));
      expect(s.floorApplied, isTrue);
    });

    test('underweight users are not given a deficit', () {
      final s = FitnessCalc.summarize(
        testProfile.copyWith(weightKg: 50, heightCm: 180, goal: Goal.loseFat),
      );
      expect(s.bmiCategory, BmiCategory.underweight);
      expect(s.targets.calories, s.tdee.round());
    });

    test('under-18 users are not given a deficit', () {
      final s = FitnessCalc.summarize(
        testProfile.copyWith(age: 16, goal: Goal.loseFat),
      );
      expect(s.targets.calories, s.tdee.round());
    });

    test('macros add up to roughly the calorie target', () {
      final s = FitnessCalc.summarize(testProfile);
      final kcal =
          s.targets.proteinG * 4 + s.targets.fatG * 9 + s.targets.carbsG * 4;
      expect(kcal, closeTo(s.targets.calories, 15));
    });
  });

  test('profile validation reports each bad field', () {
    final errors = Profile.validate(
      name: ' ',
      age: 5,
      heightCm: 400,
      weightKg: null,
      daysPerWeek: 9,
    );
    expect(
      errors.keys,
      containsAll(['name', 'age', 'height', 'weight', 'days']),
    );
    expect(
      Profile.validate(
        name: 'A',
        age: 30,
        heightCm: 170,
        weightKg: 70,
        daysPerWeek: 3,
      ),
      isEmpty,
    );
  });

  test('calorie estimate is MET x kg x hours', () {
    expect(
      FitnessCalc.estimateCalories(
        met: 5,
        weightKg: 80,
        duration: const Duration(minutes: 30),
      ),
      closeTo(200, 0.001),
    );
  });
}
