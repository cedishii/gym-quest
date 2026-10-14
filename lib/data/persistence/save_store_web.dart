import 'package:shared_preferences/shared_preferences.dart';

import 'save_store.dart';

SaveStore createStore() => PrefsSaveStore();

/// Browser store (used for local preview in Chrome). Keeps a backup of the
/// previous save the same way the file store does.
class PrefsSaveStore implements SaveStore {
  static const _key = 'gym_quest_save';
  static const _backupKey = 'gym_quest_save_bak';

  @override
  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  @override
  Future<String?> readBackup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_backupKey);
  }

  @override
  Future<void> write(String data) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(_key);
    if (previous != null) await prefs.setString(_backupKey, previous);
    await prefs.setString(_key, data);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_backupKey);
  }
}
