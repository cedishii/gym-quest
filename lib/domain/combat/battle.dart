import 'dart:math';

import '../../config/balance.dart';
import '../pet/species.dart';
import '../pet/stats.dart';
import 'element.dart';

enum BattleAction { strike, blast, guard, ultimate }

enum Side { player, enemy }

class Combatant {
  const Combatant({
    required this.name,
    required this.element,
    required this.level,
    required this.stats,
    required this.hp,
    required this.spriteAsset,
    this.guarding = false,
    this.charge = 0,
  });

  /// Builds a combatant at full HP from final [stats].
  factory Combatant.fromStats({
    required String name,
    required PetElement element,
    required int level,
    required Stats stats,
  }) => Combatant(
    name: name,
    element: element,
    level: level,
    stats: stats,
    hp: stats.hp.round(),
    spriteAsset: Species.of(element).asset,
  );

  final String name;
  final PetElement element;
  final int level;
  final Stats stats;
  final int hp;
  final String spriteAsset;
  final bool guarding;

  /// Turns charged toward the ultimate move.
  final int charge;

  int get maxHp => stats.hp.round();
  bool get fainted => hp <= 0;
  bool get ultimateReady => charge >= Balance.ultimateChargeTurns;
  Species get species => Species.of(element);

  Combatant copyWith({int? hp, bool? guarding, int? charge}) => Combatant(
    name: name,
    element: element,
    level: level,
    stats: stats,
    hp: hp ?? this.hp,
    spriteAsset: spriteAsset,
    guarding: guarding ?? this.guarding,
    charge: charge ?? this.charge,
  );
}

/// What happened in one action, for the battle log and animations.
class BattleEvent {
  const BattleEvent({
    required this.actor,
    required this.action,
    required this.text,
    this.damage = 0,
    this.healed = 0,
    this.multiplier = 1,
    this.critical = false,
    this.missed = false,
    this.targetFainted = false,
  });

  final Side actor;
  final BattleAction action;
  final String text;
  final int damage;
  final int healed;
  final double multiplier;
  final bool critical;
  final bool missed;
  final bool targetFainted;
}

class BattleState {
  const BattleState({
    required this.player,
    required this.enemy,
    this.round = 0,
    this.winner,
  });

  final Combatant player;
  final Combatant enemy;
  final int round;

  /// Set when the battle is over.
  final Side? winner;

  bool get finished => winner != null;

  BattleState copyWith({
    Combatant? player,
    Combatant? enemy,
    int? round,
    Side? winner,
  }) => BattleState(
    player: player ?? this.player,
    enemy: enemy ?? this.enemy,
    round: round ?? this.round,
    winner: winner ?? this.winner,
  );

  Combatant of(Side side) => side == Side.player ? player : enemy;

  BattleState withSide(Side side, Combatant c) =>
      side == Side.player ? copyWith(player: c) : copyWith(enemy: c);
}

class RoundResult {
  const RoundResult(this.state, this.events);

  final BattleState state;
  final List<BattleEvent> events;
}

/// Pure turn-based battle rules. Pass a seeded [Random] for reproducible
/// results (tests); the game uses an unseeded one.
class BattleEngine {
  BattleEngine([Random? random]) : _random = random ?? Random();

  final Random _random;

  static String actionName(Combatant c, BattleAction action) =>
      switch (action) {
        BattleAction.strike => 'Strike',
        BattleAction.blast => c.species.blastName,
        BattleAction.guard => 'Guard',
        BattleAction.ultimate => c.species.ultimateName,
      };

  /// Base damage before randomness and critical hits.
  static double baseDamage({
    required int level,
    required double attack,
    required double defense,
    required int power,
    required double multiplier,
  }) {
    final safeDefense = max(1.0, defense);
    return (((2 * level / 5 + 2) * power * attack / safeDefense) / 25 + 2) *
        multiplier;
  }

  static int powerOf(BattleAction action) => switch (action) {
    BattleAction.strike => Balance.strikePower,
    BattleAction.blast => Balance.blastPower,
    BattleAction.ultimate => Balance.ultimatePower,
    BattleAction.guard => 0,
  };

  static int accuracyOf(BattleAction action) => switch (action) {
    BattleAction.blast => Balance.blastAccuracy,
    BattleAction.ultimate => Balance.ultimateAccuracy,
    _ => 100,
  };

