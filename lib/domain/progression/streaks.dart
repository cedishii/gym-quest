import '../../config/balance.dart';
import '../../core/dates.dart';
import '../pet/pet_food.dart';
import '../rewards/reward.dart';

class StreakInfo {
  const StreakInfo({
    required this.current,
    required this.longest,
    required this.alive,
    this.lastWorkoutDay,
    this.daysUntilBreak,
  });

  static const empty = StreakInfo(current: 0, longest: 0, alive: false);

  /// Length in calendar days of the active streak (first to latest workout).
  final int current;
  final int longest;
  final bool alive;
  final String? lastWorkoutDay;

  /// Days left to train before the streak breaks (0 = must train today).
  final int? daysUntilBreak;
}

/// Workout streaks. Rest days are allowed: workouts may be up to
/// Balance.streakMaxGapDays apart (default 2, i.e. one rest day between
/// sessions) without breaking the streak, so the streak never pushes daily
/// training.
class Streaks {
  const Streaks._();

  static StreakInfo compute(Iterable<String> workoutDays, DateTime today) {
    final days = workoutDays.toSet().toList()..sort();
    if (days.isEmpty) return StreakInfo.empty;

    var longest = 0;
    var chainStart = days.first;
    var previous = days.first;
    for (final day in days.skip(1)) {
      if (Day.betweenKeys(previous, day) > Balance.streakMaxGapDays) {
        longest = _max(longest, Day.betweenKeys(chainStart, previous) + 1);
        chainStart = day;
      }
      previous = day;
    }
    final lastChain = Day.betweenKeys(chainStart, previous) + 1;
    longest = _max(longest, lastChain);

    final sinceLast = Day.between(Day.parse(previous), Day.dateOnly(today));
    final alive = sinceLast <= Balance.streakMaxGapDays;
    return StreakInfo(
      current: alive ? lastChain : 0,
      longest: longest,
      alive: alive,
      lastWorkoutDay: previous,
      daysUntilBreak: alive ? Balance.streakMaxGapDays - sinceLast : null,
    );
  }

  static int _max(int a, int b) => a > b ? a : b;
}

/// Rewards for reaching streak lengths. Each milestone is awarded once.
class StreakMilestones {
  const StreakMilestones._();

  static String title(int days) => switch (days) {
    7 => 'One Week Strong',
    14 => 'Two Week Warrior',
    21 => 'Three Week Titan',
    28 => 'Four Week Legend',
    30 => 'One Month Hero',
    _ => '$days-Day Streak',
  };

  static Reward reward(int days) => switch (days) {
    7 => const Reward(food: {PetFood.feast: 1}),
    14 => const Reward(food: {PetFood.feast: 1}, items: ['amulet_charm']),
    21 => const Reward(food: {PetFood.feast: 2}),
    28 => const Reward(food: {PetFood.feast: 2}, items: ['boots_runner']),
    30 => const Reward(food: {PetFood.feast: 3}, items: ['amulet_gauntlet']),
    _ => const Reward(food: {PetFood.feast: 1}),
  };

  /// Milestones reached by [streak] that have not been claimed yet.
  static List<int> newlyReached(int streak, Set<int> claimed) => Balance
      .streakMilestoneDays
      .where((days) => streak >= days && !claimed.contains(days))
      .toList();
}
