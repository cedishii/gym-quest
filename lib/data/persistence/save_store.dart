import 'save_store_stub.dart'
    if (dart.library.io) 'save_store_io.dart'
    if (dart.library.js_interop) 'save_store_web.dart';

/// Reads and writes the serialized game save.
///
/// Local-first: the save never leaves the device. On Android/iOS it is a
/// JSON file in the app's private documents folder (written atomically
/// with a backup copy); in the browser it is kept in local storage.
abstract class SaveStore {
  /// The saved JSON text, or null when nothing has been saved yet.
  Future<String?> read();

  /// The previous save, used when the current one cannot be parsed.
  Future<String?> readBackup();

  Future<void> write(String data);

  Future<void> clear();
}

/// The store for the current platform.
SaveStore createPlatformSaveStore() => createStore();

/// Keeps the save in memory. Used by tests.
class MemorySaveStore implements SaveStore {
  MemorySaveStore([this.data]);

  String? data;
  String? backup;
  int writes = 0;

  @override
  Future<String?> read() async => data;

  @override
  Future<String?> readBackup() async => backup;

  @override
  Future<void> write(String data) async {
    backup = this.data;
    this.data = data;
    writes++;
  }

  @override
  Future<void> clear() async {
    data = null;
    backup = null;
  }
}
