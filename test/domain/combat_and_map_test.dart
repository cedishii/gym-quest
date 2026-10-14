import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_rpg/config/balance.dart';
import 'package:gym_rpg/domain/combat/battle.dart';
import 'package:gym_rpg/domain/combat/element.dart';
import 'package:gym_rpg/domain/map/stages.dart';
import 'package:gym_rpg/domain/pet/species.dart';

Combatant fighter(PetElement e, int level, {double mult = 1}) =>
    Combatant.fromStats(
      name: e.label,
      element: e,
      level: level,
      stats: Species.of(e).statsAt(level) * mult,
    );

void main() {
  group('element matchups', () {
    test('agreed chart', () {
      expect(
        Matchups.multiplier(PetElement.water, PetElement.fire),
        Balance.superEffective,
      );
      expect(
        Matchups.multiplier(PetElement.fire, PetElement.leaf),
        Balance.superEffective,
      );
      expect(
        Matchups.multiplier(PetElement.leaf, PetElement.water),
        Balance.superEffective,
      );
      expect(
        Matchups.multiplier(PetElement.rock, PetElement.fire),
        Balance.superEffective,
      );
      expect(
        Matchups.multiplier(PetElement.water, PetElement.rock),
        Balance.superEffective,
      );
      expect(
        Matchups.multiplier(PetElement.leaf, PetElement.rock),
        Balance.superEffective,
      );
      // Reverse directions are weak.
      expect(
        Matchups.multiplier(PetElement.fire, PetElement.water),
        Balance.notVeryEffective,
      );
      expect(
        Matchups.multiplier(PetElement.fire, PetElement.rock),
        Balance.notVeryEffective,
      );
      expect(
        Matchups.multiplier(PetElement.rock, PetElement.leaf),
        Balance.notVeryEffective,
      );
    });

    test('neutral has no strengths or weaknesses', () {
      for (final e in PetElement.values) {
        expect(Matchups.multiplier(PetElement.neutral, e), 1.0);
        expect(Matchups.multiplier(e, PetElement.neutral), 1.0);
      }
    });

    test('same element is neutral', () {
      for (final e in PetElement.values) {
        expect(Matchups.multiplier(e, e), 1.0);
      }
    });
  });

  group('battle engine', () {
    test('type advantage increases damage', () {
      final strong = BattleEngine.baseDamage(
        level: 10,
        attack: 30,
        defense: 20,
        power: 50,
        multiplier: 1.5,
      );
      final even = BattleEngine.baseDamage(
        level: 10,
        attack: 30,
        defense: 20,
        power: 50,
        multiplier: 1,
      );
      expect(strong, closeTo(even * 1.5, 1e-9));
    });

    test('a round deals damage and the faster side acts first', () {
      final engine = BattleEngine(Random(1));
      final state = BattleState(
        player: fighter(PetElement.leaf, 10),
        enemy: fighter(PetElement.rock, 10),
      );
      final result = engine.playRound(state, BattleAction.blast);
      expect(
        result.events.first.actor,
        Side.player,
      ); // Leaf is faster than Rock
      expect(result.state.enemy.hp, lessThan(state.enemy.hp));
      expect(result.state.round, 1);
    });

    test('guard halves damage and heals', () {
      final engine = BattleEngine(Random(3));
      final player = fighter(PetElement.rock, 10).copyWith(hp: 60);
      final state = BattleState(
        player: player,
        enemy: fighter(PetElement.fire, 10),
      );
      final result = engine.playRound(state, BattleAction.guard);
      final guardEvent = result.events.firstWhere(
        (e) => e.actor == Side.player,
      );
      expect(guardEvent.action, BattleAction.guard);
      expect(guardEvent.healed, greaterThan(0));
    });

    test('ultimate needs charge', () {
      final engine = BattleEngine(Random(1));
      final state = BattleState(
        player: fighter(PetElement.fire, 5),
        enemy: fighter(PetElement.leaf, 5),
      );
      expect(
        () => engine.playRound(state, BattleAction.ultimate),
        throwsStateError,
      );
    });

    test('a much stronger pet wins and the battle ends', () {
      final engine = BattleEngine(Random(42));
      final start = BattleState(
        player: fighter(PetElement.water, 30),
        enemy: fighter(PetElement.fire, 8),
      );
      final end = engine.autoBattle(
        start,
        (s) =>
            s.player.ultimateReady ? BattleAction.ultimate : BattleAction.blast,
      );
      expect(end.finished, isTrue);
      expect(end.winner, Side.player);
      expect(end.enemy.hp, 0);
    });

    test('a much weaker pet loses', () {
      final engine = BattleEngine(Random(42));
      final start = BattleState(
        player: fighter(PetElement.fire, 3),
        enemy: fighter(PetElement.water, 25),
      );
      final end = engine.autoBattle(start, (_) => BattleAction.strike);
      expect(end.winner, Side.enemy);
    });

    test('stalemates end after the round limit', () {
      final engine = BattleEngine(Random(1));
      final start = BattleState(
        player: fighter(PetElement.rock, 60),
        enemy: fighter(PetElement.rock, 60, mult: 1),
      );
      final end = engine.autoBattle(start, (_) => BattleAction.guard);
      expect(end.finished, isTrue);
      expect(end.round, lessThanOrEqualTo(Balance.maxBattleRounds));
    });
  });

  group('map', () {
    test('5 regions with a leader each, levels rising', () {
      expect(GameMap.stages.length, 20);
      final leaders = GameMap.stages
          .where((s) => s.kind == StageKind.leader)
          .toList();
      expect(leaders.map((s) => s.element).toSet().length, 5);
      for (var i = 1; i < GameMap.stages.length; i++) {
        expect(
          GameMap.stages[i].level,
          greaterThanOrEqualTo(GameMap.stages[i - 1].level),
        );
      }
    });

    test('stages unlock one at a time', () {
      var progress = const MapProgress();
      expect(progress.isUnlocked(0), isTrue);
      expect(progress.isUnlocked(1), isFalse);
      progress = progress.withCleared(0);
      expect(progress.isUnlocked(1), isTrue);
      expect(progress.isUnlocked(2), isFalse);
      expect(progress.currentIndex, 1);
      expect(progress.endlessUnlocked, isFalse);
    });

    test('endless opens after the final leader and HP rises per floor', () {
      var progress = MapProgress(cleared: {for (var i = 0; i < 20; i++) i});
      expect(progress.endlessUnlocked, isTrue);
      expect(progress.badges, 5);
      final f1 = GameMap.endlessEnemy(1);
      final f2 = GameMap.endlessEnemy(2);
      final f6 = GameMap.endlessEnemy(6);
      expect(f6.maxHp, greaterThan(GameMap.endlessEnemy(1).maxHp));
      expect(f2.level, f1.level);
      progress = progress.withEndlessCleared(1);
      expect(progress.endlessFloor, 2);
      expect(progress.bestEndlessFloor, 1);
      expect(GameMap.endlessReward(10).items, isNotEmpty);
      expect(GameMap.endlessReward(9).isEmpty, isTrue);
    });

    test('pacing: a well-geared level 42 pet usually beats the champion', () {
      final champion = GameMap.stages.last.enemy();
      var wins = 0;
      for (var seed = 0; seed < 20; seed++) {
        final engine = BattleEngine(Random(seed));
        final player = fighter(PetElement.leaf, 42, mult: 1.2); // with gear
        final end = engine.autoBattle(
          BattleState(player: player, enemy: champion),
          (s) => s.player.ultimateReady
              ? BattleAction.ultimate
              : BattleAction.blast,
        );
        if (end.winner == Side.player) wins++;
      }
      expect(wins, greaterThan(10));
    });

    test('pacing: a level 3 pet cannot beat the first leader', () {
      final leader = GameMap.stages[3].enemy();
      final engine = BattleEngine(Random(5));
      final end = engine.autoBattle(
        BattleState(player: fighter(PetElement.fire, 3), enemy: leader),
        (_) => BattleAction.blast,
      );
      expect(end.winner, Side.enemy);
    });
  });
}
