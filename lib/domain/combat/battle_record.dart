import '../../core/json.dart';

/// One finished battle, kept in history.
class BattleRecord {
  const BattleRecord({
    required this.id,
    required this.at,
    required this.opponent,
    required this.won,
    required this.rounds,
    required this.petLevel,
    this.stageIndex,
    this.endlessFloor,
  });

  final String id;
  final DateTime at;
  final String opponent;
  final bool won;
  final int rounds;
  final int petLevel;

  /// Story stage, or null for an endless battle.
  final int? stageIndex;
  final int? endlessFloor;

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toIso8601String(),
    'opponent': opponent,
    'won': won,
    'rounds': rounds,
    'petLevel': petLevel,
    if (stageIndex != null) 'stage': stageIndex,
    if (endlessFloor != null) 'floor': endlessFloor,
  };

  factory BattleRecord.fromJson(Map<String, dynamic> json) => BattleRecord(
    id: asString(json['id']),
    at: DateTime.tryParse(asString(json['at'])) ?? DateTime.now(),
    opponent: asString(json['opponent']),
    won: json['won'] == true,
    rounds: asInt(json['rounds']),
    petLevel: asInt(json['petLevel'], 1),
    stageIndex: json['stage'] == null ? null : asInt(json['stage']),
    endlessFloor: json['floor'] == null ? null : asInt(json['floor']),
  );
}
