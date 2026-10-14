import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/app_scope.dart';
import '../../../audio/sound_service.dart';
import '../../../core/dates.dart';
import '../../../domain/nutrition/food_log.dart';
import '../../theme/tokens.dart';
import '../../widgets/bars.dart';
import '../../widgets/game_icon.dart';
import '../../widgets/panel.dart';
import 'food_search_screen.dart';

class FoodScreen extends StatefulWidget {
  const FoodScreen({super.key});

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  int _offset = 0; // days from today (0 = today, -1 = yesterday)

  String _dayKey(DateTime now) =>
      Day.key(Day.dateOnly(now).add(Duration(days: _offset)));

  void _add(String day, Meal meal) {
    context.appRead.sound.play(Sfx.open);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(day: day, meal: meal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final day = _dayKey(app.now);
    final entries = app.entriesFor(day);
    final totals = NutritionMath.total(entries);
    final byMeal = NutritionMath.byMeal(entries);
    final fitness = app.fitness!;
    final date = Day.parse(day);
    final label = switch (_offset) {
      0 => 'Today',
      -1 => 'Yesterday',
      _ => DateFormat('EEE, MMM d').format(date),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Food log')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-food'),
        onPressed: () => _add(day, _defaultMeal(app.now)),
        backgroundColor: Palette.gold,
        foregroundColor: const Color(0xFF231A05),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add food'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, 96),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous day',
                onPressed: _offset > -60
                    ? () => setState(() => _offset--)
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Next day',
                onPressed: _offset < 0 ? () => setState(() => _offset++) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          Panel(
            child: Column(
              children: [
                Row(
                  children: [
                    CalorieRing(
                      eaten: totals.kcal,
                      target: fitness.targets.calories,
                    ),
                    const SizedBox(width: Space.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _kv('Eaten', '${totals.kcal.round()} kcal'),
                          _kv('Target', '${fitness.targets.calories} kcal'),
                          _kv('Fiber', '${totals.fiberG.toStringAsFixed(1)} g'),
                          const SizedBox(height: 4),
                          const Text(
                            'Target is an estimate from your profile.',
                            style: TextStyle(
                              color: Palette.textFaint,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                LabeledBar(
                  label: 'Protein',
                  valueText:
                      '${totals.proteinG.round()} / ${fitness.targets.proteinG} g',
                  value: totals.proteinG / fitness.targets.proteinG,
                  color: Palette.protein,
                ),
                const SizedBox(height: Space.sm),
                LabeledBar(
                  label: 'Carbs',
                  valueText:
                      '${totals.carbsG.round()} / ${fitness.targets.carbsG} g',
                  value: fitness.targets.carbsG == 0
                      ? 0
                      : totals.carbsG / fitness.targets.carbsG,
                  color: Palette.carbs,
                ),
                const SizedBox(height: Space.sm),
                LabeledBar(
                  label: 'Fat',
                  valueText:
                      '${totals.fatG.round()} / ${fitness.targets.fatG} g',
                  value: totals.fatG / fitness.targets.fatG,
                  color: Palette.fat,
                ),
              ],
            ),
          ),
          for (final meal in Meal.values) ...[
            SectionHeader(
              meal.label,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${byMeal[meal]!.kcal.round()} kcal',
                    style: const TextStyle(color: Palette.textDim),
                  ),
                  IconButton(
                    tooltip: 'Add to ${meal.label}',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _add(day, meal),
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: Palette.gold,
                    ),
                  ),
                ],
              ),
            ),
            ..._entries(entries.where((e) => e.meal == meal).toList()),
          ],
        ],
      ),
    );
  }

  List<Widget> _entries(List<FoodLogEntry> entries) {
    if (entries.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: Space.xs),
          child: Text(
            'Nothing logged',
            style: TextStyle(color: Palette.textFaint, fontSize: 13),
          ),
        ),
      ];
    }
    return [
      for (final e in entries)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.xs),
          child: Dismissible(
            key: ValueKey(e.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: Space.lg),
              decoration: BoxDecoration(
                color: Palette.danger.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: const Icon(Icons.delete_outline_rounded),
            ),
            onDismissed: (_) {
              final app = context.appRead;
              app.removeFoodEntry(e.id);
              app.sound.play(Sfx.back);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(content: Text('Removed ${e.food.name}')),
                );
            },
            child: Panel(
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
                          e.food.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${e.servingLabel != null ? '${e.servingLabel} · ' : ''}${e.grams.round()} g · '
                          'P ${e.nutrients.proteinG.round()} C ${e.nutrients.carbsG.round()} F ${e.nutrients.fatG.round()}',
                          style: const TextStyle(
                            color: Palette.textDim,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${e.nutrients.kcal.round()}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 2),
                  const Text(
                    'kcal',
                    style: TextStyle(color: Palette.textDim, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
    ];
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            k,
            style: const TextStyle(color: Palette.textDim, fontSize: 13),
          ),
        ),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );

  static Meal _defaultMeal(DateTime now) {
    final h = now.hour;
    if (h < 10) return Meal.breakfast;
    if (h < 15) return Meal.lunch;
    if (h < 21) return Meal.dinner;
    return Meal.snack;
  }
}

/// Small label used in food rows.
class SourceTag extends StatelessWidget {
  const SourceTag(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: Palette.surfaceHigh,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: const TextStyle(color: Palette.textDim, fontSize: 10),
    ),
  );
}

const emptyFoodIcon = GameIcon(
  'fruit-bowl',
  size: 48,
  color: Palette.textFaint,
);
