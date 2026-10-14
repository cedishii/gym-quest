import '../../core/json.dart';
import 'food.dart';

enum Meal { breakfast, lunch, dinner, snack }

extension MealText on Meal {
  String get label => switch (this) {
    Meal.breakfast => 'Breakfast',
    Meal.lunch => 'Lunch',
    Meal.dinner => 'Dinner',
    Meal.snack => 'Snacks',
  };
}

/// One logged portion. The food is copied into the entry so the log stays
/// correct even if the source food later changes or disappears.
class FoodLogEntry {
  const FoodLogEntry({
    required this.id,
    required this.day,
    required this.meal,
    required this.food,
    required this.grams,
    required this.loggedAt,
    this.servingLabel,
  });

  static const maxGrams = 5000.0;

  final String id;

  /// Calendar day key (`yyyy-MM-dd`).
  final String day;
  final Meal meal;
  final Food food;
  final double grams;
  final String? servingLabel;
  final DateTime loggedAt;

  Nutrients get nutrients => NutritionMath.forGrams(food.per100g, grams);

  Map<String, dynamic> toJson() => {
    'id': id,
    'day': day,
    'meal': meal.name,
    'food': food.toJson(),
    'grams': grams,
    if (servingLabel != null) 'serving': servingLabel,
    'loggedAt': loggedAt.toIso8601String(),
  };

  factory FoodLogEntry.fromJson(Map<String, dynamic> json) => FoodLogEntry(
    id: asString(json['id']),
    day: asString(json['day']),
    meal: enumByName(Meal.values, json['meal'], Meal.snack),
    food: Food.fromJson(asMap(json['food'])),
    grams: asDouble(json['grams'], 100),
    servingLabel: json['serving'] as String?,
    loggedAt: DateTime.tryParse(asString(json['loggedAt'])) ?? DateTime.now(),
  );
}

class NutritionMath {
  const NutritionMath._();

  static Nutrients forGrams(Nutrients per100g, double grams) =>
      per100g.scaled(grams / 100);

  /// Grams for [quantity] of a serving (e.g. 1.5 x "1 cup" of 158 g).
  static double servingGrams(Serving serving, double quantity) =>
      serving.grams * quantity;

  static Nutrients total(Iterable<FoodLogEntry> entries) =>
      entries.fold(Nutrients.zero, (sum, entry) => sum + entry.nutrients);

  static Map<Meal, Nutrients> byMeal(Iterable<FoodLogEntry> entries) {
    final result = {for (final meal in Meal.values) meal: Nutrients.zero};
    for (final entry in entries) {
      result[entry.meal] = result[entry.meal]! + entry.nutrients;
    }
    return result;
  }

  /// Validates a logged amount; returns an error message or null.
  static String? validateGrams(double? grams) {
    if (grams == null || grams.isNaN) return 'Enter an amount';
    if (grams <= 0) return 'Amount must be more than 0';
    if (grams > FoodLogEntry.maxGrams) return 'That is more than 5 kg';
    return null;
  }
}
