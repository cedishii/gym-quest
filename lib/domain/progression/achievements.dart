import '../pet/pet_food.dart';
import '../rewards/reward.dart';

/// Numbers achievements are checked against, gathered from the save.
class AchievementContext {
  const AchievementContext({
    required this.workouts,
    required this.recordImprovements,
    required this.petLevel,
    required this.battlesWon,
    required this.badges,
    required this.bestEndlessFloor,
    required this.foodLogDays,
    required this.longestStreak,
    required this.equippedSlots,
  });

  final int workouts;
  final int recordImprovements;
  final int petLevel;
  final int battlesWon;
  final int badges;
  final int bestEndlessFloor;
  final int foodLogDays;
  final int longestStreak;
  final int equippedSlots;
}

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.reward,
    required this.progress,
    required this.goal,
  });

  final String id;
  final String title;
  final String description;
  final String icon;
  final Reward reward;

  /// Current value toward [goal].
  final int Function(AchievementContext c) progress;
  final int goal;

  bool isMet(AchievementContext c) => progress(c) >= goal;
}

class Achievements {
  const Achievements._();

  static final all = <Achievement>[
    Achievement(
      id: 'first_workout',
      title: 'First Rep',
      icon: 'weight-lifting',
      description: 'Complete your first workout.',
      reward: const Reward(food: {PetFood.kibble: 3}),
      progress: (c) => c.workouts,
      goal: 1,
    ),
    Achievement(
      id: 'workouts_10',
      title: 'Getting Serious',
      icon: 'biceps',
      description: 'Complete 10 workouts.',
      reward: const Reward(food: {PetFood.steak: 2}),
      progress: (c) => c.workouts,
      goal: 10,
    ),
    Achievement(
      id: 'workouts_50',
      title: 'Iron Habit',
      icon: 'fist',
      description: 'Complete 50 workouts.',
      reward: const Reward(food: {PetFood.feast: 2}),
      progress: (c) => c.workouts,
      goal: 50,
    ),
    Achievement(
      id: 'workouts_100',
      title: 'Century Club',
      icon: 'laurels',
      description: 'Complete 100 workouts.',
      reward: const Reward(food: {PetFood.feast: 3}, items: ['armor_plate']),
      progress: (c) => c.workouts,
      goal: 100,
    ),
    Achievement(
      id: 'first_pr',
      title: 'New Personal Best',
      icon: 'star-medal',
      description: 'Beat one of your personal records.',
      reward: const Reward(food: {PetFood.steak: 1}),
      progress: (c) => c.recordImprovements,
      goal: 1,
    ),
    Achievement(
      id: 'prs_10',
      title: 'Record Breaker',
      icon: 'medal',
      description: 'Beat personal records 10 times.',
      reward: const Reward(food: {PetFood.feast: 1}),
      progress: (c) => c.recordImprovements,
      goal: 10,
    ),
    Achievement(
      id: 'pet_10',
      title: 'Growing Up',
      icon: 'heart-plus',
      description: 'Raise your pet to level 10.',
      reward: const Reward(food: {PetFood.feast: 1}),
      progress: (c) => c.petLevel,
      goal: 10,
    ),
    Achievement(
      id: 'pet_20',
      title: 'Battle Ready',
      icon: 'swords-power',
      description: 'Raise your pet to level 20.',
      reward: const Reward(food: {PetFood.feast: 1}),
      progress: (c) => c.petLevel,
      goal: 20,
    ),
    Achievement(
      id: 'pet_30',
      title: 'Full Grown',
      icon: 'crown',
      description: 'Raise your pet to level 30.',
      reward: const Reward(food: {PetFood.feast: 2}),
      progress: (c) => c.petLevel,
      goal: 30,
    ),
    Achievement(
      id: 'first_win',
      title: 'First Victory',
      icon: 'crossed-swords',
      description: 'Win your first battle.',
      reward: const Reward(food: {PetFood.kibble: 3}),
      progress: (c) => c.battlesWon,
      goal: 1,
    ),
    Achievement(
      id: 'badge_1',
      title: 'Gym Challenger',
      icon: 'castle',
      description: 'Earn your first gym badge.',
      reward: const Reward(food: {PetFood.steak: 2}),
      progress: (c) => c.badges,
      goal: 1,
    ),
    Achievement(
      id: 'badge_5',
      title: 'Champion',
      icon: 'trophy',
      description: 'Earn all five gym badges.',
      reward: const Reward(food: {PetFood.feast: 3}),
      progress: (c) => c.badges,
      goal: 5,
    ),
    Achievement(
      id: 'endless_10',
      title: 'Tower Climber',
      icon: 'stone-tower',
      description: 'Clear floor 10 of the Endless Tower.',
      reward: const Reward(food: {PetFood.feast: 2}),
      progress: (c) => c.bestEndlessFloor,
      goal: 10,
    ),
    Achievement(
      id: 'food_7',
      title: 'Mindful Eater',
      icon: 'fruit-bowl',
      description: 'Log your food on 7 different days.',
      reward: const Reward(food: {PetFood.steak: 2}),
      progress: (c) => c.foodLogDays,
      goal: 7,
    ),
    Achievement(
      id: 'food_30',
      title: 'Nutrition Pro',
      icon: 'book',
      description: 'Log your food on 30 different days.',
      reward: const Reward(food: {PetFood.feast: 2}),
      progress: (c) => c.foodLogDays,
      goal: 30,
    ),
    Achievement(
      id: 'streak_30',
      title: 'Unbreakable',
      icon: 'flame',
      description: 'Keep a workout streak going for 30 days.',
      reward: const Reward(food: {PetFood.feast: 2}),
      progress: (c) => c.longestStreak,
      goal: 30,
    ),
    Achievement(
      id: 'full_set',
      title: 'Fully Geared',
      icon: 'backpack',
      description: 'Fill all five equipment slots.',
      reward: const Reward(food: {PetFood.steak: 1}),
      progress: (c) => c.equippedSlots,
      goal: 5,
    ),
  ];

  static Achievement? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Achievements met by [context] that are not in [unlocked] yet.
  static List<Achievement> newlyUnlocked(
    AchievementContext context,
    Set<String> unlocked,
  ) => all.where((a) => !unlocked.contains(a.id) && a.isMet(context)).toList();
}
