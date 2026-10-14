import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../audio/sound_service.dart';
import '../../../data/nutrition/open_food_facts_client.dart';
import '../../../data/nutrition/usda_catalog.dart';
import '../../../domain/nutrition/food.dart';
import '../../../domain/nutrition/food_log.dart';
import '../../../domain/rewards/reward.dart';
import '../../theme/tokens.dart';
import '../../widgets/feedback.dart';
import '../../widgets/panel.dart';
import 'add_food_sheet.dart';
import 'custom_food_screen.dart';
import 'food_screen.dart';

class FoodSearchScreen extends StatefulWidget {
  const FoodSearchScreen({super.key, required this.day, required this.meal});

  final String day;
  final Meal meal;

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Add to ${widget.meal.label}'),
          bottom: const TabBar(
            indicatorColor: Palette.gold,
            labelColor: Palette.gold,
            unselectedLabelColor: Palette.textDim,
            tabs: [
              Tab(text: 'Food list'),
              Tab(text: 'Online'),
              Tab(text: 'My foods'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OfflineTab(day: widget.day, meal: widget.meal),
            _OnlineTab(day: widget.day, meal: widget.meal),
            _CustomTab(day: widget.day, meal: widget.meal),
          ],
        ),
      ),
    );
  }
}

Future<void> _openFood(
  BuildContext context,
  Food food,
  String day,
  Meal meal,
) async {
  context.appRead.sound.play(Sfx.select);
  final unlocks = await showAddFoodSheet(
    context,
    food: food,
    day: day,
    meal: meal,
  );
  if (unlocks == null || !context.mounted) return;
  if (unlocks.isNotEmpty) {
    await showRewardDialog(
      context,
      title: 'Achievement!',
      reward: Reward.none,
      unlocks: unlocks,
    );
  } else {
    showMessage(context, 'Logged ${food.name}');
  }
  if (context.mounted) Navigator.of(context).pop();
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({required this.food, required this.onTap});

  final Food food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final serving = food.servings.isEmpty ? null : food.servings.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: Panel(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      SourceTag(food.source.label),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'P ${food.per100g.proteinG.toStringAsFixed(1)} · C ${food.per100g.carbsG.toStringAsFixed(1)} · '
                          'F ${food.per100g.fatG.toStringAsFixed(1)} per 100 g'
                          '${serving != null ? ' · ${serving.label}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Palette.textDim,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${food.per100g.kcal.round()}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Text(
                  'kcal/100g',
                  style: TextStyle(color: Palette.textDim, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Offline search over the bundled USDA list, plus recent foods.
class _OfflineTab extends StatefulWidget {
  const _OfflineTab({required this.day, required this.meal});

  final String day;
  final Meal meal;

  @override
  State<_OfflineTab> createState() => _OfflineTabState();
}

class _OfflineTabState extends State<_OfflineTab>
    with AutomaticKeepAliveClientMixin {
  final _query = TextEditingController();
  late final Future<UsdaCatalog> _catalog = context.services.usda;
  List<Food> _results = const [];

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _search(UsdaCatalog catalog) {
    setState(() => _results = catalog.search(_query.text));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final recent = context.app.recentFoods;
    return FutureBuilder<UsdaCatalog>(
      future: _catalog,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const EmptyState(
            icon: emptyFoodIcon,
            title: 'Food list unavailable',
            message: 'The offline food list could not be loaded. Try the Online or My foods tabs.',
          );
        }
        final catalog = snapshot.data;
        return ListView(
          padding: const EdgeInsets.all(Space.lg),
          children: [
            TextField(
              key: const Key('food-query'),
              controller: _query,
              enabled: catalog != null,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: catalog == null
                    ? 'Loading 7,000+ foods…'
                    : 'Search e.g. "rice cooked", "egg boiled"',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() {
                          _query.clear();
                          _results = const [];
                        }),
                      ),
              ),
              onChanged: catalog == null ? null : (_) => _search(catalog),
            ),
            const SizedBox(height: Space.sm),
            const Text(
              'Nutrition data: USDA FoodData Central (offline, public domain).',
              style: TextStyle(color: Palette.textFaint, fontSize: 11),
            ),
            if (_query.text.isEmpty) ...[
              if (recent.isNotEmpty) ...[
                const SectionHeader('Recent'),
                for (final f in recent)
                  _FoodTile(
                    food: f,
                    onTap: () => _openFood(context, f, widget.day, widget.meal),
                  ),
              ] else
                const EmptyState(
                  icon: emptyFoodIcon,
                  title: 'Search the food list',
                  message: 'Type a food name. Foods you log will show up here for quick re-adding.',
                ),
            ] else if (_results.isEmpty)
              EmptyState(
                icon: emptyFoodIcon,
                title: 'No matches',
                message: 'Try fewer or simpler words, search Online for packaged foods, or add your own in My foods.',
                action: OutlinedButton(
                  onPressed: () =>
                      DefaultTabController.of(context).animateTo(2),
                  child: const Text('Add my own food'),
                ),
              )
            else ...[
              const SizedBox(height: Space.sm),
              for (final f in _results)
                _FoodTile(
                  food: f,
                  onTap: () => _openFood(context, f, widget.day, widget.meal),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// Open Food Facts text search and barcode lookup.
class _OnlineTab extends StatefulWidget {
  const _OnlineTab({required this.day, required this.meal});

  final String day;
  final Meal meal;

  @override
  State<_OnlineTab> createState() => _OnlineTabState();
}

class _OnlineTabState extends State<_OnlineTab>
    with AutomaticKeepAliveClientMixin {
  final _query = TextEditingController();
  final _barcode = TextEditingController();
  bool _loading = false;
  String? _error;
  List<Food>? _results;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _query.dispose();
    _barcode.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<void> Function(OpenFoodFactsClient client) job,
  ) async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await job(context.services.openFoodFacts);
    } on FoodLookupException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _search() => _run((client) async {
    final results = await client.search(_query.text);
    if (mounted) setState(() => _results = results);
  });

  Future<void> _lookup() => _run((client) async {
    final food = await client.barcode(_barcode.text);
    if (!mounted) return;
    if (food == null) {
      setState(
        () => _error =
            'No product with that barcode (or it has no calorie data). '
            'You can add it yourself under My foods.',
      );
      return;
    }
    await _openFood(context, food, widget.day, widget.meal);
  });

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _query,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Packaged food or brand',
                  prefixIcon: Icon(Icons.public_rounded),
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: Space.sm),
            FilledButton(
              onPressed: _loading ? null : _search,
              child: const Text('Search'),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _barcode,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Barcode number',
                  prefixIcon: Icon(Icons.qr_code_rounded),
                ),
                onSubmitted: (_) => _lookup(),
              ),
            ),
            const SizedBox(width: Space.sm),
            OutlinedButton(
              onPressed: _loading ? null : _lookup,
              child: const Text('Look up'),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        const Text(
          'Product data from Open Food Facts (openfoodfacts.org, ODbL). Needs internet; '
          'searches are limited to a few per minute, so press Search when ready.',
          style: TextStyle(color: Palette.textFaint, fontSize: 11),
        ),
        const SizedBox(height: Space.md),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(Space.xl),
            child: Center(
              child: CircularProgressIndicator(color: Palette.gold),
            ),
          )
        else if (_error != null)
          Panel(
            borderColor: Palette.danger.withValues(alpha: 0.5),
            child: Row(
              children: [
                const Icon(Icons.wifi_off_rounded, color: Palette.danger),
                const SizedBox(width: Space.md),
                Expanded(child: Text(_error!)),
              ],
            ),
          )
        else if (_results == null)
          const EmptyState(
            icon: Icon(
              Icons.travel_explore_rounded,
              size: 48,
              color: Palette.textFaint,
            ),
            title: 'Search packaged foods',
            message: 'Find branded products or type the barcode printed on the package.',
          )
        else if (_results!.isEmpty)
          const EmptyState(
            icon: emptyFoodIcon,
            title: 'No products found',
            message:
                'Try another name, or add the food yourself under My foods.',
          )
        else
          for (final f in _results!)
            _FoodTile(
              food: f,
              onTap: () => _openFood(context, f, widget.day, widget.meal),
            ),
      ],
    );
  }
}

