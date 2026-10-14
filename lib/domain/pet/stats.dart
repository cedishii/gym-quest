import '../../core/json.dart';

/// Battle stats. Used for base stats, per-level growth and equipment bonuses.
class Stats {
  const Stats({this.hp = 0, this.attack = 0, this.defense = 0, this.speed = 0});

  static const zero = Stats();

  final double hp;
  final double attack;
  final double defense;
  final double speed;

  Stats operator +(Stats o) => Stats(
    hp: hp + o.hp,
    attack: attack + o.attack,
    defense: defense + o.defense,
    speed: speed + o.speed,
  );

  Stats operator *(double f) => Stats(
    hp: hp * f,
    attack: attack * f,
    defense: defense * f,
    speed: speed * f,
  );

  /// Multiplies each stat by (1 + the matching percent in [pct]).
  Stats withPercent(Stats pct) => Stats(
    hp: hp * (1 + pct.hp),
    attack: attack * (1 + pct.attack),
    defense: defense * (1 + pct.defense),
    speed: speed * (1 + pct.speed),
  );

  Stats copyWithHp(double value) =>
      Stats(hp: value, attack: attack, defense: defense, speed: speed);

  Stats rounded() => Stats(
    hp: hp.roundToDouble(),
    attack: attack.roundToDouble(),
    defense: defense.roundToDouble(),
    speed: speed.roundToDouble(),
  );

  bool get isZero => hp == 0 && attack == 0 && defense == 0 && speed == 0;

  Map<String, dynamic> toJson() => {
    'hp': hp,
    'atk': attack,
    'def': defense,
    'spd': speed,
  };

  factory Stats.fromJson(Map<String, dynamic> json) => Stats(
    hp: asDouble(json['hp']),
    attack: asDouble(json['atk']),
    defense: asDouble(json['def']),
    speed: asDouble(json['spd']),
  );
}
