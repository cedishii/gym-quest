import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/app_scope.dart';
import '../../../config/balance.dart';
import '../../../domain/progression/achievements.dart';
import '../../../domain/progression/streaks.dart';
import '../../theme/tokens.dart';
import '../../widgets/bars.dart';
import '../../widgets/feedback.dart';
import '../../widgets/game_icon.dart';
import '../../widgets/panel.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final ctx = app.achievementContext();
    final unlocked = app.save.achievements;
    final streak = app.streak;
    final claimed = app.save.claimedMilestones;
    final wins = app.battlesWon;
    final losses = app.save.battles.length - wins;

    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xl),
        children: [
          Panel(
            child: Row(
              children: [
                GameIcon(
                  'flame',
                  size: 40,
                  color: streak.alive ? Palette.warning : Palette.textFaint,
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${streak.current}-day streak',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Longest: ${streak.longest} days · one rest day between workouts is fine',
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
          const SectionHeader('Streak milestones'),
          for (final days in Balance.streakMilestoneDays)
            _Tile(
              icon: 'flame',
              title: StreakMilestones.title(days),
              description: 'Keep a $days-day workout streak',
              done: claimed.contains(days),
              progress: (streak.current / days).clamp(0.0, 1.0),
              progressText: '${streak.current.clamp(0, days)}/$days',
              reward: RewardList(StreakMilestones.reward(days)),
            ),
          SectionHeader(
            'Achievements (${unlocked.length}/${Achievements.all.length})',
          ),
          for (final a in Achievements.all)
            _Tile(
              icon: a.icon,
              title: a.title,
              description: a.description,
              done: unlocked.containsKey(a.id),
              doneAt: unlocked[a.id],
              progress: (a.progress(ctx) / a.goal).clamp(0.0, 1.0),
              progressText: '${a.progress(ctx).clamp(0, a.goal)}/${a.goal}',
              reward: RewardList(a.reward),
            ),
          const SectionHeader('Battle history'),
          Text(
            '$wins wins · $losses losses',
            style: const TextStyle(color: Palette.textDim),
          ),
          const SizedBox(height: Space.sm),
          for (final b in app.save.battles.reversed.take(20))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    b.won ? Icons.emoji_events_rounded : Icons.close_rounded,
                    size: 18,
                    color: b.won ? Palette.gold : Palette.textFaint,
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      '${b.opponent}${b.endlessFloor != null ? ' (floor ${b.endlessFloor})' : ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    DateFormat('MMM d').format(b.at.toLocal()),
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
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.description,
    required this.done,
    required this.progress,
    required this.progressText,
    required this.reward,
    this.doneAt,
  });

  final String icon;
  final String title;
  final String description;
  final bool done;
  final DateTime? doneAt;
  final double progress;
  final String progressText;
  final Widget reward;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.sm),
    child: Panel(
      borderColor: done ? Palette.gold.withValues(alpha: 0.6) : Palette.border,
      padding: const EdgeInsets.all(Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GameIcon(
            icon,
            size: 34,
            color: done ? Palette.gold : Palette.textFaint,
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: done ? Palette.gold : Palette.text,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(color: Palette.textDim, fontSize: 13),
                ),
                const SizedBox(height: 6),
                if (done)
                  Text(
                    doneAt == null
                        ? 'Unlocked'
                        : 'Unlocked ${DateFormat('MMM d, y').format(doneAt!.toLocal())}',
                    style: const TextStyle(color: Palette.hp, fontSize: 12),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: GameBar(
                          value: progress,
                          color: Palette.violet,
                          height: 6,
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Text(
                        progressText,
                        style: const TextStyle(
                          color: Palette.textDim,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 4),
                DefaultTextStyle.merge(
                  style: const TextStyle(fontSize: 12),
                  child: reward,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