class _CustomTab extends StatelessWidget {
  const _CustomTab({required this.day, required this.meal});

  final String day;
  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final foods = context.app.save.customFoods;
    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        FilledButton.icon(
          onPressed: () async {
            final food = await Navigator.of(context).push<Food>(
              MaterialPageRoute(builder: (_) => const CustomFoodScreen()),
            );
            if (food != null && context.mounted) {
              await _openFood(context, food, day, meal);
            }
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create a food'),
        ),
        const SizedBox(height: Space.sm),
        const Text(
          'For home-cooked dishes like adobo or sinigang: enter the values from a label or recipe.',
          style: TextStyle(color: Palette.textFaint, fontSize: 12),
        ),
        if (foods.isEmpty)
          const EmptyState(
            icon: emptyFoodIcon,
            title: 'No custom foods yet',
            message: 'Foods you create are saved here for next time.',
          )
        else ...[
          const SectionHeader('Saved'),
          for (final f in foods)
            Dismissible(
              key: ValueKey(f.id),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) => confirm(
                context,
                title: 'Delete ${f.name}?',
                message: 'Past log entries keep their values.',
                confirmLabel: 'Delete',
                destructive: true,
              ),
              onDismissed: (_) => context.appRead.deleteCustomFood(f.id),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: Space.lg),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Palette.danger,
                ),
              ),
              child: _FoodTile(
                food: f,
                onTap: () => _openFood(context, f, day, meal),
              ),
            ),
        ],
      ],
    );
  }
}