  /// Simple opponent AI.
  BattleAction chooseEnemyAction(BattleState state) {
    final me = state.enemy;
    final foe = state.player;
    if (me.ultimateReady) return BattleAction.ultimate;
    if (me.hp < me.maxHp * 0.35 && !me.guarding && _random.nextDouble() < 0.3) {
      return BattleAction.guard;
    }
    final blastMultiplier = Matchups.multiplier(me.element, foe.element);
    return blastMultiplier >= 1 ? BattleAction.blast : BattleAction.strike;
  }

  /// Plays one round: both sides act in speed order (player wins ties).
  RoundResult playRound(BattleState state, BattleAction playerAction) {
    if (state.finished) return RoundResult(state, const []);
    if (playerAction == BattleAction.ultimate && !state.player.ultimateReady) {
      throw StateError('Ultimate is not charged yet');
    }
    final enemyAction = chooseEnemyAction(state);
    final playerFirst = state.player.stats.speed >= state.enemy.stats.speed;
    final order = playerFirst
        ? [(Side.player, playerAction), (Side.enemy, enemyAction)]
        : [(Side.enemy, enemyAction), (Side.player, playerAction)];

    var current = state.copyWith(round: state.round + 1);
    final events = <BattleEvent>[];
    for (final (side, action) in order) {
      if (current.finished) break;
      final result = _act(current, side, action);
      current = result.$1;
      events.add(result.$2);
    }
    if (!current.finished && current.round >= Balance.maxBattleRounds) {
      current = current.copyWith(winner: Side.enemy);
    }
    return RoundResult(current, events);
  }

  (BattleState, BattleEvent) _act(
    BattleState state,
    Side side,
    BattleAction action,
  ) {
    final targetSide = side == Side.player ? Side.enemy : Side.player;
    // A guard lasts until the guarding side acts again.
    var actor = state.of(side).copyWith(guarding: false);
    var target = state.of(targetSide);
    final name = actionName(actor, action);

    if (action == BattleAction.guard) {
      final heal = min(
        actor.maxHp - actor.hp,
        (actor.maxHp * Balance.guardHealShare).round(),
      );
      actor = actor.copyWith(
        guarding: true,
        hp: actor.hp + heal,
        charge: actor.charge + 1,
      );
      final next = state.withSide(side, actor);
      return (
        next,
        BattleEvent(
          actor: side,
          action: action,
          healed: heal,
          text:
              '${actor.name} braces itself${heal > 0 ? ' and recovers $heal HP' : ''}.',
        ),
      );
    }

    actor = actor.copyWith(
      charge: action == BattleAction.ultimate ? 0 : actor.charge + 1,
    );

    if (_random.nextInt(100) >= accuracyOf(action)) {
      final next = state.withSide(side, actor);
      return (
        next,
        BattleEvent(
          actor: side,
          action: action,
          missed: true,
          text: '${actor.name} used $name... and missed!',
        ),
      );
    }

    final multiplier = action == BattleAction.strike
        ? 1.0
        : Matchups.multiplier(actor.element, target.element);
    var damage = baseDamage(
      level: actor.level,
      attack: actor.stats.attack,
      defense: target.stats.defense,
      power: powerOf(action),
      multiplier: multiplier,
    );
    final critical = _random.nextDouble() < Balance.critChance;
    if (critical) damage *= Balance.critMultiplier;
    damage *=
        Balance.minDamageRoll +
        _random.nextDouble() * (1 - Balance.minDamageRoll);
    if (target.guarding) damage *= Balance.guardDamageFactor;
    final dealt = max(1, damage.round());

    target = target.copyWith(hp: max(0, target.hp - dealt), guarding: false);
    var next = state.withSide(side, actor).withSide(targetSide, target);
    if (target.fainted) next = next.copyWith(winner: side);

    final effect = multiplier > 1
        ? " It's super effective!"
        : multiplier < 1
        ? " It's not very effective."
        : '';
    return (
      next,
      BattleEvent(
        actor: side,
        action: action,
        damage: dealt,
        multiplier: multiplier,
        critical: critical,
        targetFainted: target.fainted,
        text:
            '${actor.name} used $name for $dealt damage.'
            '${critical ? ' Critical hit!' : ''}$effect'
            '${target.fainted ? ' ${target.name} fainted!' : ''}',
      ),
    );
  }

  /// Plays a whole battle with a fixed strategy. Used by tests and balance
  /// checks (e.g. "can a level 10 pet beat leader 1?").
  BattleState autoBattle(
    BattleState start,
    BattleAction Function(BattleState) strategy,
  ) {
    var state = start;
    while (!state.finished) {
      state = playRound(state, strategy(state)).state;
    }
    return state;
  }
}
