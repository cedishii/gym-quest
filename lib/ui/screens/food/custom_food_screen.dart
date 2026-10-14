import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_scope.dart';
import '../../../audio/sound_service.dart';
import '../../../domain/nutrition/food.dart';
import '../../theme/tokens.dart';
import '../../widgets/feedback.dart';

/// Create a food from a label or recipe. Values can be entered per 100 g
/// or per serving; per-serving values are converted.
class CustomFoodScreen extends StatefulWidget {
  const CustomFoodScreen({super.key});

  @override
  State<CustomFoodScreen> createState() => _CustomFoodScreenState();
}

class _CustomFoodScreenState extends State<CustomFoodScreen> {
  final _name = TextEditingController();
  final _servingName = TextEditingController(text: '1 serving');
  final _servingGrams = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _fat = TextEditingController();
  final _carbs = TextEditingController();
  bool _perServing = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _servingName,
      _servingGrams,
      _kcal,
      _protein,
      _fat,
      _carbs,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) => c.text.trim().isEmpty
      ? 0
      : double.tryParse(c.text.trim().replaceAll(',', '.'));

  void _save() {
    final grams = double.tryParse(
      _servingGrams.text.trim().replaceAll(',', '.'),
    );
    final kcal = double.tryParse(_kcal.text.trim().replaceAll(',', '.'));
    final p = _num(_protein), f = _num(_fat), c = _num(_carbs);
    if (kcal == null || p == null || f == null || c == null) {
      showMessage(
        context,
        'Enter numbers for calories and macros',
        error: true,
      );
      return;
    }
    if (_perServing && (grams == null || grams <= 0)) {
      showMessage(context, 'Enter the serving weight in grams', error: true);
      return;
    }
    final factor = _perServing ? 100 / grams! : 1.0;
    final per100 = Nutrients(
      kcal: kcal * factor,
      proteinG: p * factor,
      fatG: f * factor,
      carbsG: c * factor,
    );
    final serving = grams != null && grams > 0
        ? Serving(
            _servingName.text.trim().isEmpty
                ? '1 serving'
                : _servingName.text.trim(),
            grams,
          )
        : null;
    final food = runAction(
      context,
      () => context.appRead.addCustomFood(
        name: _name.text,
        per100g: per100,
        serving: serving,
      ),
    );
    if (food == null) return;
    context.appRead.sound.play(Sfx.confirm);
    Navigator.of(context).pop(food);
  }

  @override
  Widget build(BuildContext context) {
    final unit = _perServing ? 'per serving' : 'per 100 g';
    return Scaffold(
      appBar: AppBar(title: const Text('Create a food')),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: 'Food name',
              hintText: 'e.g. Chicken adobo (homemade)',
              counterText: '',
            ),
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _servingName,
                  decoration: const InputDecoration(labelText: 'Serving name'),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(flex: 2, child: _field(_servingGrams, 'Serving (g)')),
            ],
          ),
          const SizedBox(height: Space.md),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Values per 100 g')),
              ButtonSegment(value: true, label: Text('Per serving')),
            ],
            selected: {_perServing},
            onSelectionChanged: (s) => setState(() => _perServing = s.first),
          ),
          const SizedBox(height: Space.md),
          _field(_kcal, 'Calories (kcal) $unit'),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Expanded(child: _field(_protein, 'Protein g')),
              const SizedBox(width: Space.sm),
              Expanded(child: _field(_carbs, 'Carbs g')),
              const SizedBox(width: Space.sm),
              Expanded(child: _field(_fat, 'Fat g')),
            ],
          ),
          const SizedBox(height: Space.xl),
          FilledButton(onPressed: _save, child: const Text('Save food')),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label) => TextField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      LengthLimitingTextInputFormatter(7),
    ],
    decoration: InputDecoration(labelText: label),
  );
}
