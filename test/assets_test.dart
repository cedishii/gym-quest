import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_rpg/audio/sound_service.dart';
import 'package:gym_rpg/domain/inventory/items.dart';
import 'package:gym_rpg/domain/map/stages.dart';
import 'package:gym_rpg/domain/pet/pet_food.dart';
import 'package:gym_rpg/domain/pet/species.dart';
import 'package:gym_rpg/domain/progression/achievements.dart';

import 'helpers.dart';

/// Every asset path the code refers to must exist and be bundled.
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  bool bundled(String path) {
    final dir = path.substring(0, path.lastIndexOf('/') + 1);
    return pubspec.contains('- $dir');
  }

  void expectAsset(String path) {
    expect(File(path).existsSync(), isTrue, reason: 'missing file $path');
    expect(bundled(path), isTrue, reason: 'not listed in pubspec: $path');
  }

  test('exercise photos exist and are bundled', () {
    for (final e in loadExercises().exercises) {
      expect(e.images, isNotEmpty, reason: e.id);
      e.images.forEach(expectAsset);
    }
  });

  test('pet, leader and trainer art exists', () {
    for (final s in Species.all) {
      expectAsset(s.asset);
    }
    for (final stage in GameMap.stages) {
      if (stage.portrait != null) expectAsset(stage.portrait!);
    }
  });

  test('every icon name used by game data exists', () {
    final names = <String>{
      for (final i in ItemCatalog.all) i.icon,
      for (final s in EquipSlot.values) s.icon,
      for (final f in PetFood.values) f.icon,
      for (final a in Achievements.all) a.icon,
    };
    for (final n in names) {
      expectAsset('assets/icons/$n.svg');
    }
  });

  test('sound effects exist', () {
    for (final s in Sfx.values) {
      expectAsset('assets/${s.asset}');
    }
    expectAsset('assets/audio/music/the_world_at_your_door.mp3');
  });

  test('credits manifest is valid and covers bundled folders', () {
    final manifest = jsonDecode(
      File('assets/credits/asset_manifest.json').readAsStringSync(),
    ) as Map;
    final sources = (manifest['sources'] as List).cast<Map>();
    expect(sources, isNotEmpty);
    for (final s in sources) {
      for (final key in [
        'id',
        'title',
        'author',
        'url',
        'license',
        'attribution',
      ]) {
        expect(
          (s[key] as String?)?.isNotEmpty ?? false,
          isTrue,
          reason: '${s['id']} lacks $key',
        );
      }
    }
    final software = (manifest['software'] as List).cast<Map>();
    expect(software.map((s) => s['name']), contains('flutter_svg'));
    for (final s in software) {
      expect((s['license'] as String).isNotEmpty, isTrue);
    }
    final covered = sources
        .expand((s) => (s['files'] as List).cast<String>())
        .join('\n');
    for (final folder in [
      'assets/pets/',
      'assets/leaders/',
      'assets/icons/',
      'assets/fx/',
      'assets/audio/sfx/',
      'assets/exercises/',
    ]) {
      expect(
        covered.contains(folder),
        isTrue,
        reason: '$folder has no credits entry',
      );
    }
  });
}
