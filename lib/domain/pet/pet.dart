import 'dart:math';

import '../../config/balance.dart';
import '../../core/json.dart';
import '../combat/element.dart';
import 'species.dart';

class Pet {
  const Pet({
    required this.element,
    required this.name,
    required this.level,
    required this.xp,
    required this.adoptedAt,
  });

  final PetElement element;
  final String name;
  final int level;

  /// XP collected toward the next level.
  final int xp;
  final DateTime adoptedAt;

  Species get species => Species.of(element);
  int get xpToNext => Balance.xpToNext(level);
  bool get isMaxLevel => level >= Balance.maxPetLevel;

  Pet copyWith({String? name, int? level, int? xp}) => Pet(
    element: element,
    name: name ?? this.name,
    level: level ?? this.level,
    xp: xp ?? this.xp,
    adoptedAt: adoptedAt,
  );

  Map<String, dynamic> toJson() => {
    'element': element.name,
    'name': name,
    'level': level,
    'xp': xp,
    'adoptedAt': adoptedAt.toIso8601String(),
  };

  factory Pet.fromJson(Map<String, dynamic> json) => Pet(
    element: enumByName(PetElement.values, json['element'], PetElement.neutral),
    name: asString(json['name'], 'Buddy'),
    level: asInt(json['level'], 1).clamp(1, Balance.maxPetLevel),
    xp: max(0, asInt(json['xp'])),
    adoptedAt: DateTime.tryParse(asString(json['adoptedAt'])) ?? DateTime.now(),
  );
}

class XpResult {
  const XpResult({
    required this.pet,
    required this.levelsGained,
    required this.newAuraTiers,
  });

  final Pet pet;
  final int levelsGained;

  /// Aura tiers unlocked by this XP gain (indexes into Balance.auraTierLevels).
  final List<int> newAuraTiers;
}

class PetProgression {
  const PetProgression._();

  /// Adds [amount] XP, rolling over as many levels as it covers.
  static XpResult addXp(Pet pet, int amount) {
    var level = pet.level;
    var xp = pet.xp + max(0, amount).toInt();
    while (level < Balance.maxPetLevel && xp >= Balance.xpToNext(level)) {
      xp -= Balance.xpToNext(level);
      level++;
    }
    if (level >= Balance.maxPetLevel) xp = 0;
    final before = auraTier(pet.level);
    final after = auraTier(level);
    return XpResult(
      pet: pet.copyWith(level: level, xp: xp),
      levelsGained: level - pet.level,
      newAuraTiers: [for (var t = before + 1; t <= after; t++) t],
    );
  }

  /// Total XP needed to reach [level] from level 1.
  static int totalXpForLevel(int level) {
    var total = 0;
    for (var l = 1; l < level; l++) {
      total += Balance.xpToNext(l);
    }
    return total;
  }

  /// Visual tier: 0 = none, 1 = glow, 2 = aura, 3 = stars, 4 = crown.
  static int auraTier(int level) =>
      Balance.auraTierLevels.where((threshold) => level >= threshold).length;

  /// Sprite scale for [level]: grows until the cap level, then stays.
  static double scale(int level) {
    final t = ((level - 1) / (Balance.petScaleCapLevel - 1)).clamp(0.0, 1.0);
    return Balance.petMinScale +
        (Balance.petMaxScale - Balance.petMinScale) * t;
  }
}
