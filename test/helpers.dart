import 'dart:io';
import 'dart:math';

import 'package:gym_rpg/data/exercise/exercise_repository.dart';
import 'package:gym_rpg/data/persistence/save_store.dart';
import 'package:gym_rpg/domain/combat/element.dart';
import 'package:gym_rpg/domain/profile/profile.dart';
import 'package:gym_rpg/state/app_state.dart';

/// The real bundled exercise catalog, read from disk.
ExerciseRepository loadExercises() => ExerciseRepository.fromJsonText(
  File('assets/data/exercises.json').readAsStringSync(),
);

const testProfile = Profile(
  name: 'Tester',
  sex: BodySex.male,
  age: 30,
  heightCm: 175,
  weightKg: 75,
  activity: ActivityLevel.moderate,
  goal: Goal.buildMuscle,
  experience: Experience.beginner,
  equipment: EquipmentAccess.fullGym,
  daysPerWeek: 3,
);

/// A controllable clock for tests.
class TestClock {
  TestClock(this.time);

  DateTime time;

  DateTime call() => time;

  void advance(Duration d) => time = time.add(d);
}

Future<AppState> newOnboardedState({
  SaveStore? store,
  TestClock? clock,
  PetElement element = PetElement.water,
}) async {
  final state = await AppState.load(
    store: store ?? MemorySaveStore(),
    exercises: loadExercises(),
    clock: (clock ?? TestClock(DateTime(2026, 10, 1, 9))).call,
    random: Random(7),
  );
  state.completeOnboarding(
    profile: testProfile,
    element: element,
    petName: 'Bubbles',
  );
  return state;
}

/// Marks every planned set of the active session as done.
void completeAllSets(AppState state) {
  final session = state.activeSession!;
  for (var e = 0; e < session.exercises.length; e++) {
    final log = state.activeSession!.exercises[e];
    for (var s = 0; s < log.sets.length; s++) {
      state.updateSet(e, s, log.sets[s].copyWith(done: true));
    }
  }
}
