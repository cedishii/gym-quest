import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/profile/profile.dart';
import '../../theme/tokens.dart';

/// Editable copy of a profile with validation. Used by onboarding and by
/// the profile editor so both behave the same.
class ProfileDraft {
  ProfileDraft([Profile? p])
    : name = TextEditingController(text: p?.name ?? ''),
      age = TextEditingController(text: p == null ? '' : '${p.age}'),
      height = TextEditingController(text: p == null ? '' : _num(p.heightCm)),
      weight = TextEditingController(text: p == null ? '' : _num(p.weightKg)),
      sex = p?.sex ?? BodySex.male,
      activity = p?.activity ?? ActivityLevel.light,
      goal = p?.goal ?? Goal.maintain,
      experience = p?.experience ?? Experience.beginner,
      equipment = p?.equipment ?? EquipmentAccess.bodyweight,
      daysPerWeek = p?.daysPerWeek ?? 3,
      asianCutoffs = p?.useAsianBmiCutoffs ?? true;

  final TextEditingController name;
  final TextEditingController age;
  final TextEditingController height;
  final TextEditingController weight;
  BodySex sex;
  ActivityLevel activity;
  Goal goal;
  Experience experience;
  EquipmentAccess equipment;
  int daysPerWeek;
  bool asianCutoffs;
  Map<String, String> errors = {};

  static String _num(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

  double? _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  /// Validates the body fields; returns true when valid.
  bool validateBody() {
    errors = Profile.validate(
      name: name.text,
      age: int.tryParse(age.text.trim()),
      heightCm: _parse(height),
      weightKg: _parse(weight),
      daysPerWeek: daysPerWeek,
    );
    return errors.isEmpty;
  }

  Profile build() => Profile(
    name: name.text.trim(),
    sex: sex,
    age: int.parse(age.text.trim()),
    heightCm: _parse(height)!,
    weightKg: _parse(weight)!,
    activity: activity,
    goal: goal,
    experience: experience,
    equipment: equipment,
    daysPerWeek: daysPerWeek,
    useAsianBmiCutoffs: asianCutoffs,
  );

  void dispose() {
    name.dispose();
    age.dispose();
    height.dispose();
    weight.dispose();
  }
}

class BodyFields extends StatelessWidget {
  const BodyFields({super.key, required this.draft, required this.onChanged});

  final ProfileDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final e = draft.errors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('field-name'),
          controller: draft.name,
          textCapitalization: TextCapitalization.words,
          maxLength: 30,
          decoration: InputDecoration(
            labelText: 'Your name',
            errorText: e['name'],
            counterText: '',
          ),
        ),
        const SizedBox(height: Space.md),
        const Text(
          'Body type for the calorie formula',
          style: TextStyle(color: Palette.textDim, fontSize: 13),
        ),
        const SizedBox(height: Space.xs),
        SegmentedButton<BodySex>(
          segments: const [
            ButtonSegment(value: BodySex.male, label: Text('Male')),
            ButtonSegment(value: BodySex.female, label: Text('Female')),
          ],
          selected: {draft.sex},
          onSelectionChanged: (s) {
            draft.sex = s.first;
            onChanged();
          },
        ),
        const SizedBox(height: Space.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _NumberField(
                key: const Key('field-age'),
                controller: draft.age,
                label: 'Age',
                suffix: 'yrs',
                error: e['age'],
                decimals: false,
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: _NumberField(
                key: const Key('field-height'),
                controller: draft.height,
                label: 'Height',
                suffix: 'cm',
                error: e['height'],
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: _NumberField(
                key: const Key('field-weight'),
                controller: draft.weight,
                label: 'Weight',
                suffix: 'kg',
                error: e['weight'],
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        DropdownButtonFormField<ActivityLevel>(
          initialValue: draft.activity,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Daily activity (outside workouts too)',
          ),
          items: [
            for (final a in ActivityLevel.values)
              DropdownMenuItem(
                value: a,
                child: Text(a.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) {
            if (v == null) return;
            draft.activity = v;
            onChanged();
          },
        ),
        const SizedBox(height: Space.sm),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Asian BMI cut-offs'),
          subtitle: const Text(
            'WHO Asia-Pacific: overweight from 23, obese from 25',
            style: TextStyle(fontSize: 12),
          ),
          value: draft.asianCutoffs,
          onChanged: (v) {
            draft.asianCutoffs = v;
            onChanged();
          },
        ),
      ],
    );
  }
}

class TrainingFields extends StatelessWidget {
  const TrainingFields({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final ProfileDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChoiceGroup<Goal>(
          label: 'Main goal',
          values: Goal.values,
          selected: draft.goal,
          text: (g) => g.label,
          onSelected: (g) {
            draft.goal = g;
            onChanged();
          },
        ),
        _ChoiceGroup<Experience>(
          label: 'Training experience',
          values: Experience.values,
          selected: draft.experience,
          text: (x) => x.label,
          onSelected: (x) {
            draft.experience = x;
            onChanged();
          },
        ),
        _ChoiceGroup<EquipmentAccess>(
          label: 'Equipment you can use',
          values: EquipmentAccess.values,
          selected: draft.equipment,
          text: (x) => x.label,
          onSelected: (x) {
            draft.equipment = x;
            onChanged();
          },
        ),
        const SizedBox(height: Space.sm),
        Text(
          'Workout days per week: ${draft.daysPerWeek}',
          style: const TextStyle(color: Palette.textDim),
        ),
        Slider(
          value: draft.daysPerWeek.toDouble(),
          min: Profile.minDays.toDouble(),
          max: Profile.maxDays.toDouble(),
          divisions: Profile.maxDays - Profile.minDays,
          label: '${draft.daysPerWeek}',
          onChanged: (v) {
            draft.daysPerWeek = v.round();
            onChanged();
          },
        ),
      ],
    );
  }
}

class _ChoiceGroup<T> extends StatelessWidget {
  const _ChoiceGroup({
    required this.label,
    required this.values,
    required this.selected,
    required this.text,
    required this.onSelected,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T) text;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Palette.textDim, fontSize: 13),
        ),
        const SizedBox(height: Space.xs),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final v in values)
              ChoiceChip(
                label: Text(text(v)),
                selected: v == selected,
                onSelected: (_) => onSelected(v),
              ),
          ],
        ),
      ],
    ),
  );
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    super.key,
    required this.controller,
    required this.label,
    required this.suffix,
    this.error,
    this.decimals = true,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final String? error;
  final bool decimals;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: TextInputType.numberWithOptions(decimal: decimals),
    inputFormatters: [
      FilteringTextInputFormatter.allow(
        decimals ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
      ),
      LengthLimitingTextInputFormatter(5),
    ],
    decoration: InputDecoration(
      labelText: label,
      suffixText: suffix,
      errorText: error,
      errorMaxLines: 2,
    ),
  );
}
