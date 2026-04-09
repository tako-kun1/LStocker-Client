import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class OfflineDbService {
  static const String _legacyImportHandledKey =
      'offline_db_legacy_import_handled';
  static const String dbFileName = 'offlinedb.db';

  Future<String?> getActiveDatabasePath() async {
    if (!Platform.isAndroid) {
      return null;
    }

    final dir = await _getPrimaryDatabaseDirectory();
    return join(dir.path, dbFileName);
  }

  Future<bool> shouldPromptForLegacyImport() async {
    if (!Platform.isAndroid) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final handled = prefs.getBool(_legacyImportHandledKey) ?? false;
    if (handled) {
      return false;
    }

    final activePath = await getActiveDatabasePath();
    if (activePath == null) {
      return false;
    }

    final activeDb = File(activePath);
    if (await activeDb.exists()) {
      return false;
    }

    final legacyPath = await findLegacyDatabasePath();
    return legacyPath != null;
  }

  Future<void> markLegacyImportHandled() async {
    if (!Platform.isAndroid) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_legacyImportHandledKey, true);
  }

  Future<String?> findLegacyDatabasePath() async {
    if (!Platform.isAndroid) {
      return null;
    }

    final candidates = <String>[];

    candidates.add('/storage/emulated/0/Documents/LStocker/$dbFileName');

    final externalDir = await getExternalStorageDirectory();
    if (externalDir != null) {
      candidates.add(
        join(externalDir.path, 'Documents', 'LStocker', dbFileName),
      );
    }

    candidates.add(join(await getDatabasesPath(), 'bardber.db'));

    for (final path in candidates) {
      final file = File(path);
      if (await file.exists()) {
        return path;
      }
    }

    return null;
  }

  Future<bool> importLegacyDatabaseToActive({bool archiveSource = false}) async {
    if (!Platform.isAndroid) {
      return false;
    }

    final activePath = await getActiveDatabasePath();
    final legacyPath = await findLegacyDatabasePath();
    if (activePath == null || legacyPath == null) {
      return false;
    }

    final activeDb = File(activePath);
    if (await activeDb.exists()) {
      return true;
    }

    final legacyDb = File(legacyPath);
    if (!await legacyDb.exists()) {
      return false;
    }

    await Directory(dirname(activePath)).create(recursive: true);
    await legacyDb.copy(activePath);
    await _copyIfExists(
      File('$legacyPath-wal'),
      File('$activePath-wal'),
    );
    await _copyIfExists(
      File('$legacyPath-shm'),
      File('$activePath-shm'),
    );

    if (archiveSource) {
      await _archiveDatabaseFile(legacyPath);
    }

    return true;
  }

  Future<void> archiveLegacySourceDatabase() async {
    if (!Platform.isAndroid) {
      return;
    }

    final legacyPath = await findLegacyDatabasePath();
    if (legacyPath == null) {
      return;
    }

    await _archiveDatabaseFile(legacyPath);
  }

  Future<Directory> _getPrimaryDatabaseDirectory() async {
    if (!Platform.isAndroid) {
      throw Exception('This directory strategy is only available on Android.');
    }

    final supportDir = await getApplicationSupportDirectory();
    final dbDir = Directory(join(supportDir.path, 'db'));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    return dbDir;
  }

  Future<void> _archiveDatabaseFile(String dbPath) async {
    final currentDb = File(dbPath);
    if (!await currentDb.exists()) {
      return;
    }

    final archiveName = 'offlinedb_${DateTime.now().millisecondsSinceEpoch}.old';
    final archivedDb = File(join(dirname(dbPath), archiveName));
    await currentDb.rename(archivedDb.path);

    final wal = File('$dbPath-wal');
    if (await wal.exists()) {
      await wal.delete();
    }

    final shm = File('$dbPath-shm');
    if (await shm.exists()) {
      await shm.delete();
    }
  }

  Future<void> _copyIfExists(File source, File destination) async {
    if (await source.exists()) {
      await source.copy(destination.path);
    }
  }
}
