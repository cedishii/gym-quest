import '../../core/json.dart';
import '../../domain/combat/battle_record.dart';
import '../../domain/inventory/items.dart';
import '../../domain/map/stages.dart';
import '../../domain/nutrition/food.dart';
import '../../domain/nutrition/food_log.dart';
import '../../domain/pet/pet.dart';
import '../../domain/pet/pet_food.dart';
import '../../domain/profile/profile.dart';
import '../../domain/workout/personal_records.dart';
import '../../domain/workout/workout_plan.dart';
import '../../domain/workout/workout_record.dart';
import '../../domain/workout/workout_session.dart';

class Settings {
  const Settings({this.music = true, this.sfx = true, this.musicVolume = 0.45});

  final bool music;
  final bool sfx;
  final double musicVolume;

  Settings copyWith({bool? music, bool? sfx, double? musicVolume}) => Settings(
    music: music ?? this.music,
    sfx: sfx ?? this.sfx,
    musicVolume: musicVolume ?? this.musicVolume,
  );

  Map<String, dynamic> toJson() => {
    'music': music,
    'sfx': sfx,
    'musicVolume': musicVolume,
  };

  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
    music: json['music'] != false,
    sfx: json['sfx'] != false,
    musicVolume: asDouble(json['musicVolume'], 0.45).clamp(0.0, 1.0),
  );
}

/// The whole persisted game: one immutable snapshot. Every change produces
/// a new snapshot through [copyWith], which the store then writes.
class GameSave {
  const GameSave({
    this.profile,
    this.settings = const Settings(),
    this.foodLog = const [],
    this.customFoods = const [],
    this.plan,
    this.activeSession,
    this.workouts = const [],
    this.records = const {},
    this.rewardedWorkoutIds = const {},
    this.pet,
    this.petFood = const {},
    this.inventory = const [],
    this.equipped = const {},
    this.map = const MapProgress(),
    this.battles = const [],
    this.achievements = const {},
    this.claimedMilestones = const {},
  });

  /// Bump when the format changes and add a migration in [fromJson].
  static const currentVersion = 1;

  final Profile? profile;
  final Settings settings;
  final List<FoodLogEntry> foodLog;
  final List<Food> customFoods;
  final WorkoutPlan? plan;
  final WorkoutSession? activeSession;
  final List<WorkoutRecord> workouts;
  final Map<String, PersonalRecord> records;

  /// Ids of workouts whose reward was already granted.
  final Set<String> rewardedWorkoutIds;
  final Pet? pet;
  final Map<PetFood, int> petFood;
  final List<OwnedItem> inventory;

  /// Slot -> OwnedItem.instanceId.
  final Map<EquipSlot, String> equipped;
  final MapProgress map;
  final List<BattleRecord> battles;

  /// Achievement id -> unlock time.
  final Map<String, DateTime> achievements;

  /// Streak milestones (days) already rewarded.
  final Set<int> claimedMilestones;

  bool get onboarded => profile != null && pet != null;

  static const _unset = Object();

  GameSave copyWith({
    Object? profile = _unset,
    Settings? settings,
    List<FoodLogEntry>? foodLog,
    List<Food>? customFoods,
    Object? plan = _unset,
    Object? activeSession = _unset,
    List<WorkoutRecord>? workouts,
    Map<String, PersonalRecord>? records,
    Set<String>? rewardedWorkoutIds,
    Object? pet = _unset,
    Map<PetFood, int>? petFood,
    List<OwnedItem>? inventory,
    Map<EquipSlot, String>? equipped,
    MapProgress? map,
    List<BattleRecord>? battles,
    Map<String, DateTime>? achievements,
    Set<int>? claimedMilestones,
  }) => GameSave(
    profile: identical(profile, _unset) ? this.profile : profile as Profile?,
    settings: settings ?? this.settings,
    foodLog: foodLog ?? this.foodLog,
    customFoods: customFoods ?? this.customFoods,
    plan: identical(plan, _unset) ? this.plan : plan as WorkoutPlan?,
    activeSession: identical(activeSession, _unset)
        ? this.activeSession
        : activeSession as WorkoutSession?,
    workouts: workouts ?? this.workouts,
    records: records ?? this.records,
    rewardedWorkoutIds: rewardedWorkoutIds ?? this.rewardedWorkoutIds,
    pet: identical(pet, _unset) ? this.pet : pet as Pet?,
    petFood: petFood ?? this.petFood,
    inventory: inventory ?? this.inventory,
    equipped: equipped ?? this.equipped,
    map: map ?? this.map,
    battles: battles ?? this.battles,
    achievements: achievements ?? this.achievements,
    claimedMilestones: claimedMilestones ?? this.claimedMilestones,
  );

