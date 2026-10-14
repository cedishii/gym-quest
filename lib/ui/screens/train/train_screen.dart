import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/app_scope.dart';
import '../../../audio/sound_service.dart';
import '../../../config/balance.dart';
import '../../../domain/workout/workout_plan.dart';
import '../../../domain/workout/workout_record.dart';
import '../../theme/tokens.dart';
import '../../widgets/feedback.dart';
import '../../widgets/game_icon.dart';
import '../../widgets/panel.dart';
import 'exercise_library_screen.dart';
import 'workout_session_screen.dart';

class TrainScreen extends StatelessWidget {
  const TrainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final plan = app.plan;
    final session = app.activeSession;
    final history = app.workoutHistory;
    final tier = app.trainingTier;
    final suggested = app.suggestedDayIndex;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Training'),
        actions: [
          IconButton(
            tooltip: 'Exercise library',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExerciseLibraryScreen()),
            ),
            icon: const Icon(Icons.menu_book_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xl),
        children: [
          if (session != null)
            Panel(
              glow: Palette.gold,
              borderColor: Palette.gold,
              onTap: () => _openSession(context),
              child: Row(
                children: [
                  const GameIcon('run', size: 34, color: Palette.gold),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Continue ${session.dayName}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${session.completedSets}/${session.plannedSets} sets done',
                          style: const TextStyle(color: Palette.textDim),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.play_arrow_rounded,
                    color: Palette.gold,
                    size: 30,
                  ),
                ],
              ),
            ),
          SectionHeader(
            'Your weekly plan',
            trailing: TextButton.icon(
              onPressed: () async {
                final ok = await confirm(
                  context,
                  title: 'Rebuild plan?',
                  message: 'A fresh plan is generated from your current profile and training tier.',
                  confirmLabel: 'Rebuild',
                );
                if (ok && context.mounted) {
                  runAction(context, () => context.appRead.regeneratePlan());
                  context.appRead.sound.play(Sfx.confirm);
                }
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Rebuild'),
            ),
          ),
          Panel(
            padding: const EdgeInsets.all(Space.md),
            child: Row(
              children: [
                GameIcon(
                  'star-medal',
                  size: 30,
                  color: tier > 1 ? Palette.gold : Palette.textDim,
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Training tier $tier of ${Balance.maxTier}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _tierHint(app.save.workouts.length, tier),
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
          const SizedBox(height: Space.sm),
          if (plan == null || plan.days.isEmpty)
            const EmptyState(
              icon: GameIcon(
                'weight-lifting',
                size: 48,
                color: Palette.textFaint,
              ),
              title: 'No plan yet',
              message: 'Tap Rebuild to generate one from your profile.',
            )
          else ...[
            for (var i = 0; i < plan.days.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: _DayCard(
                  day: plan.days[i],
                  index: i,
                  suggested: i == suggested && session == null,
                  onTap: () => _showDay(context, i, plan.days[i]),
                ),
              ),
            _Reasons(plan.reasons),
          ],
          const SectionHeader('History'),
          if (history.isEmpty)
            const EmptyState(
              icon: GameIcon('footprint', size: 44, color: Palette.textFaint),
              title: 'No workouts yet',
              message: 'Finish your first workout to earn food for your pet.',
            )
          else
            for (final w in history.take(15)) _HistoryTile(record: w),
        ],
      ),
    );
  }

  static String _tierHint(int workouts, int tier) {
    if (tier >= Balance.maxTier) {
      return 'Max tier: bigger plans and bonus rewards.';
    }
    final next = Balance.tierWorkoutThresholds
        .where((t) => t > workouts)
        .firstOrNull;
    return next == null
        ? 'Higher tiers add volume and bonus kibble.'
        : '${next - workouts} more workouts to the next tier (more volume, +25% kibble).';
  }

  static void _openSession(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const WorkoutSessionScreen()));
  }

  static void _showDay(BuildContext context, int index, WorkoutDay day) {
    final app = context.appRead;
    app.sound.play(Sfx.open);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
          children: [
            Text(day.name, style: Theme.of(context).textTheme.titleLarge),
            Text(day.focus, style: const TextStyle(color: Palette.textDim)),
            const SizedBox(height: Space.md),
            for (final p in day.exercises)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const GameIcon(
                  'weight-lifting',
                  size: 26,
                  color: Palette.gold,
                ),
                title: Text(
                  app.exercises.byId(p.exerciseId)?.name ?? p.exerciseId,
                ),
                subtitle: Text('${p.targetLabel} · rest ${p.restSeconds}s'),
                trailing: const Icon(Icons.info_outline_rounded, size: 20),
                onTap: () {
                  final ex = app.exercises.byId(p.exerciseId);
                  if (ex != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ExerciseDetailScreen(exercise: ex),
                      ),
                    );
                  }
                },
              ),
            const SizedBox(height: Space.md),
            FilledButton.icon(
              key: const Key('start-workout'),
              onPressed: () {
                final session = runAction(
                  context,
                  () => context.appRead.startSession(index),
                );
                if (session == null) return;
                context.appRead.sound.play(Sfx.confirm);
                Navigator.of(sheetContext).pop();
                _openSession(sheetContext);
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                app.activeSession != null
                    ? 'Continue current workout'
                    : 'Start workout',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.index,
    required this.suggested,
    required this.onTap,
  });

  final WorkoutDay day;
  final int index;
  final bool suggested;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Panel(
    key: Key('day-$index'),
    onTap: onTap,
    borderColor: suggested
        ? Palette.gold.withValues(alpha: 0.7)
        : Palette.border,
    child: Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: suggested ? Palette.gold : Palette.surfaceHigh,
          foregroundColor: suggested ? const Color(0xFF231A05) : Palette.text,
          child: Text(
            '${index + 1}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      day.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (suggested) ...[
                    const SizedBox(width: Space.sm),
                    const Text(
                      'UP NEXT',
                      style: TextStyle(
                        color: Palette.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                '${day.exercises.length} exercises · ${day.totalSets} sets · ${day.focus}',
                style: const TextStyle(color: Palette.textDim, fontSize: 13),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: Palette.textDim),
      ],
    ),
  );
}

class _Reasons extends StatelessWidget {
  const _Reasons(this.reasons);

  final List<String> reasons;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      title: const Text(
        'Why this plan?',
        style: TextStyle(color: Palette.textDim, fontSize: 14),
      ),
      children: [
        for (final r in reasons)
          ListTile(
            dense: true,
            leading: const Icon(
              Icons.check_rounded,
              color: Palette.gold,
              size: 18,
            ),
            title: Text(r, style: const TextStyle(fontSize: 13)),
          ),
      ],
    ),
  );
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record});

  final WorkoutRecord record;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEE, MMM d · h:mm a')
        .format(record.finishedAt.toLocal());
    final food = record.reward.food.values.fold<int>(0, (a, b) => a + b);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
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
                    record.dayName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '$date · ${record.completedSets} sets · ~${record.estimatedKcal.round()} kcal (est.)',
                    style: const TextStyle(
                      color: Palette.textDim,
                      fontSize: 12,
                    ),
                  ),
                  if (record.improvements > 0)
                    Text(
                      '${record.improvements} personal record${record.improvements == 1 ? '' : 's'}',
                      style: const TextStyle(color: Palette.gold, fontSize: 12),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                const GameIcon('carrot', size: 18, color: Palette.gold),
                const SizedBox(width: 2),
                Text(
                  '+$food',
                  style: const TextStyle(
                    color: Palette.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
