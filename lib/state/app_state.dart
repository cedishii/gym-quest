import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../audio/sound_service.dart';
import '../core/dates.dart';
import '../core/ids.dart';
import '../core/json.dart';
import '../data/exercise/exercise_repository.dart';
import '../data/persistence/game_save.dart';
import '../data/persistence/save_store.dart';
import '../domain/combat/battle.dart';
import '../domain/combat/battle_record.dart';
import '../domain/combat/element.dart';
import '../domain/inventory/equipment.dart';
import '../domain/inventory/items.dart';
import '../domain/map/stages.dart';
import '../domain/nutrition/food.dart';
import '../domain/nutrition/food_log.dart';
import '../domain/pet/pet.dart';
import '../domain/pet/pet_food.dart';
import '../domain/pet/stats.dart';
import '../domain/profile/fitness_calc.dart';
import '../domain/profile/profile.dart';
import '../domain/progression/achievements.dart';
import '../domain/progression/streaks.dart';
import '../domain/rewards/reward.dart';
import '../domain/rewards/workout_rewards.dart';
import '../domain/workout/personal_records.dart';
import '../domain/workout/planner.dart';
import '../domain/workout/workout_plan.dart';
import '../domain/workout/workout_record.dart';
import '../domain/workout/workout_session.dart';

/// Thrown for actions the user cannot take right now; [message] is shown
/// to them as-is.
class GameActionException implements Exception {
  const GameActionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Something earned as a side effect (achievement or streak milestone).
class Unlock {
  const Unlock({
    required this.title,
    required this.description,
    required this.reward,
    required this.icon,
  });

  final String title;
  final String description;
  final Reward reward;
  final String icon;
}

class WorkoutOutcome {
  const WorkoutOutcome({
    required this.record,
    required this.unlocks,
    required this.streak,
  });

  final WorkoutRecord record;
  final List<Unlock> unlocks;
  final StreakInfo streak;
}

class FeedOutcome {
  const FeedOutcome({
    required this.result,
    required this.food,
    required this.count,
    required this.unlocks,
  });

  final XpResult result;
  final PetFood food;
  final int count;
  final List<Unlock> unlocks;
}

class BattleOutcome {
  const BattleOutcome({
    required this.won,
    required this.reward,
    required this.firstClear,
    required this.unlocks,
    this.unlockedNext,
  });

  final bool won;
  final Reward reward;
  final bool firstClear;
  final List<Unlock> unlocks;

  /// Description of what this win opened up (next stage, endless mode).
  final String? unlockedNext;
}

/// The single source of truth. Screens read from it and call its methods;
/// every change is written to the [SaveStore] right away.
class AppState extends ChangeNotifier {
  AppState({
    required GameSave save,
    required this.store,
    required this.exercises,
    SoundService? sound,
    DateTime Function()? clock,
    Random? random,
    this.loadWarning,
  }) : _save = save, // ignore: prefer_initializing_formals
       sound = sound ?? const SilentSound(),
       _clock = clock ?? DateTime.now,
       _random = random ?? Random() {
    _applySoundSettings();
  }

  final SaveStore store;
  final ExerciseRepository exercises;
  final SoundService sound;
  final DateTime Function() _clock;
  final Random _random;

  /// Set when the save could not be read and a backup or fresh start was used.
  final String? loadWarning;

  GameSave _save;
  GameSave get save => _save;

  Future<void> _pendingWrite = Future.value();

  /// Loads the save from [store], falling back to its backup copy.
  static Future<AppState> load({
    required SaveStore store,
    required ExerciseRepository exercises,
    SoundService? sound,
    DateTime Function()? clock,
    Random? random,
  }) async {
    String? warning;
    GameSave? save;
    final main = await store.read();
    if (main != null) {
      save = _tryParse(main);
      if (save == null) {
        final backup = await store.readBackup();
        save = backup == null ? null : _tryParse(backup);
        warning = save == null
            ? 'Your save file could not be read, so a new game was started.'
            : 'Your latest save was damaged; the previous save was restored.';
      }
    }
    return AppState(
      save: save ?? const GameSave(),
      store: store,
      exercises: exercises,
      sound: sound,
      clock: clock,
      random: random,
      loadWarning: warning,
    );
  }

