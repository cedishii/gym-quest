import '../pet/pet.dart';
import '../pet/stats.dart';
import 'items.dart';

class Equipment {
  const Equipment._();

  /// Sum of flat and percent bonuses from the equipped items.
  static ({Stats flat, Stats percent}) bonuses(Iterable<ItemDef> equipped) {
    var flat = Stats.zero;
    var percent = Stats.zero;
    for (final item in equipped) {
      flat = flat + item.flat;
      percent = percent + item.percent;
    }
    return (flat: flat, percent: percent);
  }

  /// Final battle stats: (level stats + flat bonuses) x (1 + percent bonuses).
  static Stats petStats(Pet pet, Iterable<ItemDef> equipped) {
    final b = bonuses(equipped);
    return (pet.species.statsAt(pet.level) + b.flat)
        .withPercent(b.percent)
        .rounded();
  }

  /// Resolves equipped instance ids to item definitions, ignoring ids that
  /// no longer exist in the inventory or catalog.
  static List<ItemDef> resolve(
    Map<EquipSlot, String> equipped,
    List<OwnedItem> inventory,
  ) {
    final byId = {for (final item in inventory) item.instanceId: item};
    final result = <ItemDef>[];
    for (final entry in equipped.entries) {
      final def = byId[entry.value]?.def;
      if (def != null && def.slot == entry.key) result.add(def);
    }
    return result;
  }
}
