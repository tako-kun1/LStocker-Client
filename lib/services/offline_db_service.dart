import 'dart:io';

import 'package:flutter/foundation.dart';
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
      debugPrint('[OfflineDb] active database path is not overridden on this platform');
      return null;
    }

    final dir = await _getPrimaryDatabaseDirectory();
    final path = join(dir.path, dbFileName);
    debugPrint('[OfflineDb] active database path: $path');
    return path;
  }

  Future<bool> shouldPromptForLegacyImport() async {
    if (!Platform.isAndroid) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final handled = prefs.getBool(_legacyImportHandledKey) ?? false;
    debugPrint('[OfflineDb] legacy import handled flag: $handled');
    if (handled) {
      return false;
    }

    final activePath = await getActiveDatabasePath();
    if (activePath != null) {
      final activeDb = File(activePath);
      if (await activeDb.exists()) {
        debugPrint('[OfflineDb] active database already exists: $activePath');
        return false;
      }
    }

    final legacyPath = await findLegacyDatabasePath();
    if (legacyPath == null) {
      // 旧DBが存在しない環境では、毎回の探索コストを避ける。
      debugPrint('[OfflineDb] no legacy database found; mark prompt handled');
      await markLegacyImportHandled();
      return false;
    }

    debugPrint('[OfflineDb] legacy database available for import: $legacyPath');
    return true;
  }

  Future<void> markLegacyImportHandled() async {
    if (!Platform.isAndroid) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_legacyImportHandledKey, true);
    debugPrint('[OfflineDb] marked legacy import as handled');
  }

  Future<String?> findLegacyDatabasePath() async {
    if (!Platform.isAndroid) {
      return null;
    }

    final candidates = <String>{
      '/storage/emulated/0/Documents/LStocker/$dbFileName',
    };

    final externalDir = await getExternalStorageDirectory();
    if (externalDir != null) {
      candidates.add(
        join(externalDir.path, 'Documents', 'LStocker', dbFileName),
      );
    }

    candidates.add(join(await getDatabasesPath(), 'bardber.db'));

    final ordered = candidates.toList(growable: false);
    debugPrint('[OfflineDb] checking legacy database candidates: ${ordered.join(', ')}');
    final existsResults = await Future.wait(
      ordered.map((path) => File(path).exists()),
    );

    for (var i = 0; i < ordered.length; i++) {
      if (existsResults[i]) {
        debugPrint('[OfflineDb] legacy database found: ${ordered[i]}');
        return ordered[i];
      }
    }

    debugPrint('[OfflineDb] legacy database not found in any candidate path');
    return null;
  }

  Future<bool> importLegacyDatabaseToActive({bool archiveSource = false}) async {
    if (!Platform.isAndroid) {
      return false;
    }

    final activePath = await getActiveDatabasePath();
    final legacyPath = await findLegacyDatabasePath();
    if (activePath == null || legacyPath == null) {
      debugPrint('[OfflineDb] import skipped; activePath=$activePath legacyPath=$legacyPath');
      return false;
    }

    final activeDb = File(activePath);
    if (await activeDb.exists()) {
      debugPrint('[OfflineDb] import skipped; active database already exists at $activePath');
      return true;
    }

    final legacyDb = File(legacyPath);
    if (!await legacyDb.exists()) {
      debugPrint('[OfflineDb] import skipped; legacy database disappeared: $legacyPath');
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
    debugPrint('[OfflineDb] copied legacy database to active path: $activePath');

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
      debugPrint('[OfflineDb] archive skipped; source database missing: $dbPath');
      return;
    }

    final archiveName = 'offlinedb_${DateTime.now().millisecondsSinceEpoch}.old';
    final archivedDb = File(join(dirname(dbPath), archiveName));
    await currentDb.rename(archivedDb.path);
    debugPrint('[OfflineDb] archived database: ${archivedDb.path}');

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
