/// Calendar-day helpers. Days are stored as `yyyy-MM-dd` keys in local time
/// so a food entry logged at 23:59 belongs to the day the user saw.
class Day {
  const Day._();

  static String key(DateTime time) {
    final local = time.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  /// Midnight (local) of the day described by [key].
  static DateTime parse(String key) {
    final parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  static DateTime dateOnly(DateTime time) {
    final local = time.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Whole calendar days from [a] to [b] (positive when b is later).
  /// Uses UTC dates so daylight-saving changes never produce 0.96 days.
  static int between(DateTime a, DateTime b) {
    final ua = DateTime.utc(a.year, a.month, a.day);
    final ub = DateTime.utc(b.year, b.month, b.day);
    return ub.difference(ua).inDays;
  }

  static int betweenKeys(String a, String b) => between(parse(a), parse(b));
}
