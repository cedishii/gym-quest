/// App-wide constants that are not game balance (see balance.dart for that).
class AppConfig {
  const AppConfig._();

  static const appName = 'Gym Quest';
  static const appVersion = '1.0.0';

  /// Open Food Facts asks every client to identify itself as
  /// `AppName/Version (ContactEmail)`.
  static const offUserAgent =
      'GymQuest/$appVersion (personal app; github.com/cedishii/gym-quest)';

  static const offBaseUrl = 'https://world.openfoodfacts.org';

  /// Open Food Facts limits: 10 searches/min and 15 product reads/min per IP.
  /// The client keeps at least this much time between calls of each kind.
  static const offSearchInterval = Duration(seconds: 7);
  static const offProductInterval = Duration(seconds: 5);
  static const networkTimeout = Duration(seconds: 15);
}
