// Balance check: for every story stage, the lowest pet level that wins at
// least 60% of 200 simulated battles (blast/ultimate strategy), with and
// without typical gear, and the estimated full workouts needed to get there.
//
// Usage: dart run tool/balance_sim.dart
// ignore_for_file: avoid_print
import 'dart:math';

import 'package:gym_rpg/config/balance.dart';
import 'package:gym_rpg/domain/combat/battle.dart';
import 'package:gym_rpg/domain/combat/element.dart';
import 'package:gym_rpg/domain/map/stages.dart';
import 'package:gym_rpg/domain/pet/pet.dart';
import 'package:gym_rpg/domain/pet/species.dart';

/// XP from one full 5-exercise workout at tier 1 (5 kibble + 1 steak).
final xpPerWorkout = 5 * Balance.kibbleXp + Balance.steakXp;

double winRate(PetElement element, int level, double gear, Stage stage) {
  var wins = 0;
  const runs = 200;
  for (var seed = 0; seed < runs; seed++) {
    final engine = BattleEngine(Random(seed));
    final player = Combatant.fromStats(
      name: 'Pet',
      element: element,
      level: level,
      stats: (Species.of(element).statsAt(level) * gear).rounded(),
    );
    final end = engine.autoBattle(
      BattleState(player: player, enemy: stage.enemy()),
      (s) =>
          s.player.ultimateReady ? BattleAction.ultimate : BattleAction.blast,
    );
    if (end.winner == Side.player) wins++;
  }
  return wins / runs;
}

void main() {
  for (final element in PetElement.values) {
    print('== ${element.label} pet ==');
    for (final stage in GameMap.stages) {
      int? needed;
      for (var level = 1; level <= 80; level++) {
        // Gear grows with progress: ~+5% per region cleared.
        final gear = 1 + 0.05 * (stage.index ~/ GameMap.stagesPerRegion);
        if (winRate(element, level, gear, stage) >= 0.6) {
          needed = level;
          break;
        }
      }
      final xp = needed == null ? null : PetProgression.totalXpForLevel(needed);
      final workouts = xp == null ? '-' : (xp / xpPerWorkout).ceil().toString();
      print(
        '${stage.index.toString().padLeft(2)} ${stage.kind.name.padRight(7)} '
        '${stage.element.label.padRight(7)} Lv${stage.level.toString().padLeft(2)} '
        '-> pet Lv ${needed ?? '>80'} (~$workouts workouts)',
      );
    }
  }
}
