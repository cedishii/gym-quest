import 'package:flutter/widgets.dart';

import '../data/nutrition/open_food_facts_client.dart';
import '../data/nutrition/usda_catalog.dart';
import '../state/app_state.dart';

/// Long-lived services that are not game state.
class Services {
  Services({
    OpenFoodFactsClient? openFoodFacts,
    Future<UsdaCatalog> Function()? loadUsda,
  }) : openFoodFacts = openFoodFacts ?? OpenFoodFactsClient(),
       _loadUsda = loadUsda ?? UsdaCatalog.load;

  final OpenFoodFactsClient openFoodFacts;
  final Future<UsdaCatalog> Function() _loadUsda;
  Future<UsdaCatalog>? _usda;

  /// The offline food catalog, loaded on first use and then kept.
  Future<UsdaCatalog> get usda => _usda ??= _loadUsda();
}

/// Gives every screen access to [AppState] (rebuilding on change) and [Services].
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState state,
    required this.services,
    required super.child,
  }) : super(notifier: state);

  final Services services;

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Reads the state without subscribing to changes (for callbacks).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static Services servicesOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.services;
}

extension AppContext on BuildContext {
  AppState get app => AppScope.of(this);
  AppState get appRead => AppScope.read(this);
  Services get services => AppScope.servicesOf(this);
}
