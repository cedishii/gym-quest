import 'dart:math';

import '../profile/fitness_calc.dart';
import '../profile/profile.dart';
import 'exercise.dart';
import 'workout_plan.dart';

class PlannerInput {
  const PlannerInput({
    required this.goal,
    required this.experience,
    required this.equipment,
    required this.daysPerWeek,
    required this.bmiCategory,
    required this.tier,
  });

  final Goal goal;
  final Experience experience;
  final EquipmentAccess equipment;
  final int daysPerWeek;
  final BmiCategory bmiCategory;

  /// Training tier 1–5 (grows with completed workouts).
  final int tier;
}

/// Rule-based weekly plan generator.
///
/// Split by days per week: 2–3 full body, 4 upper/lower, 5–6
/// push/pull/legs. Exercises are chosen by movement pattern from what the
/// user's equipment allows. High BMI or beginner + overweight swaps
/// jumping/running for low-impact options. Volume grows with the tier.
class WorkoutPlanner {
  WorkoutPlanner(this.catalog);

  final List<Exercise> catalog;

  WorkoutPlan generate(PlannerInput input, {DateTime? now}) {
    final reasons = <String>[];
    final lowImpact =
        input.bmiCategory == BmiCategory.obese ||
        (input.bmiCategory == BmiCategory.overweight &&
            input.experience == Experience.beginner);
    if (lowImpact) {
      reasons.add('Low-impact exercises chosen to go easy on your joints.');
    }

    final templates = _templates(input.daysPerWeek);
    reasons.add(switch (input.daysPerWeek) {
      <= 3 => 'Full-body sessions: best with ${input.daysPerWeek} days a week.',
      4 => 'Upper/lower split for 4 days a week.',
      _ => 'Push/pull/legs split for ${input.daysPerWeek} days a week.',
    });

    switch (input.goal) {
      case Goal.loseFat:
        reasons.add(
          'Fat loss: moderate weights, higher reps, cardio finisher.',
        );
      case Goal.buildMuscle:
        reasons.add('Muscle: 8–12 reps with more sets per exercise.');
      case Goal.maintain:
        reasons.add('General fitness: balanced strength plus mobility.');
    }
    if (input.tier > 1) {
      reasons.add(
        'Training tier ${input.tier}: volume increased for your progress.',
      );
    }

    final usage = <String, int>{};
    final days = <WorkoutDay>[];
    for (var i = 0; i < templates.length; i++) {
      final template = templates[i];
      final slots = [...template.slots];
      if (input.goal == Goal.loseFat) {
        slots.add(MovementPattern.cardio);
      } else {
        slots.add(MovementPattern.mobility);
      }
      final exercises = <PlannedExercise>[];
      final usedToday = <String>{};
      for (final pattern in slots) {
        final exercise = _pick(pattern, input, lowImpact, usage, usedToday);
        if (exercise == null) continue;
        usedToday.add(exercise.id);
        usage[exercise.id] = (usage[exercise.id] ?? 0) + 1;
        exercises.add(_prescribe(exercise, input));
      }
      days.add(
        WorkoutDay(
          name: template.name,
          focus: template.focus,
          exercises: exercises,
        ),
      );
    }

    return WorkoutPlan(
      days: days,
      createdAt: now ?? DateTime.now(),
      tier: input.tier,
      reasons: reasons,
    );
  }

  Exercise? _pick(
    MovementPattern pattern,
    PlannerInput input,
    bool lowImpact,
    Map<String, int> usage,
    Set<String> usedToday,
  ) {
    bool allowed(Exercise e) =>
        e.pattern == pattern &&
        e.availableWith(input.equipment) &&
        !usedToday.contains(e.id) &&
        (!lowImpact || e.lowImpact) &&
        (input.experience != Experience.beginner || !e.isExpert);

    final candidates = catalog.where(allowed).toList();
    // A skipped slot is better than an unsafe or impossible exercise.
    if (candidates.isEmpty) return null;

    // Prefer exercises used least so far (variety across days), then
    // easier ones for beginners, then catalog order for stability.
    int levelRank(Exercise e) => switch (e.level) {
      'beginner' => 0,
      'intermediate' => 1,
      _ => 2,
    };
    candidates.sort((a, b) {
      final byUse = (usage[a.id] ?? 0).compareTo(usage[b.id] ?? 0);
      if (byUse != 0) return byUse;
      if (input.experience == Experience.beginner) {
        final byLevel = levelRank(a).compareTo(levelRank(b));
        if (byLevel != 0) return byLevel;
      }
      return catalog.indexOf(a).compareTo(catalog.indexOf(b));
    });
    return candidates.first;
  }

