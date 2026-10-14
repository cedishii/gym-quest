import '../../config/balance.dart';

enum PetElement { fire, water, leaf, rock, neutral }

extension ElementText on PetElement {
  String get label => switch (this) {
    PetElement.fire => 'Fire',
    PetElement.water => 'Water',
    PetElement.leaf => 'Leaf',
    PetElement.rock => 'Rock',
    PetElement.neutral => 'Neutral',
  };
}

/// Elemental matchup chart (agreed in planning):
///   Water > Fire > Leaf > Water, Rock > Fire, Water > Rock, Leaf > Rock.
///   Neutral has no strengths or weaknesses.
class Matchups {
  const Matchups._();

  static const Map<PetElement, Set<PetElement>> _strongAgainst = {
    PetElement.water: {PetElement.fire, PetElement.rock},
    PetElement.fire: {PetElement.leaf},
    PetElement.leaf: {PetElement.water, PetElement.rock},
    PetElement.rock: {PetElement.fire},
    PetElement.neutral: {},
  };

  static bool isStrong(PetElement attack, PetElement defend) =>
      _strongAgainst[attack]!.contains(defend);

  /// Damage multiplier for an [attack]-type move hitting a [defend]-type
  /// monster.
  static double multiplier(PetElement attack, PetElement defend) {
    if (isStrong(attack, defend)) return Balance.superEffective;
    if (isStrong(defend, attack)) return Balance.notVeryEffective;
    return 1.0;
  }

  static List<PetElement> strongAgainst(PetElement e) =>
      _strongAgainst[e]!.toList();

  static List<PetElement> weakAgainst(PetElement e) =>
      PetElement.values.where((other) => isStrong(other, e)).toList();
}
