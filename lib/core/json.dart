/// Small helpers for reading loosely typed JSON safely.
double asDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int asInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

String asString(Object? value, [String fallback = '']) =>
    value is String ? value : (value?.toString() ?? fallback);

List<Map<String, dynamic>> asMapList(Object? value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];

Map<String, dynamic> asMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

/// Enum lookup by name with a fallback for unknown or missing values,
/// so older or hand-edited saves never crash the app.
T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
