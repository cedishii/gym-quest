import 'dart:math';

import '../../config/balance.dart';
import '../pet/pet_food.dart';
import '../workout/personal_records.dart';
import '../workout/workout_session.dart';
import 'reward.dart';

class WorkoutRewards {
  const WorkoutRewards._();

  /// Training tier from completed workouts, never below the tier implied
  /// by the user's stated experience.
  static int tier({
    required int completedWorkouts,
    required int experienceTier,
  }) {
    var tier = 1;
    for (final threshold in Balance.tierWorkoutThresholds) {
      if (completedWorkouts >= threshold) tier++;
    }
    return min(Balance.maxTier, max(tier, experienceTier));
  }

  /// Reward for a finished workout.
  ///
  /// * Kibble for each exercise with at least one completed set, plus a
  ///   tier bonus so fitter, more consistent players earn more.
  /// * A steak for completing every planned set. Extra sets beyond the plan
  ///   add nothing (no reward for over-training).
  /// * A steak per meaningful personal record (first-time baselines do not
  ///   count), capped per workout.
  static Reward forWorkout({
    required WorkoutSession session,
    required List<RecordHit> recordHits,
    required int tier,
  }) {
    final reasons = <String>[];
    final exercisesDone = session.exercises.where((e) => e.started).length;
    if (exercisesDone == 0) return Reward.none;

    var kibble = exercisesDone * Balance.kibblePerExercise;
    reasons.add(
      '$exercisesDone exercise${exercisesDone == 1 ? '' : 's'} completed: +$kibble kibble',
    );

    final bonus = (kibble * (tier - 1) * Balance.tierKibbleBonus).floor();
    if (bonus > 0) {
      kibble += bonus;
      reasons.add('Training tier $tier bonus: +$bonus kibble');
    }

    var steak = 0;
    final completion = min(session.completion, Balance.maxCompletion);
    if (completion >= Balance.fullWorkoutThreshold) {
      steak += Balance.steakForFullWorkout;
      reasons.add(
        'Every planned set done: +${Balance.steakForFullWorkout} steak',
      );
    }

    final improvements = recordHits.where((h) => h.isImprovement).length;
    final rewarded = min(improvements, Balance.maxRewardedRecordsPerWorkout);
    if (rewarded > 0) {
      steak += rewarded * Balance.steakPerPersonalRecord;
      reasons.add(
        '$rewarded personal record${rewarded == 1 ? '' : 's'}: '
        '+${rewarded * Balance.steakPerPersonalRecord} steak',
      );
    }

    return Reward(
      food: {PetFood.kibble: kibble, if (steak > 0) PetFood.steak: steak},
      reasons: reasons,
    );
  }
}
