import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../../core/json.dart';
import '../../domain/nutrition/food.dart';

/// Thrown with a message that can be shown to the user as-is.
class FoodLookupException implements Exception {
  const FoodLookupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Read-only Open Food Facts client (product data ODbL).
///
/// Respects the published limits: searches only when the user submits
/// (never as-you-type), and keeps a minimum gap between calls.
class OpenFoodFactsClient {
  OpenFoodFactsClient({http.Client? client, DateTime Function()? clock})
    : _client = client ?? http.Client(),
      _clock = clock ?? DateTime.now;

  final http.Client _client;
  final DateTime Function() _clock;
  DateTime? _lastSearch;
  DateTime? _lastProduct;

  static const _fields =
      'code,product_name,brands,nutriments,serving_size,serving_quantity';

  Map<String, String> get _headers => kIsWeb
      // Browsers do not allow setting User-Agent; the app name goes in the query.
      ? const {'Accept': 'application/json'}
      : const {
          'Accept': 'application/json',
          'User-Agent': AppConfig.offUserAgent,
        };

  /// Time to wait before another search is allowed, or zero.
  Duration get searchCooldown =>
      _remaining(_lastSearch, AppConfig.offSearchInterval);

  Duration get productCooldown =>
      _remaining(_lastProduct, AppConfig.offProductInterval);

  Duration _remaining(DateTime? last, Duration interval) {
    if (last == null) return Duration.zero;
    final left = interval - _clock().difference(last);
    return left.isNegative ? Duration.zero : left;
  }

  Future<List<Food>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      throw const FoodLookupException('Type at least 2 letters');
    }
    final wait = searchCooldown;
    if (wait > Duration.zero) {
      throw FoodLookupException(
        'Open Food Facts allows a few searches per minute. Try again in ${wait.inSeconds + 1}s.',
      );
    }
    _lastSearch = _clock();
    final uri = Uri.parse('${AppConfig.offBaseUrl}/cgi/search.pl').replace(
      queryParameters: {
        'search_terms': trimmed,
        'search_simple': '1',
        'action': 'process',
        'json': '1',
        'page_size': '24',
        'fields': _fields,
        'app_name': 'GymQuest',
      },
    );
    final json = await _get(uri);
    return asMapList(json['products'])
        .map(parseProduct)
        .whereType<Food>()
        .toList();
  }

  /// Looks up a barcode. Returns null when the product is unknown.
  Future<Food?> barcode(String code) async {
    final digits = code.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{6,14}$').hasMatch(digits)) {
      throw const FoodLookupException('A barcode has 6–14 digits');
    }
    final wait = productCooldown;
    if (wait > Duration.zero) {
      throw FoodLookupException(
        'Please wait ${wait.inSeconds + 1}s before the next lookup.',
      );
    }
    _lastProduct = _clock();
    final uri = Uri.parse('${AppConfig.offBaseUrl}/api/v2/product/$digits.json')
        .replace(queryParameters: {'fields': _fields, 'app_name': 'GymQuest'});
    final json = await _get(uri, allowNotFound: true);
    if (asInt(json['status']) != 1) return null;
    final product = asMap(json['product']);
    product['code'] ??= digits;
    return parseProduct(product);
  }

  Future<Map<String, dynamic>> _get(
    Uri uri, {
    bool allowNotFound = false,
  }) async {
    http.Response response;
    try {
      response = await _client
          .get(uri, headers: _headers)
          .timeout(AppConfig.networkTimeout);
    } on Exception {
      throw const FoodLookupException(
        'Could not reach Open Food Facts. Check your connection, or use the offline USDA list.',
      );
    }
    if (response.statusCode == 429 || response.statusCode == 503) {
      throw const FoodLookupException(
        'Open Food Facts is busy. Try again in a minute.',
      );
    }
    if (response.statusCode == 404 && allowNotFound) return const {'status': 0};
    if (response.statusCode != 200) {
      throw FoodLookupException(
        'Open Food Facts error (${response.statusCode}).',
      );
    }
    try {
      return asMap(jsonDecode(utf8.decode(response.bodyBytes)));
    } on FormatException {
      throw const FoodLookupException(
        'Open Food Facts sent an unreadable reply.',
      );
    }
  }

  /// Converts a product to a [Food], or null when it lacks energy data.
  static Food? parseProduct(Map<String, dynamic> p) {
    final name = asString(p['product_name']).trim();
    final n = asMap(p['nutriments']);
    double? kcal = _num(n['energy-kcal_100g']);
    if (kcal == null) {
      final kj = _num(n['energy_100g']) ?? _num(n['energy-kj_100g']);
      if (kj != null) kcal = kj / 4.184;
    }
    if (name.isEmpty || kcal == null) return null;
    final servingGrams = _num(p['serving_quantity']);
    final servingLabel = asString(p['serving_size']).trim();
    return Food(
      id: asString(p['code']),
      name: name,
      brand: asString(p['brands']).split(',').first.trim(),
      source: FoodSource.openFoodFacts,
      per100g: Nutrients(
        kcal: kcal,
        proteinG: _num(n['proteins_100g']) ?? 0,
        fatG: _num(n['fat_100g']) ?? 0,
        carbsG: _num(n['carbohydrates_100g']) ?? 0,
        fiberG: _num(n['fiber_100g']) ?? 0,
      ),
      servings: [
        if (servingGrams != null && servingGrams > 0)
          Serving(
            servingLabel.isEmpty ? '1 serving' : '1 serving ($servingLabel)',
            servingGrams,
          ),
      ],
    );
  }

  static double? _num(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
