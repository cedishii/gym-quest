import '../combat/element.dart';
import 'stats.dart';

/// The five starter pets, one per element.
class Species {
  const Species({
    required this.element,
    required this.name,
    required this.description,
    required this.base,
    required this.growth,
    required this.asset,
    required this.blastName,
    required this.ultimateName,
  });

  final PetElement element;
  final String name;
  final String description;

  /// Stats at level 1.
  final Stats base;

  /// Stats gained per level.
  final Stats growth;
  final String asset;
  final String blastName;
  final String ultimateName;

  static const all = <Species>[
    Species(
      element: PetElement.fire,
      name: 'Emberkin',
      description: 'Hot-headed and fast. Hits hard, but its guard is thin.',
      base: Stats(hp: 44, attack: 14, defense: 9, speed: 12),
      growth: Stats(hp: 7.0, attack: 2.4, defense: 1.4, speed: 1.8),
      asset: 'assets/pets/fire.png',
      blastName: 'Flame Burst',
      ultimateName: 'Inferno',
    ),
    Species(
      element: PetElement.water,
      name: 'Ripplet',
      description: 'Calm and sturdy. Outlasts opponents with steady defense.',
      base: Stats(hp: 48, attack: 11, defense: 12, speed: 10),
      growth: Stats(hp: 7.5, attack: 1.9, defense: 2.0, speed: 1.5),
      asset: 'assets/pets/water.png',
      blastName: 'Tide Splash',
      ultimateName: 'Tsunami',
    ),
    Species(
      element: PetElement.leaf,
      name: 'Sproutle',
      description: 'Quick and balanced. Strong against Water and Rock.',
      base: Stats(hp: 46, attack: 12, defense: 10, speed: 13),
      growth: Stats(hp: 7.0, attack: 2.0, defense: 1.6, speed: 2.0),
      asset: 'assets/pets/leaf.png',
      blastName: 'Vine Whip',
      ultimateName: 'Solar Bloom',
    ),
    Species(
      element: PetElement.rock,
      name: 'Pebblor',
      description: 'Slow but tough as a mountain. Shrugs off big hits.',
      base: Stats(hp: 54, attack: 12, defense: 14, speed: 7),
      growth: Stats(hp: 8.5, attack: 2.0, defense: 2.4, speed: 1.0),
      asset: 'assets/pets/rock.png',
      blastName: 'Rock Throw',
      ultimateName: 'Landslide',
    ),
    Species(
      element: PetElement.neutral,
      name: 'Nimbo',
      description: 'No weaknesses, no strengths. Relies on pure training.',
      base: Stats(hp: 50, attack: 12, defense: 11, speed: 11),
      growth: Stats(hp: 7.6, attack: 2.0, defense: 1.8, speed: 1.6),
      asset: 'assets/pets/neutral.png',
      blastName: 'Power Wave',
      ultimateName: 'Mega Impact',
    ),
  ];

  static Species of(PetElement element) =>
      all.firstWhere((s) => s.element == element);

  /// Stats at [level] before equipment.
  Stats statsAt(int level) =>
      (base + growth * (level - 1).toDouble()).rounded();
}