  PlannedExercise _prescribe(Exercise e, PlannerInput input) {
    final tier = input.tier.clamp(1, 5);
    final extraSet = tier >= 3 ? 1 : 0;
    final baseSets = switch (input.goal) {
      Goal.buildMuscle => input.experience == Experience.beginner ? 3 : 4,
      _ => 3,
    };

    if (e.pattern == MovementPattern.cardio) {
      final minutes = switch (input.goal) {
        Goal.loseFat => 12,
        Goal.buildMuscle => 8,
        Goal.maintain => 10,
      };
      return PlannedExercise(
        exerciseId: e.id,
        sets: 1,
        targetReps: e.timed ? 0 : 15,
        targetSeconds: e.timed ? (minutes + (tier - 1) * 2) * 60 : 0,
        restSeconds: 60,
      );
    }
    if (e.pattern == MovementPattern.mobility) {
      return PlannedExercise(
        exerciseId: e.id,
        sets: 2,
        targetReps: e.timed ? 0 : 10,
        targetSeconds: e.timed ? 30 : 0,
        restSeconds: 15,
      );
    }
    if (e.timed) {
      return PlannedExercise(
        exerciseId: e.id,
        sets: min(5, baseSets + extraSet),
        targetReps: 0,
        targetSeconds: 25 + (tier - 1) * 10,
        restSeconds: 45,
      );
    }
    final reps = switch (input.goal) {
      Goal.loseFat => 12,
      Goal.buildMuscle => 10,
      Goal.maintain => 10,
    };
    return PlannedExercise(
      exerciseId: e.id,
      sets: min(5, baseSets + extraSet),
      targetReps: reps,
      targetSeconds: 0,
      restSeconds: input.goal == Goal.buildMuscle ? 90 : 60,
    );
  }

  static List<_DayTemplate> _templates(int days) {
    const fullA = _DayTemplate('Full Body A', 'Whole body', [
      MovementPattern.squat,
      MovementPattern.push,
      MovementPattern.pull,
      MovementPattern.hinge,
      MovementPattern.core,
    ]);
    const fullB = _DayTemplate('Full Body B', 'Whole body', [
      MovementPattern.hinge,
      MovementPattern.press,
      MovementPattern.pull,
      MovementPattern.squat,
      MovementPattern.core,
    ]);
    const fullC = _DayTemplate('Full Body C', 'Whole body', [
      MovementPattern.squat,
      MovementPattern.push,
      MovementPattern.pull,
      MovementPattern.arms,
      MovementPattern.core,
    ]);
    const upper = _DayTemplate('Upper', 'Chest, back, shoulders, arms', [
      MovementPattern.push,
      MovementPattern.pull,
      MovementPattern.press,
      MovementPattern.pull,
      MovementPattern.arms,
    ]);
    const lower = _DayTemplate('Lower', 'Legs and core', [
      MovementPattern.squat,
      MovementPattern.hinge,
      MovementPattern.squat,
      MovementPattern.core,
    ]);
    const push = _DayTemplate('Push', 'Chest, shoulders, triceps', [
      MovementPattern.push,
      MovementPattern.press,
      MovementPattern.push,
      MovementPattern.arms,
    ]);
    const pull = _DayTemplate('Pull', 'Back and biceps', [
      MovementPattern.pull,
      MovementPattern.pull,
      MovementPattern.hinge,
      MovementPattern.arms,
    ]);
    const legs = _DayTemplate('Legs', 'Legs and core', [
      MovementPattern.squat,
      MovementPattern.hinge,
      MovementPattern.squat,
      MovementPattern.core,
    ]);

    return switch (days) {
      <= 2 => [fullA, fullB],
      3 => [fullA, fullB, fullC],
      4 => [
        upper,
        lower,
        const _DayTemplate('Upper 2', 'Chest, back, shoulders, arms', [
          MovementPattern.press,
          MovementPattern.pull,
          MovementPattern.push,
          MovementPattern.pull,
          MovementPattern.arms,
        ]),
        const _DayTemplate('Lower 2', 'Legs and core', [
          MovementPattern.hinge,
          MovementPattern.squat,
          MovementPattern.hinge,
          MovementPattern.core,
        ]),
      ],
      5 => [push, pull, legs, upper, lower],
      _ => [
        push,
        pull,
        legs,
        const _DayTemplate('Push 2', 'Chest, shoulders, triceps', [
          MovementPattern.press,
          MovementPattern.push,
          MovementPattern.press,
          MovementPattern.arms,
        ]),
        const _DayTemplate('Pull 2', 'Back and biceps', [
          MovementPattern.pull,
          MovementPattern.hinge,
          MovementPattern.pull,
          MovementPattern.arms,
        ]),
        const _DayTemplate('Legs 2', 'Legs and core', [
          MovementPattern.hinge,
          MovementPattern.squat,
          MovementPattern.squat,
          MovementPattern.core,
        ]),
      ],
    };
  }
}

class _DayTemplate {
  const _DayTemplate(this.name, this.focus, this.slots);

  final String name;
  final String focus;
  final List<MovementPattern> slots;
}
