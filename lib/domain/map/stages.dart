import '../../config/balance.dart';
import '../../core/json.dart';
import '../combat/battle.dart';
import '../combat/element.dart';
import '../inventory/items.dart';
import '../pet/pet_food.dart';
import '../pet/species.dart';
import '../rewards/reward.dart';

enum StageKind { wild, trainer, leader }

class Region {
  const Region({
    required this.name,
    required this.element,
    required this.leaderName,
    required this.leaderTitle,
    required this.leaderPortrait,
    required this.leaderPetName,
    required this.badgeName,
    required this.intro,
  });

  final String name;
  final PetElement element;
  final String leaderName;
  final String leaderTitle;
  final String leaderPortrait;
  final String leaderPetName;
  final String badgeName;
  final String intro;
}

class Stage {
  const Stage({
    required this.index,
    required this.region,
    required this.kind,
    required this.element,
    required this.level,
    required this.opponentName,
    required this.monsterName,
    required this.reward,
    this.portrait,
  });

  /// 0-based position on the map path.
  final int index;
  final Region region;
  final StageKind kind;
  final PetElement element;
  final int level;

  /// Trainer or leader name, or the wild monster's name.
  final String opponentName;
  final String monsterName;

  /// Granted on the first clear only.
  final Reward reward;
  final String? portrait;

  double get statMultiplier => switch (kind) {
    StageKind.wild => Balance.wildStatMultiplier,
    StageKind.trainer => Balance.trainerStatMultiplier,
    StageKind.leader => Balance.leaderStatMultiplier,
  };

  double get hpMultiplier =>
      kind == StageKind.leader ? Balance.leaderHpMultiplier : 1.0;

  Combatant enemy() => Opponents.build(
    name: monsterName,
    element: element,
    level: level,
    statMultiplier: statMultiplier,
    hpMultiplier: hpMultiplier,
  );
}

class Opponents {
  const Opponents._();

  static Combatant build({
    required String name,
    required PetElement element,
    required int level,
    required double statMultiplier,
    required double hpMultiplier,
  }) {
    final base = Species.of(element).statsAt(level) * statMultiplier;
    final stats = base.copyWithHp(base.hp * hpMultiplier).rounded();
    return Combatant.fromStats(
      name: name,
      element: element,
      level: level,
      stats: stats,
    );
  }
}

class GameMap {
  const GameMap._();

  static const regions = <Region>[
    Region(
      name: 'Verdant Grove',
      element: PetElement.leaf,
      leaderName: 'Mira',
      leaderTitle: 'Grove Keeper',
      leaderPortrait: 'assets/leaders/leader_leaf.png',
      leaderPetName: 'Thornback',
      badgeName: 'Sprout Badge',
      intro: 'A quiet forest where every step is a warm-up.',
    ),
    Region(
      name: 'Tidewater Coast',
      element: PetElement.water,
      leaderName: 'Ren',
      leaderTitle: 'Harbor Captain',
      leaderPortrait: 'assets/leaders/leader_water.png',
      leaderPetName: 'Riptide',
      badgeName: 'Wave Badge',
      intro: 'Salt air and endless shoreline sprints.',
    ),
    Region(
      name: 'Granite Peaks',
      element: PetElement.rock,
      leaderName: 'Tomas',
      leaderTitle: 'Mountain Warden',
      leaderPortrait: 'assets/leaders/leader_rock.png',
      leaderPetName: 'Boulderhide',
      badgeName: 'Summit Badge',
      intro: 'Steep climbs that test real strength.',
    ),
    Region(
      name: 'Ember Caldera',
      element: PetElement.fire,
      leaderName: 'Dario',
      leaderTitle: 'Forge Master',
      leaderPortrait: 'assets/leaders/leader_fire.png',
      leaderPetName: 'Cinderfang',
      badgeName: 'Blaze Badge',
      intro: 'A volcano where only the disciplined survive the heat.',
    ),
    Region(
      name: 'Skyreach Arena',
      element: PetElement.neutral,
      leaderName: 'Aiko',
      leaderTitle: 'Arena Champion',
      leaderPortrait: 'assets/leaders/leader_neutral.png',
      leaderPetName: 'Paragon',
      badgeName: 'Champion Badge',
      intro: 'The final arena above the clouds.',
    ),
  ];

  static const _trainers = [
    ('Kai', 'assets/leaders/trainer_b.png'),
    ('Juno', 'assets/leaders/trainer_a.png'),
    ('Lexi', 'assets/leaders/trainer_c.png'),
  ];

  /// First-clear items for the stages of each region (stages 1 and 2; the
  /// leader's item is separate). Chosen so every slot shows up early.
  static const _stageItems = [
    ['ring_copper', 'boots_trail'],
    ['cap_padded', 'armor_vest'],
    ['amulet_charm', 'ring_power'],
    ['boots_runner', 'helm_iron'],
    ['armor_chain', 'amulet_heart'],
  ];

  static const _leaderItems = [
    'ring_power',
    'armor_chain',
    'boots_wind',
    'ring_diamond',
    'helm_crest',
  ];

  /// Elements of the non-leader monsters in each region: mostly the home
  /// element, with one visitor so type matchups matter.
  static PetElement _wildElement(int region, int slot) {
    final home = regions[region].element;
    if (slot != 1) return home;
    const visitors = [
      PetElement.water,
      PetElement.rock,
      PetElement.leaf,
      PetElement.neutral,
      PetElement.fire,
    ];
    return visitors[region];
  }

