import 'package:flutter_test/flutter_test.dart';
import 'package:gym_rpg/domain/progression/achievements.dart';
import 'package:gym_rpg/domain/progression/streaks.dart';
import 'package:gym_rpg/domain/workout/planner.dart';
import 'package:gym_rpg/domain/profile/fitness_calc.dart';
import 'package:gym_rpg/domain/profile/profile.dart';
import 'package:gym_rpg/domain/workout/exercise.dart';

import '../helpers.dart';

AchievementContext ctx({
  int workouts = 0,
  int petLevel = 1,
  int badges = 0,
  int foodDays = 0,
}) => AchievementContext(
  workouts: workouts,
  recordImprovements: 0,
  petLevel: petLevel,
  battlesWon: 0,
  badges: badges,
  bestEndlessFloor: 0,
  foodLogDays: foodDays,
  longestStreak: 0,
  equippedSlots: 0,
);

void main() {
  group('streaks', () {
    final today = DateTime(2026, 10, 20, 12);

    test('empty history has no streak', () {
      final s = Streaks.compute([], today);
      expect(s.current, 0);
      expect(s.alive, isFalse);
    });

    test('one rest day between workouts keeps the streak', () {
      final s = Streaks.compute([
        '2026-10-14',
        '2026-10-16',
        '2026-10-18',
        '2026-10-20',
      ], today);
      expect(s.alive, isTrue);
      expect(s.current, 7);
    });

    test('two rest days in a row break it', () {
      final s = Streaks.compute([
        '2026-10-10',
        '2026-10-11',
        '2026-10-15',
        '2026-10-16',
      ], today);
      expect(s.current, 0); // last workout 4 days ago
      expect(s.longest, 2);
    });

    test('streak stays alive through one missed day', () {
      final s = Streaks.compute(['2026-10-17', '2026-10-18'], today);
      expect(s.alive, isTrue);
      expect(s.daysUntilBreak, 0);
    });

    test('milestones are reached once', () {
      expect(StreakMilestones.newlyReached(15, {}), [7, 14]);
      expect(StreakMilestones.newlyReached(15, {7}), [14]);
      expect(StreakMilestones.newlyReached(30, {7, 14, 21, 28}), [30]);
      expect(StreakMilestones.newlyReached(6, {}), isEmpty);
    });
  });

  group('achievements', () {
    test('conditions unlock at their goal', () {
      final unlocked = Achievements.newlyUnlocked(
        ctx(workouts: 10, petLevel: 10),
        {},
      );
      final ids = unlocked.map((a) => a.id).toSet();
      expect(ids, containsAll(['first_workout', 'workouts_10', 'pet_10']));
      expect(ids, isNot(contains('workouts_50')));
    });

    test('already unlocked ones are not repeated', () {
      final unlocked = Achievements.newlyUnlocked(ctx(workouts: 1), {
        'first_workout',
      });
      expect(unlocked, isEmpty);
    });

    test('ids are unique', () {
      final ids = Achievements.all.map((a) => a.id).toSet();
      expect(ids.length, Achievements.all.length);
    });
  });

  group('planner', () {
    final catalog = loadExercises().exercises;

    PlannerInput input({
      int days = 3,
      EquipmentAccess equipment = EquipmentAccess.fullGym,
      BmiCategory bmi = BmiCategory.normal,
      Goal goal = Goal.maintain,
      Experience exp = Experience.beginner,
      int tier = 1,
    }) => PlannerInput(
      goal: goal,
      experience: exp,
      equipment: equipment,
      daysPerWeek: days,
      bmiCategory: bmi,
      tier: tier,
    );

    test('day count follows the split', () {
      final planner = WorkoutPlanner(catalog);
      expect(planner.generate(input(days: 2)).days.length, 2);
      expect(planner.generate(input(days: 3)).days.length, 3);
      expect(planner.generate(input(days: 4)).days.length, 4);
      expect(planner.generate(input(days: 6)).days.length, 6);
    });

    test('bodyweight plans only use bodyweight exercises', () {
      final plan = WorkoutPlanner(catalog)
          .generate(input(equipment: EquipmentAccess.bodyweight));
      final byId = {for (final e in catalog) e.id: e};
      for (final day in plan.days) {
        expect(day.exercises, isNotEmpty);
        for (final e in day.exercises) {
          expect(byId[e.exerciseId]!.equipment, 'body only');
        }
      }
    });

    test('high BMI gets only low-impact exercises', () {
      final plan = WorkoutPlanner(catalog).generate(
        input(
          bmi: BmiCategory.obese,
          goal: Goal.loseFat,
          equipment: EquipmentAccess.homeDumbbells,
        ),
      );
      final byId = {for (final e in catalog) e.id: e};
      for (final day in plan.days) {
        for (final e in day.exercises) {
          expect(byId[e.exerciseId]!.lowImpact, isTrue, reason: e.exerciseId);
        }
      }
      expect(
        plan.days.every(
          (d) => d.exercises.any(
            (e) => byId[e.exerciseId]!.pattern == MovementPattern.cardio,
          ),
        ),
        isTrue,
      );
    });

    test('higher tier adds volume', () {
      final low = WorkoutPlanner(catalog).generate(input(tier: 1));
      final high = WorkoutPlanner(catalog).generate(input(tier: 4));
      expect(high.days.first.totalSets, greaterThan(low.days.first.totalSets));
    });

    test('no exercise repeats within a day', () {
      final plan = WorkoutPlanner(catalog)
          .generate(input(days: 5, goal: Goal.buildMuscle));
      for (final day in plan.days) {
        final ids = day.exercises.map((e) => e.exerciseId).toList();
        expect(ids.toSet().length, ids.length);
      }
    });
  });
}
