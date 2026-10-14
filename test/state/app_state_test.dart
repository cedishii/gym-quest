import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_rpg/data/persistence/save_store.dart';
import 'package:gym_rpg/data/persistence/save_store_io.dart';
import 'package:gym_rpg/domain/combat/battle.dart';
import 'package:gym_rpg/domain/combat/element.dart';
import 'package:gym_rpg/domain/inventory/items.dart';
import 'package:gym_rpg/domain/map/stages.dart';
import 'package:gym_rpg/domain/nutrition/food.dart';
import 'package:gym_rpg/domain/nutrition/food_log.dart';
import 'package:gym_rpg/domain/pet/pet_food.dart';
import 'package:gym_rpg/state/app_state.dart';

import '../helpers.dart';

const apple = Food(
  id: '171688',
  name: 'Apples, raw, with skin',
  source: FoodSource.usda,
  per100g: Nutrients(kcal: 52, proteinG: 0.26, fatG: 0.17, carbsG: 13.8),
);

void main() {
  group('onboarding', () {
    test('creates profile, pet, starter food and a plan', () async {
      final state = await newOnboardedState();
      expect(state.save.onboarded, isTrue);
      expect(state.pet!.level, 1);
      expect(state.foodCount(PetFood.kibble), 2);
      expect(state.plan!.days.length, 3);
    });

    test('rejects an empty pet name', () async {
      final state = await newOnboardedState();
      expect(
        () => state.completeOnboarding(
          profile: testProfile,
          element: PetElement.fire,
          petName: '  ',
        ),
        throwsA(isA<GameActionException>()),
      );
    });
  });

  group('workout to reward', () {
    test('a full workout gives kibble per exercise plus a steak', () async {
      final clock = TestClock(DateTime(2026, 10, 1, 9));
      final state = await newOnboardedState(clock: clock);
      state.startSession(0);
      final exercisesInDay = state.activeSession!.exercises.length;
      completeAllSets(state);
      clock.advance(const Duration(minutes: 45));
      final outcome = state.finishSession();

      expect(outcome.record.completion, 1.0);
      expect(outcome.record.reward.count(PetFood.kibble), exercisesInDay);
      expect(outcome.record.reward.count(PetFood.steak), 1);
      expect(outcome.record.estimatedKcal, greaterThan(0));
      // Starter kibble (2) + workout kibble + first-workout achievement (3).
      expect(state.foodCount(PetFood.kibble), 2 + exercisesInDay + 3);
      expect(state.save.workouts.length, 1);
      expect(state.activeSession, isNull);
      expect(outcome.unlocks.map((u) => u.title), contains('First Rep'));
    });

    test('a partial workout gives kibble only', () async {
      final state = await newOnboardedState();
      state.startSession(0);
      final log = state.activeSession!.exercises.first;
      state.updateSet(0, 0, log.sets.first.copyWith(done: true));
      final outcome = state.finishSession();
      expect(outcome.record.reward.count(PetFood.kibble), 1);
      expect(outcome.record.reward.count(PetFood.steak), 0);
    });

    test('finishing with nothing done is refused', () async {
      final state = await newOnboardedState();
      state.startSession(0);
      expect(state.finishSession, throwsA(isA<GameActionException>()));
      expect(state.save.workouts, isEmpty);
    });

    test('the same workout can never be rewarded twice', () async {
      final store = MemorySaveStore();
      final state = await newOnboardedState(store: store);
      final session = state.startSession(0);
      completeAllSets(state);
      state.finishSession();
      final kibbleAfterFirst = state.foodCount(PetFood.kibble);
      await state.flush();

      // Simulate a stale copy of the same session coming back (e.g. a
      // double submit restored from an old save).
      final replay = await AppState.load(
        store: store,
        exercises: loadExercises(),
      );
      final restored = replay.save.copyWith(activeSession: session);
      final dup = AppState(
        save: restored,
        store: store,
        exercises: loadExercises(),
      );
      completeAllSets(dup);
      expect(dup.finishSession, throwsA(isA<GameActionException>()));
      expect(dup.foodCount(PetFood.kibble), kibbleAfterFirst);
      expect(dup.save.workouts.length, 1);
      expect(dup.activeSession, isNull);
    });

    test('a personal record improvement earns an extra steak', () async {
      final clock = TestClock(DateTime(2026, 10, 1, 9));
      final state = await newOnboardedState(clock: clock);
      // Baseline: first workout sets records but does not reward them.
      state.startSession(0);
      completeAllSets(state);
      final first = state.finishSession();
      expect(first.record.improvements, 0);

      clock.advance(const Duration(days: 2));
      state.startSession(0);
      final log = state.activeSession!.exercises.first;
      final planned = log.planned;
      // Beat the first exercise's best by a clear margin.
      final better = planned.isTimed
          ? log.sets.first.copyWith(
              seconds: planned.targetSeconds + 30,
              done: true,
            )
          : log.sets.first.copyWith(reps: planned.targetReps + 5, done: true);
      state.updateSet(0, 0, better);
      final second = state.finishSession();
      expect(second.record.improvements, 1);
      expect(second.record.reward.count(PetFood.steak), 1);
    });
  });

  group('pet', () {
    test('feeding spends food and levels the pet', () async {
      final state = await newOnboardedState();
      state.startSession(0);
      completeAllSets(state);
      state.finishSession();
      final before = state.foodCount(PetFood.steak);
      final outcome = state.feed(PetFood.steak);
      expect(state.foodCount(PetFood.steak), before - 1);
      expect(outcome.result.pet.level, greaterThanOrEqualTo(1));
      expect(state.pet!.level * 1000 + state.pet!.xp, greaterThan(1000));
    });

    test('feeding without food is refused', () async {
      final state = await newOnboardedState();
      expect(
        () => state.feed(PetFood.feast),
        throwsA(isA<GameActionException>()),
      );
    });
  });

  group('battles and map', () {
    test(
      'winning the first stage grants its reward once and unlocks the next',
      () async {
        final state = await newOnboardedState();
        final start = state.startStageBattle(0);
        final engine = BattleEngine(Random(3));
        // Give the player an overwhelming pet for the test.
        final strong = BattleState(
          player: Combatant.fromStats(
            name: 'Test',
            element: start.player.element,
            level: 50,
            stats: start.player.stats * 10,
          ),
          enemy: start.enemy,
        );
        final end = engine.autoBattle(strong, (_) => BattleAction.strike);
        expect(end.winner, Side.player);

        final itemsBefore = state.inventory.length;
        final outcome = state.finishStageBattle(0, end);
        expect(outcome.firstClear, isTrue);
        expect(
          state.inventory.length,
          itemsBefore + GameMap.stages[0].reward.items.length,
        );
        expect(state.mapProgress.isUnlocked(1), isTrue);
        expect(outcome.unlocks.map((u) => u.title), contains('First Victory'));

        // Replaying a cleared stage gives nothing.
        final again = state.finishStageBattle(0, end);
        expect(again.firstClear, isFalse);
        expect(again.reward.isEmpty, isTrue);
        expect(
          state.inventory.length,
          itemsBefore + GameMap.stages[0].reward.items.length,
        );
      },
    );

    test('locked stages cannot be started', () async {
      final state = await newOnboardedState();
      expect(
        () => state.startStageBattle(2),
        throwsA(isA<GameActionException>()),
      );
      expect(state.startEndlessBattle, throwsA(isA<GameActionException>()));
    });

    test('equipment changes battle stats', () async {
      final state = await newOnboardedState();
      final before = state.petStats!;
      final start = state.startStageBattle(0);
      final end = BattleState(
        player: start.player,
        enemy: start.enemy.copyWith(hp: 0),
        winner: Side.player,
      );
      state.finishStageBattle(0, end); // grants ring_copper
      final ring = state.inventory.firstWhere((i) => i.itemId == 'ring_copper');
      state.equip(ring.instanceId);
      expect(state.equippedIn(EquipSlot.ring)!.instanceId, ring.instanceId);
      expect(state.petStats!.attack, before.attack + 2);
      expect(state.playerCombatant().stats.attack, before.attack + 2);
      state.unequip(EquipSlot.ring);
      expect(state.petStats!.attack, before.attack);
    });
  });

  group('nutrition', () {
    test('logging food updates the day total', () async {
      final clock = TestClock(DateTime(2026, 10, 1, 12));
      final state = await newOnboardedState(clock: clock);
      state.logFood(
        food: apple,
        grams: 200,
        meal: Meal.snack,
        day: state.today,
      );
      expect(state.totalsFor(state.today).kcal, closeTo(104, 0.001));
      expect(state.recentFoods.single.name, apple.name);
      final id = state.entriesFor(state.today).single.id;
      state.removeFoodEntry(id);
      expect(state.entriesFor(state.today), isEmpty);
    });

    test('invalid amounts are rejected', () async {
      final state = await newOnboardedState();
      expect(
        () => state.logFood(
          food: apple,
          grams: 0,
          meal: Meal.lunch,
          day: state.today,
        ),
        throwsA(isA<GameActionException>()),
      );
    });

    test('custom food validation', () async {
      final state = await newOnboardedState();
      expect(
        () => state.addCustomFood(
          name: 'X',
          per100g: const Nutrients(
            kcal: 100,
            proteinG: 60,
            fatG: 30,
            carbsG: 30,
          ),
        ),
        throwsA(isA<GameActionException>()),
      );
      final adobo = state.addCustomFood(
        name: 'Chicken adobo (homemade)',
        per100g: const Nutrients(kcal: 190, proteinG: 18, fatG: 11, carbsG: 4),
        serving: const Serving('1 bowl', 250),
      );
      expect(state.save.customFoods.single.id, adobo.id);
    });
  });

  group('persistence', () {
    test('everything survives a restart (memory store)', () async {
      final store = MemorySaveStore();
      final clock = TestClock(DateTime(2026, 10, 1, 9));
      final state = await newOnboardedState(store: store, clock: clock);
      state.startSession(0);
      completeAllSets(state);
      state.finishSession();
      state.feed(PetFood.kibble, count: 2);
      state.logFood(
        food: apple,
        grams: 150,
        meal: Meal.breakfast,
        day: state.today,
      );
      await state.flush();

      final reloaded = await AppState.load(
        store: store,
        exercises: loadExercises(),
        clock: clock.call,
      );
      expect(reloaded.save.toJson(), state.save.toJson());
      expect(reloaded.pet!.xp, state.pet!.xp);
      expect(reloaded.save.rewardedWorkoutIds, state.save.rewardedWorkoutIds);
    });

    test('an in-progress workout survives a restart', () async {
      final store = MemorySaveStore();
      final state = await newOnboardedState(store: store);
      state.startSession(1);
      final log = state.activeSession!.exercises.first;
      state.updateSet(0, 0, log.sets.first.copyWith(done: true, reps: 7));
      await state.flush();
      final reloaded = await AppState.load(
        store: store,
        exercises: loadExercises(),
      );
      expect(reloaded.activeSession!.exercises.first.sets.first.reps, 7);
      expect(reloaded.activeSession!.exercises.first.sets.first.done, isTrue);
    });

    test('a damaged save falls back to the backup', () async {
      final store = MemorySaveStore();
      final state = await newOnboardedState(store: store);
      state.renamePet('Second');
      await state.flush();
      store.data = '{broken json';
      final reloaded = await AppState.load(
        store: store,
        exercises: loadExercises(),
      );
      expect(reloaded.loadWarning, isNotNull);
      expect(reloaded.save.onboarded, isTrue);
    });

    test('file store writes atomically and reloads', () async {
      final dir = await Directory.systemTemp.createTemp('gym_quest_test');
      try {
        final store = FileSaveStore(dir);
        final state = await newOnboardedState(store: store);
        state.renamePet('Disk');
        await state.flush();
        expect(
          File('${dir.path}${Platform.pathSeparator}save.json').existsSync(),
          isTrue,
        );
        expect(
          File('${dir.path}${Platform.pathSeparator}save.json.tmp')
              .existsSync(),
          isFalse,
        );

        final reloaded = await AppState.load(
          store: FileSaveStore(dir),
          exercises: loadExercises(),
        );
        expect(reloaded.pet!.name, 'Disk');
        expect(await FileSaveStore(dir).readBackup(), isNotNull);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('reset clears the save', () async {
      final store = MemorySaveStore();
      final state = await newOnboardedState(store: store);
      await state.flush();
      await state.resetAll();
      expect(state.save.onboarded, isFalse);
      expect(store.data, isNull);
    });
  });
}