  static GameSave? _tryParse(String text) {
    try {
      return GameSave.fromJson(asMap(jsonDecode(text)));
    } catch (e) {
      debugPrint('save parse failed: $e');
      return null;
    }
  }

  DateTime get now => _clock();
  String get today => Day.key(now);

  /// Applies [next], notifies listeners and queues a write. Writes run one
  /// after another so a slow write can never land after a newer one.
  void _commit(GameSave next) {
    _save = next;
    notifyListeners();
    final data = jsonEncode(next.toJson());
    _pendingWrite = _pendingWrite.then((_) => store.write(data)).catchError((
      Object e,
    ) {
      debugPrint('save failed: $e');
    });
  }

  /// Completes when every queued write has finished (used by tests).
  Future<void> flush() => _pendingWrite;

  // ------------------------------------------------------------ profile --

  Profile? get profile => _save.profile;

  FitnessSummary? get fitness =>
      profile == null ? null : FitnessCalc.summarize(profile!);

  int get experienceTier => switch (profile?.experience) {
    Experience.intermediate => 2,
    Experience.advanced => 3,
    _ => 1,
  };

  int get trainingTier => WorkoutRewards.tier(
    completedWorkouts: _save.workouts.length,
    experienceTier: experienceTier,
  );

  /// Finishes onboarding: saves the profile, adopts the pet, gives a few
  /// starter snacks and generates the first plan.
  void completeOnboarding({
    required Profile profile,
    required PetElement element,
    required String petName,
  }) {
    final name = petName.trim();
    if (name.isEmpty || name.length > 16) {
      throw const GameActionException(
        'Give your pet a name (up to 16 letters).',
      );
    }
    final pet = Pet(
      element: element,
      name: name,
      level: 1,
      xp: 0,
      adoptedAt: now,
    );
    var next = _save.copyWith(
      profile: profile,
      pet: pet,
      petFood: {
        ..._save.petFood,
        PetFood.kibble: (_save.petFood[PetFood.kibble] ?? 0) + 2,
      },
    );
    next = next.copyWith(plan: _generatePlan(next));
    _commit(next);
  }

  /// Saves profile changes. The plan is regenerated when training inputs change.
  void updateProfile(Profile updated) {
    final old = profile;
    var next = _save.copyWith(profile: updated);
    final trainingChanged =
        old == null ||
        old.goal != updated.goal ||
        old.experience != updated.experience ||
        old.equipment != updated.equipment ||
        old.daysPerWeek != updated.daysPerWeek;
    if (trainingChanged) next = next.copyWith(plan: _generatePlan(next));
    _commit(next);
  }

  // ---------------------------------------------------------- nutrition --

