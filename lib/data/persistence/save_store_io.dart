import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'save_store.dart';

SaveStore createStore() => FileSaveStore.appDocuments();

/// JSON file store with atomic writes.
///
/// A write goes to `save.json.tmp` first and is then renamed over
/// `save.json`, so a crash mid-write never leaves a half-written save. The
/// previous good save is kept as `save.json.bak` and used if the main file
/// is missing or unreadable.
class FileSaveStore implements SaveStore {
  FileSaveStore(this._directory);

  FileSaveStore.appDocuments() : _directory = null;

  Directory? _directory;

  Future<Directory> _dir() async {
    if (_directory != null) return _directory!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}gym_quest');
    await dir.create(recursive: true);
    return _directory = dir;
  }

  Future<File> _file(String name) async =>
      File('${(await _dir()).path}${Platform.pathSeparator}$name');

  @override
  Future<String?> read() async => _readText(await _file('save.json'));

  @override
  Future<String?> readBackup() async => _readText(await _file('save.json.bak'));

  Future<String?> _readText(File file) async {
    try {
      if (!await file.exists()) return null;
      final text = await file.readAsString();
      return text.trim().isEmpty ? null : text;
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> write(String data) async {
    final main = await _file('save.json');
    final tmp = await _file('save.json.tmp');
    final backup = await _file('save.json.bak');
    await tmp.writeAsString(data, flush: true);
    if (await main.exists()) {
      await main.copy(backup.path);
    }
    await tmp.rename(main.path);
  }

  @override
  Future<void> clear() async {
    for (final name in ['save.json', 'save.json.tmp', 'save.json.bak']) {
      final file = await _file(name);
      if (await file.exists()) await file.delete();
    }
  }
}
