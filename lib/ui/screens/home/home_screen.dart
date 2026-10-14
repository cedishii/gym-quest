import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../domain/map/stages.dart';
import '../../../domain/pet/pet_food.dart';
import '../../theme/tokens.dart';
import '../../widgets/bars.dart';
import '../../widgets/game_icon.dart';
import '../../widgets/panel.dart';
import '../../widgets/pet_sprite.dart';
import '../profile/profile_screen.dart';
import '../shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pet = app.pet!;
    final profile = app.profile!;
    final fitness = app.fitness!;
    final totals = app.totalsFor(app.today);
    final streak = app.streak;
    final plan = app.plan;
    final session = app.activeSession;
    final nextDay = plan == null || plan.days.isEmpty
        ? null
        : plan.days[app.suggestedDayIndex];
    final progress = app.mapProgress;
    final nextStage = progress.currentIndex < GameMap.stages.length
        ? GameMap.stages[progress.currentIndex]
        : null;
    final food = PetFood.values.fold<int>(
      0,
      (sum, f) => sum + app.foodCount(f),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${profile.name}'),
        actions: [
          IconButton(
            tooltip: 'Profile & settings',
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
            icon: const Icon(Icons.person_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xl),
        children: [
          // Pet card.
          Panel(
            onTap: () => Shell.goTo(Shell.pet),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Palette.element(pet.element).withValues(alpha: 0.25),
                Palette.surface,
              ],
            ),
            child: Row(
              children: [
                PetSprite(element: pet.element, level: pet.level, size: 110),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Level ${pet.level} ${pet.species.name}',
                        style: const TextStyle(color: Palette.textDim),
                      ),
                      const SizedBox(height: Space.sm),
                      GameBar(value: pet.xp / pet.xpToNext, color: Palette.xp),
                      const SizedBox(height: 4),
                      Text(
                        '${pet.xp} / ${pet.xpToNext} XP',
                        style: const TextStyle(
                          color: Palette.textDim,
                          fontSize: 12,
                        ),
                      ),
                      if (food > 0) ...[
                        const SizedBox(height: Space.sm),
                        Row(
                          children: [
                            const GameIcon(
                              'carrot',
                              size: 16,
                              color: Palette.gold,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$food food ready to feed',
                              style: const TextStyle(
                                color: Palette.gold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          // Streak + badges row.
          Row(
            children: [
              Expanded(
                child: _Stat(
                  icon: 'flame',
                  color: streak.alive ? Palette.warning : Palette.textFaint,
                  value: '${streak.current}',
                  label: streak.alive
                      ? (streak.daysUntilBreak == 0
                            ? 'day streak · train today!'
                            : 'day streak')
                      : 'day streak',
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: _Stat(
                  icon: 'medal',
                  color: Palette.gold,
                  value: '${progress.badges}/5',
                  label: 'gym badges',
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: _Stat(
                  icon: 'weight-lifting',
                  color: Palette.xp,
                  value: '${app.save.workouts.length}',
                  label: 'workouts',
                ),
              ),
            ],
          ),
          const SectionHeader('Today'),
          // Workout card.
          Panel(
            onTap: () => Shell.goTo(Shell.train),
            borderColor: session != null ? Palette.gold : Palette.border,
            child: Row(
              children: [
                const GameIcon('weight-lifting', size: 36, color: Palette.gold),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session != null
                            ? 'Workout in progress'
                            : 'Next workout',
                        style: const TextStyle(
                          color: Palette.textDim,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        session?.dayName ?? nextDay?.name ?? 'No plan yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (session != null)
                        Text(
                          '${session.completedSets}/${session.plannedSets} sets done',
                          style: const TextStyle(
                            color: Palette.gold,
                            fontSize: 13,
                          ),
                        )
                      else if (nextDay != null)
                        Text(
                          '${nextDay.exercises.length} exercises · ${nextDay.focus}',
                          style: const TextStyle(
                            color: Palette.textDim,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Palette.textDim),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          // Nutrition card.
          Panel(
            onTap: () => Shell.goTo(Shell.food),
            child: Row(
              children: [
                CalorieRing(
                  eaten: totals.kcal,
                  target: fitness.targets.calories,
                  size: 104,
                ),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Column(
                    children: [
                      LabeledBar(
                        label: 'Protein',
                        valueText:
                            '${totals.proteinG.round()}/${fitness.targets.proteinG} g',
                        value: totals.proteinG / fitness.targets.proteinG,
                        color: Palette.protein,
                      ),
                      const SizedBox(height: Space.sm),
                      LabeledBar(
                        label: 'Carbs',
                        valueText:
                            '${totals.carbsG.round()}/${fitness.targets.carbsG} g',
                        value: fitness.targets.carbsG == 0
                            ? 0
                            : totals.carbsG / fitness.targets.carbsG,
                        color: Palette.carbs,
                      ),
                      const SizedBox(height: Space.sm),
                      LabeledBar(
                        label: 'Fat',
                        valueText:
                            '${totals.fatG.round()}/${fitness.targets.fatG} g',
                        value: totals.fatG / fitness.targets.fatG,
                        color: Palette.fat,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          // Adventure card.
          Panel(
            onTap: () => Shell.goTo(Shell.adventure),
            gradient: nextStage == null
                ? null
                : LinearGradient(
                    colors: [
                      Palette.backdrop(nextStage.region.element).first,
                      Palette.surface,
                    ],
                  ),
            child: Row(
              children: [
                const GameIcon('treasure-map', size: 36, color: Palette.gold),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Adventure',
                        style: TextStyle(color: Palette.textDim, fontSize: 13),
                      ),
                      Text(
                        nextStage == null
                            ? 'Endless Tower · floor ${progress.endlessFloor}'
                            : nextStage.opponentName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        nextStage == null
                            ? 'Best: floor ${progress.bestEndlessFloor}'
                            : '${nextStage.region.name} · Lv ${nextStage.level}',
                        style: const TextStyle(
                          color: Palette.textDim,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Palette.textDim),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final String icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Panel(
    padding: const EdgeInsets.symmetric(
      horizontal: Space.sm,
      vertical: Space.md,
    ),
    child: Column(
      children: [
        GameIcon(icon, size: 26, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Palette.textDim, fontSize: 11),
        ),
      ],
    ),
  );
}
