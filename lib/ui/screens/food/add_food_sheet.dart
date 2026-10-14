import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_scope.dart';
import '../../../audio/sound_service.dart';
import '../../../domain/nutrition/food.dart';
import '../../../domain/nutrition/food_log.dart';
import '../../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/feedback.dart';

/// Pick an amount and meal, then log. Returns the achievements unlocked by
/// logging (possibly empty), or null when the sheet was dismissed.
Future<List<Unlock>?> showAddFoodSheet(
  BuildContext context, {
  required Food food,
  required String day,
  required Meal meal,
}) => showModalBottomSheet<List<Unlock>>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _AddFoodSheet(food: food, day: day, meal: meal),
);

class _AddFoodSheet extends StatefulWidget {
  const _AddFoodSheet({
    required this.food,
    required this.day,
    required this.meal,
  });

  final Food food;
  final String day;
  final Meal meal;

  @override
  State<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<_AddFoodSheet> {
  static const _grams = Serving('grams', 1);

  late final List<Serving> _options = [
    ...widget.food.servings,
    const Serving('100 g', 100),
    _grams,
  ];
  late Serving _serving = _options.first;
  late final TextEditingController _amount = TextEditingController(
    text: identical(_serving, _grams) ? '100' : '1',
  );
  late Meal _meal = widget.meal;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double? get _quantity => double.tryParse(_amount.text.replaceAll(',', '.'));

  double? get _gramsTotal {
    final q = _quantity;
    if (q == null) return null;
    return NutritionMath.servingGrams(_serving, q);
  }

  void _log() {
    final grams = _gramsTotal;
    final error = NutritionMath.validateGrams(grams);
    if (error != null) {
      showMessage(context, error, error: true);
      return;
    }
    final label = identical(_serving, _grams)
        ? null
        : '${_trim(_quantity!)} × ${_serving.label}';
    final unlocks = runAction(
      context,
      () => context.appRead.logFood(
        food: widget.food,
        grams: grams!,
        meal: _meal,
        day: widget.day,
        servingLabel: label,
      ),
    );
    if (unlocks == null) return;
    context.appRead.sound.play(Sfx.confirm);
    Navigator.of(context).pop(unlocks);
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final grams = _gramsTotal;
    final n = grams == null
        ? null
        : NutritionMath.forGrams(widget.food.per100g, grams);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.lg,
        0,
        Space.lg,
        MediaQuery.viewInsetsOf(context).bottom + Space.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.food.displayName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            '${widget.food.source.label}${widget.food.category != null ? ' · ${widget.food.category}' : ''}',
            style: const TextStyle(color: Palette.textDim, fontSize: 12),
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              SizedBox(
                width: 96,
                child: TextField(
                  key: const Key('food-amount'),
                  controller: _amount,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(labelText: 'Amount'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: DropdownButtonFormField<Serving>(
                  initialValue: _serving,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: [
                    for (final s in _options)
                      DropdownMenuItem(
                        value: s,
                        child: Text(
                          identical(s, _grams)
                              ? 'grams'
                              : '${s.label} (${s.grams.round()} g)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (s) {
                    if (s == null) return;
                    setState(() {
                      _serving = s;
                      _amount.text = identical(s, _grams) ? '100' : '1';
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            children: [
              for (final m in Meal.values)
                ChoiceChip(
                  label: Text(m.label),
                  selected: m == _meal,
                  onSelected: (_) => setState(() => _meal = m),
                ),
            ],
          ),
          const SizedBox(height: Space.md),
          Container(
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(
              color: Palette.surfaceHigh,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: n == null
                ? const Text(
                    'Enter an amount',
                    style: TextStyle(color: Palette.textDim),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _macro('${n.kcal.round()}', 'kcal', Palette.gold),
                      _macro(
                        '${n.proteinG.toStringAsFixed(1)} g',
                        'protein',
                        Palette.protein,
                      ),
                      _macro(
                        '${n.carbsG.toStringAsFixed(1)} g',
                        'carbs',
                        Palette.carbs,
                      ),
                      _macro(
                        '${n.fatG.toStringAsFixed(1)} g',
                        'fat',
                        Palette.fat,
                      ),
                    ],
                  ),
          ),
          if (grams != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(
                '= ${grams.round()} g',
                textAlign: TextAlign.end,
                style: const TextStyle(color: Palette.textDim, fontSize: 12),
              ),
            ),
          const SizedBox(height: Space.md),
          FilledButton(
            key: const Key('log-food'),
            onPressed: _log,
            child: Text('Add to ${_meal.label}'),
          ),
        ],
      ),
    );
  }

  Widget _macro(String value, String label, Color color) => Column(
    children: [
      Text(
        value,
        style: TextStyle(fontWeight: FontWeight.w600, color: color),
      ),
      Text(label, style: const TextStyle(color: Palette.textDim, fontSize: 11)),
    ],
  );
}
