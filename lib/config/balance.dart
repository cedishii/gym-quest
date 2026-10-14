/// Every game-balance number lives here so tuning never means hunting
/// through screens. Each value notes what it controls. Formulas that use
/// these values are in lib/domain (rewards, pet progression, combat, map).
///
/// Pacing target: a player who completes ~3 full workouts a week reaches
/// the final gym leader's level (~38) in roughly 3–4 months. Personal
/// records and a higher training tier speed this up for fitter players.
class Balance {
  const Balance._();

  // ---------------------------------------------------------------- pets --

  /// XP needed to go from [level] to [level] + 1.
  static int xpToNext(int level) => 60 + 8 * level;

  static const int maxPetLevel = 100;

  /// Pet sprite scale grows with level, then stops so it always fits the
  /// screen. Strength beyond the cap shows through aura tiers instead.
  static const double petMinScale = 0.62;
  static const double petMaxScale = 1.0;
  static const int petScaleCapLevel = 30;

  /// Levels at which the pet gains a visual tier (glow, aura, stars, crown).
  static const List<int> auraTierLevels = [10, 20, 30, 45];

  // ----------------------------------------------------- food for pets --

  /// XP granted by each pet food when fed.
  static const int kibbleXp = 25;
  static const int steakXp = 70;
  static const int feastXp = 200;

  // ------------------------------------------------------ workout rewards --

  /// Kibble for every exercise with at least one completed set.
  static const int kibblePerExercise = 1;

  /// Extra steak for completing every planned set of the workout.
  static const int steakForFullWorkout = 1;

  /// Minimum share of planned sets that counts as a "full" workout.
  static const double fullWorkoutThreshold = 1.0;

  /// One steak per meaningful personal record...
  static const int steakPerPersonalRecord = 1;

  /// ...for at most this many records in one workout, so typing an
  /// inflated weight cannot mint unlimited food.
  static const int maxRewardedRecordsPerWorkout = 3;

  /// Bonus kibble share per training tier above 1 (tier 3 => +50%).
  static const double tierKibbleBonus = 0.25;

  /// Doing more sets than planned does not add rewards: completion is
  /// capped at 100% so over-training is never encouraged.
  static const double maxCompletion = 1.0;

  // ------------------------------------------------ personal records --

  /// A record must beat the previous best by this much to count.
  static const double prMinWeightImprovement = 0.02; // +2% estimated 1RM
  static const int prMinRepImprovement = 1;
  static const int prMinSecondsImprovement = 5;

  // ---------------------------------------------------- training tier --

  /// Completed workouts needed to reach tier 2, 3, 4, 5.
  static const List<int> tierWorkoutThresholds = [12, 30, 60, 100];
  static const int maxTier = 5;

  // ----------------------------------------------------------- streaks --

  /// Workouts may be up to this many calendar days apart and still keep a
  /// streak alive (2 = one rest day between workouts is fine).
  static const int streakMaxGapDays = 2;

  /// Streak lengths (days) that award a milestone.
  static const List<int> streakMilestoneDays = [7, 14, 21, 28, 30];

  // ------------------------------------------------------------ combat --

  static const int strikePower = 35;
  static const int blastPower = 50;
  static const int ultimatePower = 85;
  static const int blastAccuracy = 95;
  static const int ultimateAccuracy = 90;

  /// Turns of charging before the ultimate can be used (and again after).
  static const int ultimateChargeTurns = 3;

  /// Guard halves the next hit and heals this share of max HP.
  static const double guardDamageFactor = 0.5;
  static const double guardHealShare = 0.08;

  static const double critChance = 0.0625;
  static const double critMultiplier = 1.5;
  static const double minDamageRoll = 0.85;

  static const double superEffective = 1.4;
  static const double notVeryEffective = 0.75;

  /// Battles stop after this many rounds (counted as a loss) so a stalemate
  /// between two guarding monsters cannot run forever.
  static const int maxBattleRounds = 60;

  // --------------------------------------------------------------- map --

  /// Enemy level for story stage [index] (0-based).
  static int stageEnemyLevel(int index) => (2 + index * 1.9).round();

  /// Stat multipliers for the different kinds of opponents.
  static const double wildStatMultiplier = 0.95;
  static const double trainerStatMultiplier = 1.0;
  static const double leaderStatMultiplier = 1.12;
  static const double leaderHpMultiplier = 1.3;

  // ------------------------------------------------------- endless mode --

  /// Endless floor n (1-based): enemy HP grows a little every floor.
  static const double endlessHpGrowthPerFloor = 0.06;
  static const int endlessBaseLevel = 38;
  static const int endlessFloorsPerLevel = 3;

  /// An equipment drop every this many endless floors cleared.
  static const int endlessItemEveryFloors = 10;
}