  List<FoodLogEntry> entriesFor(String day) =>
      _save.foodLog.where((e) => e.day == day).toList()
        ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));

  Nutrients totalsFor(String day) => NutritionMath.total(entriesFor(day));

  /// Recently logged foods, most recent first, without duplicates.
  List<Food> get recentFoods {
    final seen = <String>{};
    final result = <Food>[];
    for (final entry in _save.foodLog.reversed) {
      if (seen.add(entry.food.key)) result.add(entry.food);
      if (result.length >= 20) break;
    }
    return result;
  }

  List<Unlock> logFood({
    required Food food,
    required double grams,
    required Meal meal,
    required String day,
    String? servingLabel,
  }) {
    final error = NutritionMath.validateGrams(grams);
    if (error != null) throw GameActionException(error);
    final entry = FoodLogEntry(
      id: newId('f'),
      day: day,
      meal: meal,
      food: food,
      grams: grams,
      servingLabel: servingLabel,
      loggedAt: now,
    );
    final result = _withAchievements(
      _save.copyWith(foodLog: [..._save.foodLog, entry]),
    );
    _commit(result.$1);
    return result.$2;
  }

  void removeFoodEntry(String id) {
    _commit(
      _save.copyWith(foodLog: _save.foodLog.where((e) => e.id != id).toList()),
    );
  }

  Food addCustomFood({
    required String name,
    required Nutrients per100g,
    Serving? serving,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const GameActionException('Name the food');
    if (per100g.kcal < 0 || per100g.kcal > 900) {
      throw const GameActionException('Calories per 100 g must be 0–900');
    }
    if (per100g.proteinG < 0 || per100g.fatG < 0 || per100g.carbsG < 0) {
      throw const GameActionException('Nutrients cannot be negative');
    }
    if (per100g.proteinG + per100g.fatG + per100g.carbsG > 100) {
      throw const GameActionException(
        'Protein, fat and carbs add up to more than 100 g',
      );
    }
    final food = Food(
      id: newId('c'),
      name: trimmed,
      source: FoodSource.custom,
      per100g: per100g,
      servings: serving == null ? const [] : [serving],
    );
    _commit(_save.copyWith(customFoods: [..._save.customFoods, food]));
    return food;
  }

  void deleteCustomFood(String id) {
    _commit(
      _save.copyWith(
        customFoods: _save.customFoods.where((f) => f.id != id).toList(),
      ),
    );
  }

  // ------------------------------------------------------------ workouts --

  WorkoutPlan? get plan => _save.plan;
  WorkoutSession? get activeSession => _save.activeSession;

  WorkoutPlan? _generatePlan(GameSave s) {
    final p = s.profile;
    if (p == null) return null;
    final summary = FitnessCalc.summarize(p);
    final tier = WorkoutRewards.tier(
      completedWorkouts: s.workouts.length,
      experienceTier: switch (p.experience) {
        Experience.intermediate => 2,
        Experience.advanced => 3,
        Experience.beginner => 1,
      },
    );
    return WorkoutPlanner(exercises.exercises).generate(
      PlannerInput(
        goal: p.goal,
        experience: p.experience,
        equipment: p.equipment,
        daysPerWeek: p.daysPerWeek,
        bmiCategory: summary.bmiCategory,
        tier: tier,
      ),
      now: now,
    );
  }

  void regeneratePlan() {
    if (profile == null) {
      throw const GameActionException('Create your profile first.');
    }
    _commit(_save.copyWith(plan: _generatePlan(_save)));
  }

  /// Plan day suggested for today: the one after the last finished workout.
  int get suggestedDayIndex {
    final days = plan?.days ?? const [];
    if (days.isEmpty) return 0;
    if (_save.workouts.isEmpty) return 0;
    final lastName = _save.workouts.last.dayName;
    final index = days.indexWhere((d) => d.name == lastName);
    return index < 0 ? 0 : (index + 1) % days.length;
  }

  WorkoutSession startSession(int dayIndex) {
    if (activeSession != null) return activeSession!;
    final days = plan?.days ?? const [];
    if (dayIndex < 0 || dayIndex >= days.length) {
      throw const GameActionException('That workout day does not exist.');
    }
    final day = days[dayIndex];
    final session = WorkoutSession(
      id: newId('w'),
      dayName: day.name,
      startedAt: now,
      exercises: day.exercises.map(ExerciseLog.fromPlan).toList(),
    );
    _commit(_save.copyWith(activeSession: session));
    return session;
  }

  void updateSet(int exerciseIndex, int setIndex, SetLog set) {
    final session = activeSession;
    if (session == null) return;
    final log = session.exercises[exerciseIndex];
    if (set.done) {
      final error = set.validate(timed: log.planned.isTimed);
      if (error != null) throw GameActionException(error);
    }
    _commit(
      _save.copyWith(
        activeSession: session.withExercise(
          exerciseIndex,
          log.withSet(setIndex, set),
        ),
      ),
    );
  }

  void addSet(int exerciseIndex) {
    final session = activeSession;
    if (session == null) return;
    final log = session.exercises[exerciseIndex];
    if (log.sets.length >= 10) {
      throw const GameActionException('10 sets is the limit.');
    }
    _commit(
      _save.copyWith(
        activeSession: session.withExercise(exerciseIndex, log.withExtraSet()),
      ),
    );
  }

  void cancelSession() => _commit(_save.copyWith(activeSession: null));

  /// Finishes the active workout: records it, detects personal records and
  /// grants the reward exactly once.
  WorkoutOutcome finishSession() {
    final session = activeSession;
    if (session == null) {
      throw const GameActionException('No workout in progress.');
    }
    if (session.completedSets == 0) {
      throw const GameActionException(
        'Complete at least one set before finishing.',
      );
    }
    if (_save.rewardedWorkoutIds.contains(session.id)) {
      // Already rewarded (e.g. a double tap): just close the session.
      _commit(_save.copyWith(activeSession: null));
      throw const GameActionException('This workout was already saved.');
    }

    final finishedAt = now;
    final evaluation = PersonalRecords.evaluate(
      existing: _save.records,
      logs: session.exercises,
      isTimed: exercises.isTimed,
      at: finishedAt,
    );
    final tier = trainingTier;
    final reward = WorkoutRewards.forWorkout(
      session: session,
      recordHits: evaluation.hits,
      tier: tier,
    );

    final record = WorkoutRecord(
      id: session.id,
      dayName: session.dayName,
      startedAt: session.startedAt,
      finishedAt: finishedAt,
      exercises: session.exercises,
      completion: min(1.0, session.completion),
      estimatedKcal: _estimateKcal(session, finishedAt),
      recordHits: evaluation.hits,
      reward: reward,
    );

    var next = _grant(_save, reward).copyWith(
      activeSession: null,
      workouts: [..._save.workouts, record],
      records: evaluation.records,
      rewardedWorkoutIds: {..._save.rewardedWorkoutIds, session.id},
    );

    // Streak milestones.
    final unlocks = <Unlock>[];
    final streak = Streaks.compute(
      next.workouts.map((w) => Day.key(w.finishedAt)),
      finishedAt,
    );
    final reached = StreakMilestones.newlyReached(
      streak.current,
      next.claimedMilestones,
    );
    for (final days in reached) {
      final milestoneReward = StreakMilestones.reward(days);
      next = _grant(
        next,
        milestoneReward,
      ).copyWith(claimedMilestones: {...next.claimedMilestones, days});
      unlocks.add(
        Unlock(
          title: StreakMilestones.title(days),
          description: '$days-day workout streak',
          reward: milestoneReward,
          icon: 'flame',
        ),
      );
    }

    final withAchievements = _withAchievements(next);
    unlocks.addAll(withAchievements.$2);
    _commit(withAchievements.$1);
    return WorkoutOutcome(record: record, unlocks: unlocks, streak: streak);
  }

  double _estimateKcal(WorkoutSession session, DateTime finishedAt) {
    final weight = profile?.weightKg ?? 70;
    var minutes = finishedAt.difference(session.startedAt).inSeconds / 60;
    // Clamp to a plausible workout length so a session left open overnight
    // does not claim thousands of calories.
    final timedMinutes =
        session.exercises
            .expand((e) => e.sets.where((s) => s.done))
            .fold<int>(0, (sum, s) => sum + s.seconds) /
        60;
    minutes = minutes.clamp(max(5.0, timedMinutes), 180.0);
    var metSum = 0.0;
    var sets = 0;
    for (final log in session.exercises) {
      final done = log.completedSets;
      metSum += (exercises.byId(log.exerciseId)?.met ?? 4) * done;
      sets += done;
    }
    final met = sets == 0 ? 3.5 : metSum / sets;
    return FitnessCalc.estimateCalories(
      met: met,
      weightKg: weight,
      duration: Duration(seconds: (minutes * 60).round()),
    );
  }

  StreakInfo get streak =>
      Streaks.compute(_save.workouts.map((w) => Day.key(w.finishedAt)), now);

  List<WorkoutRecord> get workoutHistory => _save.workouts.reversed.toList();

  // ----------------------------------------------------------------- pet --

  Pet? get pet => _save.pet;

  int foodCount(PetFood food) => _save.petFood[food] ?? 0;

  List<ItemDef> get equippedItems =>
      Equipment.resolve(_save.equipped, _save.inventory);

  Stats? get petStats =>
      pet == null ? null : Equipment.petStats(pet!, equippedItems);

  Stats? get petBaseStats => pet?.species.statsAt(pet!.level);

  FeedOutcome feed(PetFood food, {int count = 1}) {
    final current = pet;
    if (current == null) throw const GameActionException('Adopt a pet first.');
    if (count < 1) throw const GameActionException('Feed at least one.');
    final have = foodCount(food);
    if (have < count) {
      throw GameActionException(
        'You have no ${food.label} left. Work out to earn more!',
      );
    }
    if (current.isMaxLevel) {
      throw const GameActionException('Your pet is already at max level.');
    }
    final result = PetProgression.addXp(current, food.xp * count);
    final next = _save.copyWith(
      pet: result.pet,
      petFood: {..._save.petFood, food: have - count},
    );
    final withAchievements = _withAchievements(next);
    _commit(withAchievements.$1);
    return FeedOutcome(
      result: result,
      food: food,
      count: count,
      unlocks: withAchievements.$2,
    );
  }

  void renamePet(String name) {
    final trimmed = name.trim();
    if (pet == null) return;
    if (trimmed.isEmpty || trimmed.length > 16) {
      throw const GameActionException('Pet names are 1–16 letters.');
    }
    _commit(_save.copyWith(pet: pet!.copyWith(name: trimmed)));
  }

  // ------------------------------------------------------------ inventory --

  List<OwnedItem> get inventory => _save.inventory;

  Map<EquipSlot, String> get equipped => _save.equipped;

  OwnedItem? equippedIn(EquipSlot slot) {
    final id = _save.equipped[slot];
    if (id == null) return null;
    for (final item in _save.inventory) {
      if (item.instanceId == id) return item;
    }
    return null;
  }

  List<Unlock> equip(String instanceId) {
    final item = _save.inventory
        .where((i) => i.instanceId == instanceId)
        .firstOrNull;
    final def = item?.def;
    if (item == null || def == null) {
      throw const GameActionException('Item not found.');
    }
    final next = _save.copyWith(
      equipped: {..._save.equipped, def.slot: instanceId},
    );
    final withAchievements = _withAchievements(next);
    _commit(withAchievements.$1);
    return withAchievements.$2;
  }

  void unequip(EquipSlot slot) {
    final next = Map<EquipSlot, String>.from(_save.equipped)..remove(slot);
    _commit(_save.copyWith(equipped: next));
  }

  // ------------------------------------------------------------- battles --

  MapProgress get mapProgress => _save.map;

  Combatant playerCombatant() {
    final current = pet;
    if (current == null) throw const GameActionException('Adopt a pet first.');
    return Combatant.fromStats(
      name: current.name,
      element: current.element,
      level: current.level,
      stats: petStats!,
    );
  }

  BattleState startStageBattle(int stageIndex) {
    if (stageIndex < 0 || stageIndex >= GameMap.stages.length) {
      throw const GameActionException('Unknown stage.');
    }
    if (!mapProgress.isUnlocked(stageIndex)) {
      throw const GameActionException('Clear the previous stage first.');
    }
    return BattleState(
      player: playerCombatant(),
      enemy: GameMap.stages[stageIndex].enemy(),
    );
  }

  BattleState startEndlessBattle() {
    if (!mapProgress.endlessUnlocked) {
      throw const GameActionException(
        'Beat the Arena Champion to open the Endless Tower.',
      );
    }
    return BattleState(
      player: playerCombatant(),
      enemy: GameMap.endlessEnemy(mapProgress.endlessFloor),
    );
  }

  /// Records a finished story battle and grants first-clear rewards once.
  BattleOutcome finishStageBattle(int stageIndex, BattleState result) {
    if (!result.finished) {
      throw const GameActionException('The battle is not over yet.');
    }
    if (!mapProgress.isUnlocked(stageIndex)) {
      throw const GameActionException('That stage is locked.');
    }
    final stage = GameMap.stages[stageIndex];
    final won = result.winner == Side.player;
    final firstClear = won && !mapProgress.isCleared(stageIndex);
    var next = _save.copyWith(
      battles: [
        ..._save.battles,
        BattleRecord(
          id: newId('b'),
          at: now,
          opponent: stage.opponentName,
          won: won,
          rounds: result.round,
          petLevel: pet?.level ?? 1,
          stageIndex: stageIndex,
        ),
      ],
    );
    String? unlockedNext;
    if (firstClear) {
      next = _grant(
        next,
        stage.reward,
      ).copyWith(map: next.map.withCleared(stageIndex));
      if (stageIndex == GameMap.lastStoryIndex) {
        unlockedNext = 'The Endless Tower is open!';
      } else {
        final upcoming = GameMap.stages[stageIndex + 1];
        unlockedNext =
            'Unlocked: ${upcoming.opponentName} (Lv ${upcoming.level})';
      }
    }
    final withAchievements = _withAchievements(next);
    _commit(withAchievements.$1);
    return BattleOutcome(
      won: won,
      reward: firstClear ? stage.reward : Reward.none,
      firstClear: firstClear,
      unlocks: withAchievements.$2,
      unlockedNext: unlockedNext,
    );
  }

  BattleOutcome finishEndlessBattle(BattleState result) {
    if (!result.finished) {
      throw const GameActionException('The battle is not over yet.');
    }
    final floor = mapProgress.endlessFloor;
    final won = result.winner == Side.player;
    var next = _save.copyWith(
      battles: [
        ..._save.battles,
        BattleRecord(
          id: newId('b'),
          at: now,
          opponent: result.enemy.name,
          won: won,
          rounds: result.round,
          petLevel: pet?.level ?? 1,
          endlessFloor: floor,
        ),
      ],
    );
    var reward = Reward.none;
    if (won) {
      reward = GameMap.endlessReward(floor);
      next = _grant(
        next,
        reward,
      ).copyWith(map: next.map.withEndlessCleared(floor));
    }
    final withAchievements = _withAchievements(next);
    _commit(withAchievements.$1);
    return BattleOutcome(
      won: won,
      reward: reward,
      firstClear: won,
      unlocks: withAchievements.$2,
      unlockedNext: won ? 'Next: floor ${floor + 1}' : null,
    );
  }

  int get battlesWon => _save.battles.where((b) => b.won).length;

  // -------------------------------------------------------- achievements --

  AchievementContext achievementContext([GameSave? s]) {
    final save = s ?? _save;
    final streakInfo = Streaks.compute(
      save.workouts.map((w) => Day.key(w.finishedAt)),
      now,
    );
    return AchievementContext(
      workouts: save.workouts.length,
      recordImprovements: save.workouts.fold(
        0,
        (sum, w) => sum + w.improvements,
      ),
      petLevel: save.pet?.level ?? 0,
      battlesWon: save.battles.where((b) => b.won).length,
      badges: save.map.badges,
      bestEndlessFloor: save.map.bestEndlessFloor,
      foodLogDays: save.foodLog.map((e) => e.day).toSet().length,
      longestStreak: streakInfo.longest,
      equippedSlots: Equipment.resolve(save.equipped, save.inventory).length,
    );
  }

  /// Unlocks newly met achievements on [s] and grants their rewards.
  (GameSave, List<Unlock>) _withAchievements(GameSave s) {
    final unlocked = Achievements.newlyUnlocked(
      achievementContext(s),
      s.achievements.keys.toSet(),
    );
    if (unlocked.isEmpty) return (s, const []);
    var next = s;
    final at = now;
    final unlocks = <Unlock>[];
    for (final a in unlocked) {
      next = _grant(
        next,
        a.reward,
      ).copyWith(achievements: {...next.achievements, a.id: at});
      unlocks.add(
        Unlock(
          title: a.title,
          description: a.description,
          reward: a.reward,
          icon: a.icon,
        ),
      );
    }
    return (next, unlocks);
  }

  // ------------------------------------------------------------- rewards --

  GameSave _grant(GameSave s, Reward reward) {
    if (reward.isEmpty) return s;
    final food = Map<PetFood, int>.from(s.petFood);
    reward.food.forEach((key, value) => food[key] = (food[key] ?? 0) + value);
    final items = [
      ...s.inventory,
      for (final id in reward.items)
        if (ItemCatalog.byId(id) != null)
          OwnedItem(instanceId: newId('i'), itemId: id, obtainedAt: now),
    ];
    return s.copyWith(petFood: food, inventory: items);
  }

  // ------------------------------------------------------------ settings --

  Settings get settings => _save.settings;

  void updateSettings(Settings settings) {
    _commit(_save.copyWith(settings: settings));
    _applySoundSettings();
  }

  void _applySoundSettings() {
    final s = _save.settings;
    sound.configure(music: s.music, sfx: s.sfx, musicVolume: s.musicVolume);
  }

  /// Deletes everything and returns to onboarding.
  Future<void> resetAll() async {
    await _pendingWrite;
    await store.clear();
    _save = GameSave(settings: _save.settings);
    notifyListeners();
  }

  /// Random number source for battles (seedable in tests).
  Random get random => _random;
}
