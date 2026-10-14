import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/json.dart';
import '../../domain/nutrition/food.dart';

/// Offline food search over the bundled USDA SR Legacy data
/// (public domain; see tool/build_usda_foods.py).
class UsdaCatalog {
  UsdaCatalog(this.foods)
    : _names = [for (final f in foods) f.name.toLowerCase()];

  final List<Food> foods;
  final List<String> _names;

  static Future<UsdaCatalog> load([AssetBundle? bundle]) async {
    final text = await (bundle ?? rootBundle).loadString(
      'assets/data/foods_usda.json',
    );
    // ~7,000 foods: parse off the UI thread.
    final foods = await compute(_parse, text);
    return UsdaCatalog(foods);
  }

  static List<Food> _parse(String text) => parseJson(text);

  @visibleForTesting
  static List<Food> parseJson(String text) {
    final json = asMap(jsonDecode(text));
    return [
      for (final raw in asMapList(json['foods']))
        Food(
          id: asString(raw['id']),
          name: asString(raw['n']),
          source: FoodSource.usda,
          category: raw['c'] as String?,
          per100g: Nutrients(
            kcal: asDouble(raw['k']),
            proteinG: asDouble(raw['p']),
            fatG: asDouble(raw['f']),
            carbsG: asDouble(raw['cb']),
            fiberG: asDouble(raw['fb']),
          ),
          servings: [
            for (final s in (raw['s'] as List? ?? const []))
              if (s is List && s.length == 2)
                Serving(asString(s[0]), asDouble(s[1])),
          ],
        ),
    ];
  }

  /// Foods whose name contains every word of [query], best matches first:
  /// names starting with the first word, then shorter (more generic) names.
  List<Food> search(String query, {int limit = 60}) {
    final words = query
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return const [];

    final matches = <int>[];
    for (var i = 0; i < _names.length; i++) {
      final name = _names[i];
      if (words.every(name.contains)) matches.add(i);
    }
    int score(int i) {
      final name = _names[i];
      var s = name.length;
      if (name.startsWith(words.first)) s -= 1000;
      if (name.contains(', raw') || name.contains(', cooked')) s -= 5;
      return s;
    }

    matches.sort((a, b) => score(a).compareTo(score(b)));
    return [for (final i in matches.take(limit)) foods[i]];
  }
}
