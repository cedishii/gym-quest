import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_scope.dart';
import '../../../audio/sound_service.dart';
import '../../../domain/workout/exercise.dart';
import '../../../domain/workout/personal_records.dart';
import '../../../domain/workout/workout_session.dart';
import '../../theme/tokens.dart';
import '../../widgets/bars.dart';
import '../../widgets/exercise_demo.dart';
import '../../widgets/feedback.dart';
import 'exercise_library_screen.dart';

/// Logging screen for the workout in progress. Every change is saved
/// immediately, so leaving and coming back keeps all sets.
class WorkoutSessionScreen extends StatelessWidget {
  const WorkoutSessionScreen({super.key});

  Future<void> _finish(BuildContext context, WorkoutSession session) async {
    final app = context.appRead;
    if (session.completedSets < session.plannedSets) {
      final ok = await confirm(
        context,
        title: 'Finish early?',
        message:
            '${session.completedSets} of ${session.plannedSets} planned sets are done. '
            'You still earn food for every exercise you started.',
        confirmLabel: 'Finish',
      );
      if (!ok || !context.mounted) return;
    }
    final outcome = runAction(context, () => app.finishSession());
    if (outcome == null || !context.mounted) return;
    final r = outcome.record;
    final lines = <String>[
      '${r.completedSets} sets in ${r.duration.inMinutes} min · about ${r.estimatedKcal.round()} kcal burned (estimate)',
      if (outcome.streak.alive)
        'Streak: ${outcome.streak.current} day${outcome.streak.current == 1 ? '' : 's'}',
      for (final hit in r.recordHits.where((h) => h.isImprovement))
        'New record: ${app.exercises.byId(hit.record.exerciseId)?.name ?? hit.record.exerciseId} '
            '(${hit.record.valueLabel})',
      ...r.reward.reasons,
    ];
    await showRewardDialog(
      context,
      title: 'Workout complete!',
      reward: r.reward,
      unlocks: outcome.unlocks,
      lines: lines,
      icon: 'laurels',
    );
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _cancel(BuildContext context) async {
    final ok = await confirm(
      context,
      title: 'Discard workout?',
      message:
          'Logged sets in this workout will be lost and no food is earned.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    context.appRead.cancelSession();
    context.appRead.sound.play(Sfx.back);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final session = app.activeSession;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('No workout in progress.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(session.dayName),
        actions: [
          IconButton(
            tooltip: 'Discard workout',
            onPressed: () => _cancel(context),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, 120),
        children: [
          for (var i = 0; i < session.exercises.length; i++)
            _ExerciseCard(
              index: i,
              log: session.exercises[i],
              exercise: app.exercises.byId(session.exercises[i].exerciseId),
            ),
        ],
      ),
      bottomSheet: Container(
        color: Palette.backgroundDeep,
        padding: EdgeInsets.fromLTRB(
          Space.lg,
          Space.md,
          Space.lg,
          Space.md + MediaQuery.paddingOf(context).bottom,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${session.completedSets} / ${session.plannedSets} sets',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  GameBar(value: session.completion, color: Palette.gold),
                ],
              ),
            ),
            const SizedBox(width: Space.lg),
            FilledButton(
              key: const Key('finish-workout'),
              onPressed: session.completedSets == 0
                  ? null
                  : () => _finish(context, session),
              child: const Text('Finish'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.index,
    required this.log,
    required this.exercise,
  });

  final int index;
  final ExerciseLog log;
  final Exercise? exercise;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final timed = log.planned.isTimed;
    final done = log.completedSets >= log.planned.sets;
    PersonalRecord? best;
    for (final r in app.save.records.values) {
      if (r.exerciseId == log.exerciseId &&
          (best == null || r.achievedAt.isAfter(best.achievedAt))) {
        best = r;
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Container(
        decoration: BoxDecoration(
          color: Palette.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: done ? Palette.hp.withValues(alpha: 0.6) : Palette.border,
          ),
        ),
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: exercise == null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ExerciseDetailScreen(exercise: exercise!),
                      ),
                    ),
              child: Row(
                children: [
                  if (exercise != null)
                    SizedBox(
                      width: 72,
                      child: ExerciseDemo(exercise: exercise!, height: 56),
                    ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise?.name ?? log.exerciseId,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Target ${log.planned.targetLabel} · rest ${log.planned.restSeconds}s',
                          style: const TextStyle(
                            color: Palette.textDim,
                            fontSize: 12,
                          ),
                        ),
                        if (best != null)
                          Text(
                            'Best: ${best.valueLabel}',
                            style: const TextStyle(
                              color: Palette.gold,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (done)
                    const Icon(Icons.check_circle_rounded, color: Palette.hp),
                ],
              ),
            ),
            const SizedBox(height: Space.sm),
            Row(
              children: [
                const SizedBox(
                  width: 36,
                  child: Text(
                    'SET',
                    style: TextStyle(color: Palette.textFaint, fontSize: 11),
                  ),
                ),
                Expanded(
                  child: Text(
                    timed ? 'SECONDS' : 'REPS',
                    style: const TextStyle(
                      color: Palette.textFaint,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (!timed)
                  const Expanded(
                    child: Text(
                      'KG (optional)',
                      style: TextStyle(color: Palette.textFaint, fontSize: 11),
                    ),
                  ),
                const SizedBox(width: 48),
              ],
            ),
            for (var s = 0; s < log.sets.length; s++)
              _SetRow(
                key: ValueKey('set-$index-$s'),
                exerciseIndex: index,
                setIndex: s,
                set: log.sets[s],
                timed: timed,
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    runAction(context, () => context.appRead.addSet(index)),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add set'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetRow extends StatefulWidget {
  const _SetRow({
    super.key,
    required this.exerciseIndex,
    required this.setIndex,
    required this.set,
    required this.timed,
  });

  final int exerciseIndex;
  final int setIndex;
  final SetLog set;
  final bool timed;

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late final TextEditingController _amount = TextEditingController(
    text: '${widget.timed ? widget.set.seconds : widget.set.reps}',
  );
  late final TextEditingController _weight = TextEditingController(
    text: widget.set.weightKg == 0 ? '' : _fmt(widget.set.weightKg),
  );

  static String _fmt(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : '$v';

  @override
  void dispose() {
    _amount.dispose();
    _weight.dispose();
    super.dispose();
  }

  SetLog _current({bool? done}) {
    final amount = int.tryParse(_amount.text) ?? 0;
    final weight = double.tryParse(_weight.text.replaceAll(',', '.')) ?? 0;
    return widget.set.copyWith(
      reps: widget.timed ? widget.set.reps : amount,
      seconds: widget.timed ? amount : widget.set.seconds,
      weightKg: weight,
      done: done ?? widget.set.done,
    );
  }

  void _save({bool? done}) {
    final app = context.appRead;
    final ok = runAction(context, () {
      app.updateSet(
        widget.exerciseIndex,
        widget.setIndex,
        _current(done: done),
      );
      return true;
    });
    if (ok == true && done != null) {
      app.sound.play(done ? Sfx.select : Sfx.toggle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.set.done;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '${widget.setIndex + 1}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: done ? Palette.hp : Palette.text,
              ),
            ),
          ),
          Expanded(child: _input(_amount, decimal: false, enabled: !done)),
          if (!widget.timed) ...[
            const SizedBox(width: Space.sm),
            Expanded(child: _input(_weight, decimal: true, enabled: !done)),
          ],
          const SizedBox(width: Space.sm),
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton.filled(
              key: Key('done-${widget.exerciseIndex}-${widget.setIndex}'),
              style: IconButton.styleFrom(
                backgroundColor: done ? Palette.hp : Palette.surfaceHigh,
                foregroundColor: done
                    ? const Color(0xFF0B2615)
                    : Palette.textDim,
              ),
              tooltip: done
                  ? 'Undo set ${widget.setIndex + 1}'
                  : 'Set ${widget.setIndex + 1} done',
              onPressed: () => _save(done: !done),
              icon: const Icon(Icons.check_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _input(
    TextEditingController c, {
    required bool decimal,
    required bool enabled,
  }) => SizedBox(
    height: 40,
    child: TextField(
      controller: c,
      enabled: enabled,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          decimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
        ),
        LengthLimitingTextInputFormatter(5),
      ],
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 8),
      ),
      onEditingComplete: () => _save(),
      onTapOutside: (_) {
        if (enabled) _save();
        FocusManager.instance.primaryFocus?.unfocus();
      },
    ),
  );
}