  static const stagesPerRegion = 4;

  static final List<Stage> stages = _build();

  static int get lastStoryIndex => stages.length - 1;

  static List<Stage> _build() {
    final result = <Stage>[];
    for (var r = 0; r < regions.length; r++) {
      final region = regions[r];
      for (var s = 0; s < stagesPerRegion; s++) {
        final index = r * stagesPerRegion + s;
        final level = Balance.stageEnemyLevel(index);
        if (s == stagesPerRegion - 1) {
          result.add(
            Stage(
              index: index,
              region: region,
              kind: StageKind.leader,
              element: region.element,
              level: level,
              opponentName: '${region.leaderTitle} ${region.leaderName}',
              monsterName: region.leaderPetName,
              portrait: region.leaderPortrait,
              reward: Reward(
                food: const {PetFood.feast: 1},
                items: [_leaderItems[r]],
                reasons: ['Defeated ${region.leaderName}: ${region.badgeName}'],
              ),
            ),
          );
          continue;
        }
        final element = _wildElement(r, s);
        final species = Species.of(element);
        if (s == 0) {
          result.add(
            Stage(
              index: index,
              region: region,
              kind: StageKind.wild,
              element: element,
              level: level,
              opponentName: 'Wild ${species.name}',
              monsterName: 'Wild ${species.name}',
              reward: Reward(
                food: const {PetFood.kibble: 2},
                items: [_stageItems[r][0]],
                reasons: const ['First clear'],
              ),
            ),
          );
        } else {
          final trainer = _trainers[(r + s) % _trainers.length];
          result.add(
            Stage(
              index: index,
              region: region,
              kind: StageKind.trainer,
              element: element,
              level: level,
              opponentName: 'Trainer ${trainer.$1}',
              monsterName: "${trainer.$1}'s ${species.name}",
              portrait: trainer.$2,
              reward: Reward(
                food: const {PetFood.kibble: 3},
                items: [_stageItems[r][1]],
                reasons: const ['First clear'],
              ),
            ),
          );
        }
      }
    }
    return result;
  }

  // ------------------------------------------------------- endless mode --

  static const _endlessOrder = [
    PetElement.neutral,
    PetElement.fire,
    PetElement.water,
    PetElement.leaf,
    PetElement.rock,
  ];

  /// Opponent on endless floor [floor] (1-based). HP rises a little on every
  /// floor; level rises every few floors.
  static Combatant endlessEnemy(int floor) {
    final n = floor < 1 ? 1 : floor;
    final element = _endlessOrder[(n - 1) % _endlessOrder.length];
    return Opponents.build(
      name: 'Tower Guardian ${Species.of(element).name}',
      element: element,
      level:
          Balance.endlessBaseLevel + (n - 1) ~/ Balance.endlessFloorsPerLevel,
      statMultiplier: Balance.leaderStatMultiplier,
      hpMultiplier: 1 + Balance.endlessHpGrowthPerFloor * (n - 1),
    );
  }

  /// Reward for clearing endless floor [floor] (an item every few floors).
  static Reward endlessReward(int floor) {
    if (floor % Balance.endlessItemEveryFloors != 0) return Reward.none;
    final pool = ItemCatalog.ofRarity(
      (floor ~/ Balance.endlessItemEveryFloors).isEven
          ? Rarity.epic
          : Rarity.rare,
    );
    final item = pool[(floor ~/ Balance.endlessItemEveryFloors) % pool.length];
    return Reward(items: [item.id], reasons: ['Endless floor $floor cleared']);
  }
}

class MapProgress {
  const MapProgress({
    this.cleared = const {},
    this.endlessFloor = 1,
    this.bestEndlessFloor = 0,
  });

  /// Indexes of cleared story stages.
  final Set<int> cleared;

  /// Next endless floor to fight.
  final int endlessFloor;

  /// Highest endless floor cleared.
  final int bestEndlessFloor;

  bool isUnlocked(int index) => index == 0 || cleared.contains(index - 1);
  bool isCleared(int index) => cleared.contains(index);

  /// The first stage not yet cleared (the "current" node on the map).
  int get currentIndex {
    for (var i = 0; i < GameMap.stages.length; i++) {
      if (!cleared.contains(i)) return i;
    }
    return GameMap.stages.length;
  }

  bool get endlessUnlocked => cleared.contains(GameMap.lastStoryIndex);

  int get badges => GameMap.stages
      .where((s) => s.kind == StageKind.leader && cleared.contains(s.index))
      .length;

  MapProgress withCleared(int index) => MapProgress(
    cleared: {...cleared, index},
    endlessFloor: endlessFloor,
    bestEndlessFloor: bestEndlessFloor,
  );

  MapProgress withEndlessCleared(int floor) => MapProgress(
    cleared: cleared,
    endlessFloor: floor + 1,
    bestEndlessFloor: floor > bestEndlessFloor ? floor : bestEndlessFloor,
  );

  Map<String, dynamic> toJson() => {
    'cleared': cleared.toList()..sort(),
    'endlessFloor': endlessFloor,
    'bestEndless': bestEndlessFloor,
  };

  factory MapProgress.fromJson(Map<String, dynamic> json) => MapProgress(
    cleared: {for (final v in (json['cleared'] as List? ?? const [])) asInt(v)},
    endlessFloor: asInt(json['endlessFloor'], 1).clamp(1, 1 << 30),
    bestEndlessFloor: asInt(json['bestEndless']),
  );
}
