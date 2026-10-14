import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_rpg/data/nutrition/open_food_facts_client.dart';
import 'package:gym_rpg/data/nutrition/usda_catalog.dart';
import 'package:gym_rpg/domain/nutrition/food.dart';
import 'package:gym_rpg/domain/nutrition/food_log.dart';

const rice = Food(
  id: '1',
  name: 'Rice, white, cooked',
  source: FoodSource.usda,
  per100g: Nutrients(
    kcal: 130,
    proteinG: 2.7,
    fatG: 0.3,
    carbsG: 28.2,
    fiberG: 0.4,
  ),
  servings: [Serving('1 cup', 158)],
);

FoodLogEntry entry(Meal meal, double grams) => FoodLogEntry(
  id: '$meal$grams',
  day: '2026-10-01',
  meal: meal,
  food: rice,
  grams: grams,
  loggedAt: DateTime(2026, 10, 1),
);

void main() {
  test('nutrients scale with grams', () {
    final n = NutritionMath.forGrams(rice.per100g, 250);
    expect(n.kcal, closeTo(325, 0.001));
    expect(n.carbsG, closeTo(70.5, 0.001));
  });

  test('serving size converts to grams', () {
    expect(
      NutritionMath.servingGrams(rice.servings.first, 1.5),
      closeTo(237, 0.001),
    );
  });

  test('daily and per-meal totals add up', () {
    final entries = [
      entry(Meal.breakfast, 100),
      entry(Meal.lunch, 200),
      entry(Meal.lunch, 50),
    ];
    expect(NutritionMath.total(entries).kcal, closeTo(455, 0.001));
    final byMeal = NutritionMath.byMeal(entries);
    expect(byMeal[Meal.lunch]!.kcal, closeTo(325, 0.001));
    expect(byMeal[Meal.dinner]!.kcal, 0);
  });

  test('gram validation', () {
    expect(NutritionMath.validateGrams(0), isNotNull);
    expect(NutritionMath.validateGrams(null), isNotNull);
    expect(NutritionMath.validateGrams(6000), isNotNull);
    expect(NutritionMath.validateGrams(120), isNull);
  });

  test('bundled USDA catalog parses and searches', () {
    final foods = UsdaCatalog.parseJson(
      File('assets/data/foods_usda.json').readAsStringSync(),
    );
    expect(foods.length, greaterThan(7000));
    final catalog = UsdaCatalog(foods);
    final results = catalog.search('chicken breast roasted');
    expect(results, isNotEmpty);
    expect(results.first.name.toLowerCase(), contains('chicken'));
    expect(catalog.search('   '), isEmpty);
    final egg = catalog.search('egg whole hard-boiled').first;
    expect(egg.per100g.kcal, closeTo(155, 1));
  });

  test('Open Food Facts products convert, including kJ-only energy', () {
    final food = OpenFoodFactsClient.parseProduct({
      'code': '123',
      'product_name': 'Test Bar',
      'brands': 'Acme, Other',
      'serving_quantity': 40,
      'serving_size': '40 g',
      'nutriments': {
        'energy_100g': 1674,
        'proteins_100g': 20,
        'fat_100g': 10,
        'carbohydrates_100g': 50,
      },
    })!;
    expect(food.per100g.kcal, closeTo(400, 0.5));
    expect(food.brand, 'Acme');
    expect(food.servings.single.grams, 40);
    expect(
      OpenFoodFactsClient.parseProduct({
        'product_name': 'No energy',
        'nutriments': {},
      }),
      isNull,
    );
  });
}
