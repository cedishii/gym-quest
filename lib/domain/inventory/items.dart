import '../../core/json.dart';
import '../pet/stats.dart';

enum EquipSlot { helmet, armor, boots, ring, amulet }

extension EquipSlotText on EquipSlot {
  String get label => switch (this) {
    EquipSlot.helmet => 'Helmet',
    EquipSlot.armor => 'Armor',
    EquipSlot.boots => 'Boots',
    EquipSlot.ring => 'Ring',
    EquipSlot.amulet => 'Amulet',
  };

  /// Icon shown on an empty slot.
  String get icon => switch (this) {
    EquipSlot.helmet => 'visored-helm',
    EquipSlot.armor => 'leather-armor',
    EquipSlot.boots => 'boots',
    EquipSlot.ring => 'ring',
    EquipSlot.amulet => 'gem-pendant',
  };
}

enum Rarity { common, rare, epic }

extension RarityText on Rarity {
  String get label => switch (this) {
    Rarity.common => 'Common',
    Rarity.rare => 'Rare',
    Rarity.epic => 'Epic',
  };
}

/// An equipment definition. Items change stats only; they appear as icons
/// in the equipment slots, not drawn on the pet.
class ItemDef {
  const ItemDef({
    required this.id,
    required this.name,
    required this.slot,
    required this.rarity,
    required this.icon,
    this.flat = Stats.zero,
    this.percent = Stats.zero,
  });

  final String id;
  final String name;
  final EquipSlot slot;
  final Rarity rarity;
  final String icon;

  /// Added to the pet's stats.
  final Stats flat;

  /// Then multiplied in (0.05 = +5%).
  final Stats percent;

  String get effectLabel {
    final parts = <String>[];
    void add(String name, double flatValue, double pctValue) {
      if (flatValue != 0) parts.add('+${flatValue.round()} $name');
      if (pctValue != 0) parts.add('+${(pctValue * 100).round()}% $name');
    }

    add('HP', flat.hp, percent.hp);
    add('ATK', flat.attack, percent.attack);
    add('DEF', flat.defense, percent.defense);
    add('SPD', flat.speed, percent.speed);
    return parts.join(', ');
  }
}

/// All equipment in the game. Rewards refer to items by id.
class ItemCatalog {
  const ItemCatalog._();

  static const all = <ItemDef>[
    // Helmets
    ItemDef(
      id: 'cap_padded',
      name: 'Padded Cap',
      slot: EquipSlot.helmet,
      rarity: Rarity.common,
      icon: 'barbute',
      flat: Stats(defense: 2, hp: 5),
    ),
    ItemDef(
      id: 'helm_iron',
      name: 'Iron Visor',
      slot: EquipSlot.helmet,
      rarity: Rarity.rare,
      icon: 'visored-helm',
      flat: Stats(defense: 4, hp: 12),
    ),
    ItemDef(
      id: 'helm_crest',
      name: 'Champion Crest',
      slot: EquipSlot.helmet,
      rarity: Rarity.epic,
      icon: 'crested-helmet',
      flat: Stats(defense: 6, hp: 20),
      percent: Stats(attack: 0.04),
    ),
    // Armor
    ItemDef(
      id: 'armor_vest',
      name: 'Training Vest',
      slot: EquipSlot.armor,
      rarity: Rarity.common,
      icon: 'leather-armor',
      flat: Stats(hp: 12, defense: 1),
    ),
    ItemDef(
      id: 'armor_chain',
      name: 'Guard Mail',
      slot: EquipSlot.armor,
      rarity: Rarity.rare,
      icon: 'chest-armor',
      flat: Stats(hp: 20, defense: 4),
    ),
    ItemDef(
      id: 'armor_plate',
      name: 'Titan Plate',
      slot: EquipSlot.armor,
      rarity: Rarity.epic,
      icon: 'breastplate',
      flat: Stats(hp: 30, defense: 6),
      percent: Stats(hp: 0.06),
    ),
    // Boots
    ItemDef(
      id: 'boots_trail',
      name: 'Trail Boots',
      slot: EquipSlot.boots,
      rarity: Rarity.common,
      icon: 'walking-boot',
      flat: Stats(speed: 2),
    ),
    ItemDef(
      id: 'boots_runner',
      name: 'Runner Boots',
      slot: EquipSlot.boots,
      rarity: Rarity.rare,
      icon: 'leather-boot',
      flat: Stats(speed: 4, defense: 1),
    ),
    ItemDef(
      id: 'boots_wind',
      name: 'Windstep Boots',
      slot: EquipSlot.boots,
      rarity: Rarity.epic,
      icon: 'boots',
      flat: Stats(speed: 6, defense: 2),
      percent: Stats(speed: 0.05),
    ),
    // Rings
    ItemDef(
      id: 'ring_copper',
      name: 'Copper Ring',
      slot: EquipSlot.ring,
      rarity: Rarity.common,
      icon: 'ring',
      flat: Stats(attack: 2),
    ),
    ItemDef(
      id: 'ring_power',
      name: 'Power Ring',
      slot: EquipSlot.ring,
      rarity: Rarity.rare,
      icon: 'power-ring',
      flat: Stats(attack: 4, speed: 1),
    ),
    ItemDef(
      id: 'ring_diamond',
      name: 'Diamond Ring',
      slot: EquipSlot.ring,
      rarity: Rarity.epic,
      icon: 'diamond-ring',
      flat: Stats(attack: 6),
      percent: Stats(attack: 0.06),
    ),
    // Amulets
    ItemDef(
      id: 'amulet_charm',
      name: 'Lucky Charm',
      slot: EquipSlot.amulet,
      rarity: Rarity.common,
      icon: 'gem-pendant',
      flat: Stats(hp: 8, speed: 1),
    ),
    ItemDef(
      id: 'amulet_heart',
      name: 'Heart Pendant',
      slot: EquipSlot.amulet,
      rarity: Rarity.rare,
      icon: 'heart-plus',
      flat: Stats(hp: 18, attack: 2),
    ),
    ItemDef(
      id: 'amulet_gauntlet',
      name: 'Iron Will',
      slot: EquipSlot.amulet,
      rarity: Rarity.epic,
      icon: 'gauntlet',
      flat: Stats(hp: 15, attack: 3, defense: 3),
      percent: Stats(defense: 0.05),
    ),
  ];

  static ItemDef? byId(String id) {
    for (final item in all) {
      if (item.id == id) return item;
    }
    return null;
  }

  static List<ItemDef> ofRarity(Rarity rarity) =>
      all.where((item) => item.rarity == rarity).toList();
}

/// One owned copy of an item. Copies are separate so duplicates can exist.
class OwnedItem {
  const OwnedItem({
    required this.instanceId,
    required this.itemId,
    required this.obtainedAt,
  });

  final String instanceId;
  final String itemId;
  final DateTime obtainedAt;

  ItemDef? get def => ItemCatalog.byId(itemId);

  Map<String, dynamic> toJson() => {
    'id': instanceId,
    'item': itemId,
    'at': obtainedAt.toIso8601String(),
  };

  factory OwnedItem.fromJson(Map<String, dynamic> json) => OwnedItem(
    instanceId: asString(json['id']),
    itemId: asString(json['item']),
    obtainedAt: DateTime.tryParse(asString(json['at'])) ?? DateTime.now(),
  );
}
