import '../../core/json.dart';
import '../pet/pet_food.dart';

/// A bundle of things granted to the player: pet food and/or items.
class Reward {
  const Reward({
    this.food = const {},
    this.items = const [],
    this.reasons = const [],
  });

  static const none = Reward();

  final Map<PetFood, int> food;

  /// Item ids (see ItemCatalog).
  final List<String> items;

  /// Human-readable lines explaining each part of the reward.
  final List<String> reasons;

  bool get isEmpty => food.values.every((n) => n <= 0) && items.isEmpty;

  int count(PetFood f) => food[f] ?? 0;

  Reward operator +(Reward other) {
    final merged = Map<PetFood, int>.from(food);
    other.food.forEach(
      (key, value) => merged[key] = (merged[key] ?? 0) + value,
    );
    return Reward(
      food: merged,
      items: [...items, ...other.items],
      reasons: [...reasons, ...other.reasons],
    );
  }

  Map<String, dynamic> toJson() => {
    'food': {for (final e in food.entries) e.key.name: e.value},
    'items': items,
    'reasons': reasons,
  };

  factory Reward.fromJson(Map<String, dynamic> json) {
    final food = <PetFood, int>{};
    asMap(json['food']).forEach((key, value) {
      for (final f in PetFood.values) {
        if (f.name == key) food[f] = asInt(value);
      }
    });
    return Reward(
      food: food,
      items: List<String>.from(json['items'] ?? const []),
      reasons: List<String>.from(json['reasons'] ?? const []),
    );
  }
}
