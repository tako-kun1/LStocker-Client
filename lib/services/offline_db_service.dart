import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineDbService {
  static const String _handledKey = 'offline_db_first_launch_handled';
  static const String dbFileName = 'offlinedb.db';

  Future<String?> getActiveDatabasePath() async {
    if (!Platform.isAndroid) {
      return null;
    }

    final dir = await _getLStockerDirectory();
    return join(dir.path, dbFileName);
  }

  Future<bool> shouldPromptForExistingOfflineDb() async {
    if (!Platform.isAndroid) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final handled = prefs.getBool(_handledKey) ?? false;
    if (handled) {
      return false;
    }

    final dir = await _getLStockerDirectory();
    final dbFile = File(join(dir.path, dbFileName));
    return dbFile.exists();
  }

  Future<void> archiveExistingOfflineDb() async {
    if (!Platform.isAndroid) {
      return;
    }

    final dir = await _getLStockerDirectory();
    final currentDb = File(join(dir.path, dbFileName));
    if (!await currentDb.exists()) {
      return;
    }

    final archiveName = 'offlinedb_${DateTime.now().millisecondsSinceEpoch}.old';
    final archivedDb = File(join(dir.path, archiveName));
    await currentDb.rename(archivedDb.path);

    final wal = File('${currentDb.path}-wal');
    if (await wal.exists()) {
      await wal.delete();
    }

    final shm = File('${currentDb.path}-shm');
    if (await shm.exists()) {
      await shm.delete();
    }
  }

  Future<void> markFirstLaunchHandled() async {
    if (!Platform.isAndroid) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_handledKey, true);
  }

  Future<Directory> _getLStockerDirectory() async {
    final baseDir = await getExternalStorageDirectory();
    if (baseDir == null) {
      throw Exception('External storage directory is not available on this device.');
    }

    final lStockerDir = Directory(join(baseDir.path, 'Documents', 'LStocker'));
    if (!await lStockerDir.exists()) {
      await lStockerDir.create(recursive: true);
    }

    return lStockerDir;
  }
}