  Map<String, dynamic> toJson() => {
    'version': currentVersion,
    if (profile != null) 'profile': profile!.toJson(),
    'settings': settings.toJson(),
    'foodLog': foodLog.map((e) => e.toJson()).toList(),
    'customFoods': customFoods.map((f) => f.toJson()).toList(),
    if (plan != null) 'plan': plan!.toJson(),
    if (activeSession != null) 'activeSession': activeSession!.toJson(),
    'workouts': workouts.map((w) => w.toJson()).toList(),
    'records': {for (final e in records.entries) e.key: e.value.toJson()},
    'rewardedWorkoutIds': rewardedWorkoutIds.toList(),
    if (pet != null) 'pet': pet!.toJson(),
    'petFood': {for (final e in petFood.entries) e.key.name: e.value},
    'inventory': inventory.map((i) => i.toJson()).toList(),
    'equipped': {for (final e in equipped.entries) e.key.name: e.value},
    'map': map.toJson(),
    'battles': battles.map((b) => b.toJson()).toList(),
    'achievements': {
      for (final e in achievements.entries) e.key: e.value.toIso8601String(),
    },
    'claimedMilestones': claimedMilestones.toList(),
  };

  factory GameSave.fromJson(Map<String, dynamic> json) {
    final version = asInt(json['version'], 1);
    if (version > currentVersion) {
      throw FormatException('Save is from a newer app version ($version)');
    }

    final petFood = <PetFood, int>{};
    asMap(json['petFood']).forEach((key, value) {
      for (final f in PetFood.values) {
        if (f.name == key) petFood[f] = asInt(value).clamp(0, 1 << 30);
      }
    });
    final equipped = <EquipSlot, String>{};
    asMap(json['equipped']).forEach((key, value) {
      for (final slot in EquipSlot.values) {
        if (slot.name == key && value is String) equipped[slot] = value;
      }
    });
    final records = <String, PersonalRecord>{};
    asMap(json['records']).forEach((key, value) {
      records[key] = PersonalRecord.fromJson(asMap(value));
    });
    final achievements = <String, DateTime>{};
    asMap(json['achievements']).forEach((key, value) {
      final at = DateTime.tryParse(asString(value));
      if (at != null) achievements[key] = at;
    });

    return GameSave(
      profile: json['profile'] == null
          ? null
          : Profile.fromJson(asMap(json['profile'])),
      settings: Settings.fromJson(asMap(json['settings'])),
      foodLog: asMapList(json['foodLog']).map(FoodLogEntry.fromJson).toList(),
      customFoods: asMapList(json['customFoods']).map(Food.fromJson).toList(),
      plan: json['plan'] == null
          ? null
          : WorkoutPlan.fromJson(asMap(json['plan'])),
      activeSession: json['activeSession'] == null
          ? null
          : WorkoutSession.fromJson(asMap(json['activeSession'])),
      workouts: asMapList(json['workouts'])
          .map(WorkoutRecord.fromJson)
          .toList(),
      records: records,
      rewardedWorkoutIds: {
        for (final id in (json['rewardedWorkoutIds'] as List? ?? const []))
          asString(id),
      },
      pet: json['pet'] == null ? null : Pet.fromJson(asMap(json['pet'])),
      petFood: petFood,
      inventory: asMapList(json['inventory']).map(OwnedItem.fromJson).toList(),
      equipped: equipped,
      map: MapProgress.fromJson(asMap(json['map'])),
      battles: asMapList(json['battles']).map(BattleRecord.fromJson).toList(),
      achievements: achievements,
      claimedMilestones: {
        for (final d in (json['claimedMilestones'] as List? ?? const []))
          asInt(d),
      },
    );
  }
}
