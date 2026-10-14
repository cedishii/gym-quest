import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../domain/workout/exercise.dart';
import '../../theme/tokens.dart';
import '../../widgets/exercise_demo.dart';
import '../../widgets/panel.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  MovementPattern? _filter;

  @override
  Widget build(BuildContext context) {
    final all = context.app.exercises.exercises;
    final list = _filter == null
        ? all
        : all.where((e) => e.pattern == _filter).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise library')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: Space.lg,
                vertical: Space.sm,
              ),
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                for (final p in MovementPattern.values) ...[
                  const SizedBox(width: Space.sm),
                  ChoiceChip(
                    label: Text(p.label),
                    selected: _filter == p,
                    onSelected: (_) => setState(() => _filter = p),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                0,
                Space.lg,
                Space.lg,
              ),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final e = list[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: Space.xs),
                  child: Panel(
                    padding: const EdgeInsets.all(Space.sm),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ExerciseDetailScreen(exercise: e),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 72,
                          child: ExerciseDemo(
                            exercise: e,
                            height: 56,
                            animate: false,
                          ),
                        ),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${e.pattern.label} · ${e.equipment} · ${e.level}',
                                style: const TextStyle(
                                  color: Palette.textDim,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final e = exercise;
    final records = context.app.save.records.values
        .where((r) => r.exerciseId == e.id)
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(e.name)),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          ExerciseDemo(exercise: e, height: 240),
          const SizedBox(height: Space.xs),
          const Text(
            'Start and end positions · photos: free-exercise-db',
            style: TextStyle(color: Palette.textFaint, fontSize: 11),
          ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              _chip(e.pattern.label),
              _chip(e.equipment),
              _chip(e.level),
              if (e.lowImpact) _chip('low impact'),
              if (e.timed) _chip('timed'),
            ],
          ),
          const SizedBox(height: Space.md),
          Text(
            'Muscles: ${[...e.primaryMuscles, ...e.secondaryMuscles].join(', ')}',
            style: const TextStyle(color: Palette.textDim),
          ),
          if (records.isNotEmpty) ...[
            const SectionHeader('Your records'),
            for (final r in records)
              Text(
                '• ${r.valueLabel}',
                style: const TextStyle(color: Palette.gold),
              ),
          ],
          const SectionHeader('How to'),
          for (var i = 0; i < e.instructions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: Palette.surfaceHigh,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(fontSize: 11, color: Palette.text),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      e.instructions[i],
                      style: const TextStyle(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Space.md),
          Text(
            'Intensity estimate: ${e.met} MET (Compendium of Physical Activities).',
            style: const TextStyle(color: Palette.textFaint, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Palette.surfaceHigh,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(text, style: const TextStyle(fontSize: 12)),
  );
}
