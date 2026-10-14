import 'package:flutter_test/flutter_test.dart';
import 'package:gym_rpg/config/balance.dart';
import 'package:gym_rpg/domain/combat/element.dart';
import 'package:gym_rpg/domain/inventory/equipment.dart';
import 'package:gym_rpg/domain/inventory/items.dart';
import 'package:gym_rpg/domain/pet/pet.dart';
import 'package:gym_rpg/domain/pet/species.dart';

Pet pet({int level = 1, int xp = 0}) => Pet(
  element: PetElement.fire,
  name: 'Blaze',
  level: level,
  xp: xp,
  adoptedAt: DateTime(2026),
);

void main() {
  group('leveling', () {
    test('XP below the threshold does not level up', () {
      final r = PetProgression.addXp(pet(), Balance.xpToNext(1) - 1);
      expect(r.pet.level, 1);
      expect(r.levelsGained, 0);
    });

    test('XP rolls over several levels', () {
      final needed = Balance.xpToNext(1) + Balance.xpToNext(2) + 5;
      final r = PetProgression.addXp(pet(), needed);
      expect(r.pet.level, 3);
      expect(r.pet.xp, 5);
      expect(r.levelsGained, 2);
    });

    test('reaching an aura level reports the new tier', () {
      final r = PetProgression.addXp(pet(level: 9), Balance.xpToNext(9));
      expect(r.pet.level, 10);
      expect(r.newAuraTiers, [1]);
    });

    test('stops at max level', () {
      final r = PetProgression.addXp(
        pet(level: Balance.maxPetLevel - 1),
        1 << 20,
      );
      expect(r.pet.level, Balance.maxPetLevel);
      expect(r.pet.xp, 0);
    });

    test('sprite scale grows then caps', () {
      expect(PetProgression.scale(1), Balance.petMinScale);
      expect(
        PetProgression.scale(Balance.petScaleCapLevel),
        closeTo(Balance.petMaxScale, 1e-9),
      );
      expect(PetProgression.scale(80), closeTo(Balance.petMaxScale, 1e-9));
      expect(
        PetProgression.scale(15),
        inExclusiveRange(Balance.petMinScale, Balance.petMaxScale),
      );
    });
  });

  test('species stats grow with level', () {
    final s = Species.of(PetElement.rock);
    expect(s.statsAt(1).hp, 54);
    expect(s.statsAt(11).hp, 54 + 85);
    expect(s.statsAt(11).defense, (14 + 24).toDouble());
  });

  group('equipment', () {
    test('flat bonuses add, percent bonuses multiply', () {
      final p = pet(level: 5);
      final base = p.species.statsAt(5);
      final ring = ItemCatalog.byId('ring_diamond')!; // +6 atk, +6% atk
      final boots = ItemCatalog.byId('boots_trail')!; // +2 spd
      final stats = Equipment.petStats(p, [ring, boots]);
      expect(stats.attack, ((base.attack + 6) * 1.06).roundToDouble());
      expect(stats.speed, base.speed + 2);
      expect(stats.hp, base.hp);
    });

    test('resolve ignores missing items and wrong slots', () {
      final inventory = [
        OwnedItem(
          instanceId: 'a',
          itemId: 'ring_copper',
          obtainedAt: DateTime(2026),
        ),
        OwnedItem(
          instanceId: 'b',
          itemId: 'boots_trail',
          obtainedAt: DateTime(2026),
        ),
      ];
      final resolved = Equipment.resolve({
        EquipSlot.ring: 'a',
        EquipSlot.helmet: 'b', // boots in the helmet slot: ignored
        EquipSlot.armor: 'missing',
      }, inventory);
      expect(resolved.map((d) => d.id), ['ring_copper']);
    });

    test('every catalog item has a unique id and a known icon slot', () {
      final ids = ItemCatalog.all.map((i) => i.id).toSet();
      expect(ids.length, ItemCatalog.all.length);
      for (final slot in EquipSlot.values) {
        expect(ItemCatalog.all.where((i) => i.slot == slot), isNotEmpty);
      }
    });
  });
}
