import '../../core/json.dart';

enum FoodSource { usda, openFoodFacts, custom }

extension FoodSourceText on FoodSource {
  String get label => switch (this) {
    FoodSource.usda => 'USDA',
    FoodSource.openFoodFacts => 'Open Food Facts',
    FoodSource.custom => 'My food',
  };
}

/// Nutrients per 100 g of a food.
class Nutrients {
  const Nutrients({
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    this.fiberG = 0,
  });

  static const zero = Nutrients(kcal: 0, proteinG: 0, fatG: 0, carbsG: 0);

  final double kcal;
  final double proteinG;
  final double fatG;
  final double carbsG;
  final double fiberG;

  Nutrients scaled(double factor) => Nutrients(
    kcal: kcal * factor,
    proteinG: proteinG * factor,
    fatG: fatG * factor,
    carbsG: carbsG * factor,
    fiberG: fiberG * factor,
  );

  Nutrients operator +(Nutrients other) => Nutrients(
    kcal: kcal + other.kcal,
    proteinG: proteinG + other.proteinG,
    fatG: fatG + other.fatG,
    carbsG: carbsG + other.carbsG,
    fiberG: fiberG + other.fiberG,
  );

  Map<String, dynamic> toJson() => {
    'kcal': kcal,
    'p': proteinG,
    'f': fatG,
    'c': carbsG,
    'fb': fiberG,
  };

  factory Nutrients.fromJson(Map<String, dynamic> json) => Nutrients(
    kcal: asDouble(json['kcal']),
    proteinG: asDouble(json['p']),
    fatG: asDouble(json['f']),
    carbsG: asDouble(json['c']),
    fiberG: asDouble(json['fb']),
  );
}

/// A named portion, e.g. "1 cup" = 158 g.
class Serving {
  const Serving(this.label, this.grams);

  final String label;
  final double grams;

  Map<String, dynamic> toJson() => {'label': label, 'grams': grams};

  factory Serving.fromJson(Map<String, dynamic> json) =>
      Serving(asString(json['label']), asDouble(json['grams'], 100));
}

class Food {
  const Food({
    required this.id,
    required this.name,
    required this.source,
    required this.per100g,
    this.brand,
    this.category,
    this.servings = const [],
  });

  /// Unique within its source (USDA fdcId, barcode, or a generated id).
  final String id;
  final String name;
  final FoodSource source;
  final Nutrients per100g;
  final String? brand;
  final String? category;
  final List<Serving> servings;

  /// Key that is unique across sources.
  String get key => '${source.name}:$id';

  String get displayName =>
      brand == null || brand!.isEmpty ? name : '$name · $brand';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'source': source.name,
    'per100g': per100g.toJson(),
    if (brand != null) 'brand': brand,
    if (category != null) 'category': category,
    'servings': servings.map((s) => s.toJson()).toList(),
  };

  factory Food.fromJson(Map<String, dynamic> json) => Food(
    id: asString(json['id']),
    name: asString(json['name'], 'Food'),
    source: enumByName(FoodSource.values, json['source'], FoodSource.custom),
    per100g: Nutrients.fromJson(asMap(json['per100g'])),
    brand: json['brand'] as String?,
    category: json['category'] as String?,
    servings: asMapList(json['servings']).map(Serving.fromJson).toList(),
  );
}
