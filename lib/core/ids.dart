import 'dart:math';

final _random = Random.secure();

/// A short unique id: time-ordered prefix plus random suffix.
String newId([String prefix = '']) {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final rand = List.generate(
    6,
    (_) => _random.nextInt(36).toRadixString(36),
  ).join();
  return '$prefix$time$rand';
}
