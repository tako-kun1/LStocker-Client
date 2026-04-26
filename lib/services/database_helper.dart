import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/product.dart';
import '../models/inventory.dart';
import 'offline_db_service.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final sw = Stopwatch()..start();
    final offlineDbService = OfflineDbService();
    final offlinePath = await offlineDbService.getActiveDatabasePath();
    final legacyPath = join(await getDatabasesPath(), 'bardber.db');
    debugPrint(
      '[Database] init started; offlinePath=$offlinePath legacyPath=$legacyPath',
    );

    if (offlinePath != null) {
      await _migrateLegacyInternalDbIfNeeded(
        legacyPath: legacyPath,
        offlinePath: offlinePath,
      );
    }

    final path = offlinePath ?? legacyPath;
    final pathExists = await File(path).exists();
    debugPrint('[Database] opening path=$path exists=$pathExists');

    final db = await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await _ensurePerformanceIndexes(db);
        debugPrint('[Database] opened path=${db.path}');
      },
    );
    debugPrint('[Database] init completed in ${sw.elapsedMilliseconds}ms');
    return db;
  }

  Future<void> _migrateLegacyInternalDbIfNeeded({
    required String legacyPath,
    required String offlinePath,
  }) async {
    final legacyDb = File(legacyPath);
    final offlineDb = File(offlinePath);
    final legacyExists = await legacyDb.exists();
    final offlineExists = await offlineDb.exists();
    debugPrint(
      '[Database] migration check legacyExists=$legacyExists offlineExists=$offlineExists',
    );

    if (!legacyExists || offlineExists) {
      return;
    }

    await Directory(dirname(offlinePath)).create(recursive: true);
    await legacyDb.copy(offlinePath);
    await _copyIfExists(File('$legacyPath-wal'), File('$offlinePath-wal'));
    await _copyIfExists(File('$legacyPath-shm'), File('$offlinePath-shm'));
    debugPrint('[Database] migrated legacy internal database to $offlinePath');
  }

  Future<void> _copyIfExists(File source, File destination) async {
    if (await source.exists()) {
      await source.copy(destination.path);
    }
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        janCode TEXT PRIMARY KEY,
        name TEXT,
        imagePath TEXT,
        deptNumber INTEGER,
        salesPeriod INTEGER,
        description TEXT,
        updatedAtLocal TEXT,
        syncStatus TEXT DEFAULT 'synced',
        isDeleted INTEGER DEFAULT 0,
        serverModifiedAt TEXT,
        modifiedBy INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE inventories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        janCode TEXT,
        expirationDate TEXT,
        quantity INTEGER,
        registrationDate TEXT,
        isArchived INTEGER DEFAULT 0,
        updatedAtLocal TEXT,
        syncStatus TEXT DEFAULT 'synced',
        serverModifiedAt TEXT,
        modifiedBy INTEGER,
        FOREIGN KEY (janCode) REFERENCES products (janCode)
      )
    ''');

    // Sync queue for offline changes
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entityType TEXT NOT NULL,
        entityId TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAtLocal TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        retryCount INTEGER NOT NULL DEFAULT 0,
        lastError TEXT,
        conflictPayload TEXT,
        conflictResolution TEXT,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await _ensurePerformanceIndexes(db);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add columns for server sync tracking
      try {
        await db.execute(
          'ALTER TABLE products ADD COLUMN serverModifiedAt TEXT',
        );
      } catch (e) {
        // Column might already exist
      }

      try {
        await db.execute('ALTER TABLE products ADD COLUMN modifiedBy INTEGER');
      } catch (e) {
        // Column might already exist
      }

      try {
        await db.execute(
          'ALTER TABLE inventories ADD COLUMN serverModifiedAt TEXT',
        );
      } catch (e) {
        // Column might already exist
      }

      try {
        await db.execute(
          'ALTER TABLE inventories ADD COLUMN modifiedBy INTEGER',
        );
      } catch (e) {
        // Column might already exist
      }

      // Create sync_queue table
      try {
        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entityType TEXT NOT NULL,
            entityId TEXT NOT NULL,
            operation TEXT NOT NULL,
            payload TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            updatedAtLocal TEXT NOT NULL DEFAULT '',
            status TEXT NOT NULL DEFAULT 'pending',
            retryCount INTEGER NOT NULL DEFAULT 0,
            lastError TEXT,
            conflictPayload TEXT,
            conflictResolution TEXT,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_sync_queue_synced ON sync_queue(synced)',
        );
        await db.execute(
          'CREATE INDEX idx_sync_queue_status ON sync_queue(status)',
        );
        await db.execute(
          'CREATE INDEX idx_sync_queue_createdAt ON sync_queue(createdAt)',
        );
      } catch (e) {
        // Table might already exist
      }
    }

    if (oldVersion < 3) {
      await _addColumnIfMissing(db, 'products', 'updatedAtLocal', 'TEXT');
      await _addColumnIfMissing(
        db,
        'products',
        'syncStatus',
        "TEXT DEFAULT 'synced'",
      );
      await _addColumnIfMissing(
        db,
        'products',
        'isDeleted',
        'INTEGER DEFAULT 0',
      );

      await _addColumnIfMissing(db, 'inventories', 'updatedAtLocal', 'TEXT');
      await _addColumnIfMissing(
        db,
        'inventories',
        'syncStatus',
        "TEXT DEFAULT 'synced'",
      );

      await _addColumnIfMissing(db, 'sync_queue', 'updatedAtLocal', 'TEXT');
      await _addColumnIfMissing(
        db,
        'sync_queue',
        'status',
        "TEXT NOT NULL DEFAULT 'pending'",
      );
      await _addColumnIfMissing(
        db,
        'sync_queue',
        'retryCount',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(db, 'sync_queue', 'lastError', 'TEXT');
      await _addColumnIfMissing(db, 'sync_queue', 'conflictPayload', 'TEXT');
      await _addColumnIfMissing(db, 'sync_queue', 'conflictResolution', 'TEXT');

      try {
        await db.execute(
          'CREATE INDEX idx_sync_queue_status ON sync_queue(status)',
        );
      } catch (_) {
        // Index might already exist.
      }
    }

    await _ensurePerformanceIndexes(db);
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    } catch (_) {
      // Column might already exist.
    }
  }

  Future<void> _ensurePerformanceIndexes(Database db) async {
    const statements = [
      'CREATE INDEX IF NOT EXISTS idx_products_isDeleted ON products(isDeleted)',
      'CREATE INDEX IF NOT EXISTS idx_inventories_isArchived_expirationDate ON inventories(isArchived, expirationDate)',
      'CREATE INDEX IF NOT EXISTS idx_inventories_janCode ON inventories(janCode)',
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_synced ON sync_queue(synced)',
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue(status)',
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_createdAt ON sync_queue(createdAt)',
    ];

    for (final statement in statements) {
      await db.execute(statement);
    }
  }

  // Product operations
  Future<int> insertProduct(
    Product product, {
    String syncStatus = 'synced',
    bool isDeleted = false,
    String? updatedAtLocal,
  }) async {
    Database db = await database;
    final map = product.toMap();
    map['updatedAtLocal'] = updatedAtLocal ?? DateTime.now().toIso8601String();
    map['syncStatus'] = syncStatus;
    map['isDeleted'] = isDeleted ? 1 : 0;
    return await db.insert(
      'products',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Product>> getProducts() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'isDeleted = 0',
    );
    return List.generate(maps.length, (i) {
      return Product.fromMap(maps[i]);
    });
  }

  Future<Set<String>> getAllProductJanCodes() async {
    final db = await database;
    final maps = await db.query('products', columns: ['janCode']);
    return maps
        .map((row) => (row['janCode'] as String?) ?? '')
        .where((janCode) => janCode.isNotEmpty)
        .toSet();
  }

  Future<int> insertProductsInTransaction(
    List<Product> products, {
    String syncStatus = 'synced',
  }) async {
    if (products.isEmpty) {
      return 0;
    }

    final db = await database;
    var insertedCount = 0;

    await db.transaction((txn) async {
      for (final product in products) {
        final map = product.toMap();
        map['updatedAtLocal'] = DateTime.now().toIso8601String();
        map['syncStatus'] = syncStatus;
        map['isDeleted'] = 0;

        final result = await txn.insert(
          'products',
          map,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (result > 0) {
          insertedCount++;
        }
      }
    });

    return insertedCount;
  }

  Future<Product?> getProduct(String janCode) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'janCode = ?',
      whereArgs: [janCode],
    );
    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateProduct(
    Product product, {
    String syncStatus = 'pending',
    String? updatedAtLocal,
  }) async {
    Database db = await database;
    final map = product.toMap();
    map['updatedAtLocal'] = updatedAtLocal ?? DateTime.now().toIso8601String();
    map['syncStatus'] = syncStatus;
    map['isDeleted'] = 0;
    return await db.update(
      'products',
      map,
      where: 'janCode = ?',
      whereArgs: [product.janCode],
    );
  }

  Future<int> markProductDeleted(
    String janCode, {
    String syncStatus = 'pending',
  }) async {
    Database db = await database;
    return await db.update(
      'products',
      {
        'isDeleted': 1,
        'syncStatus': syncStatus,
        'updatedAtLocal': DateTime.now().toIso8601String(),
      },
      where: 'janCode = ?',
      whereArgs: [janCode],
    );
  }

  Future<int> setProductSyncStatus(String janCode, String status) async {
    Database db = await database;
    return await db.update(
      'products',
      {'syncStatus': status},
      where: 'janCode = ?',
      whereArgs: [janCode],
    );
  }

  // Inventory operations
  Future<int> insertInventory(
    Inventory inventory, {
    String syncStatus = 'synced',
    String? updatedAtLocal,
  }) async {
    Database db = await database;
    final map = inventory.toMap();
    map['updatedAtLocal'] = updatedAtLocal ?? DateTime.now().toIso8601String();
    map['syncStatus'] = syncStatus;
    return await db.insert(
      'inventories',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Inventory>> getInventories({bool includeArchived = false}) async {
    Database db = await database;
    String whereClause = includeArchived ? '' : 'isArchived = 0';
    final List<Map<String, dynamic>> maps = await db.query(
      'inventories',
      where: whereClause.isNotEmpty ? whereClause : null,
      orderBy: 'expirationDate ASC',
    );
    return List.generate(maps.length, (i) {
      return Inventory.fromMap(maps[i]);
    });
  }

  Future<int> archiveInventory(int id, {String syncStatus = 'pending'}) async {
    Database db = await database;
    return await db.update(
      'inventories',
      {
        'isArchived': 1,
        'syncStatus': syncStatus,
        'updatedAtLocal': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateInventory(
    Inventory inventory, {
    String syncStatus = 'pending',
    String? updatedAtLocal,
  }) async {
    Database db = await database;
    final map = inventory.toMap();
    map['updatedAtLocal'] = updatedAtLocal ?? DateTime.now().toIso8601String();
    map['syncStatus'] = syncStatus;
    return await db.update(
      'inventories',
      map,
      where: 'id = ?',
      whereArgs: [inventory.id],
    );
  }

  Future<int> setInventorySyncStatus(int id, String status) async {
    Database db = await database;
    return await db.update(
      'inventories',
      {'syncStatus': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> remapInventoryId({
    required int localId,
    required int serverId,
  }) async {
    if (localId == serverId) return;

    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'inventories',
        where: 'id = ?',
        whereArgs: [localId],
        limit: 1,
      );
      if (rows.isEmpty) return;

      final map = Map<String, dynamic>.from(rows.first);
      map['id'] = serverId;

      await txn.delete('inventories', where: 'id = ?', whereArgs: [localId]);
      await txn.insert(
        'inventories',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.update(
        'sync_queue',
        {'entityId': serverId.toString()},
        where: 'entityType = ? AND entityId = ?',
        whereArgs: ['inventory', localId.toString()],
      );
    });
  }

  Future<int> deleteInventory(int id) async {
    Database db = await database;
    return await db.delete('inventories', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> replaceAllInventories(List<Inventory> inventories) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('inventories');
      for (final inventory in inventories) {
        final map = inventory.toMap();
        map['updatedAtLocal'] = DateTime.now().toIso8601String();
        map['syncStatus'] = 'synced';
        await txn.insert(
          'inventories',
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> clearAllAppDataForCsvRefresh() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('products');
      await txn.delete(
        'sync_queue',
        where: 'entityType = ?',
        whereArgs: ['product'],
      );
    });
  }

  Future<List<Map<String, dynamic>>> getInventoriesWithProduct({
    bool includeArchived = false,
  }) async {
    Database db = await database;
    String whereClause = includeArchived ? '' : 'WHERE i.isArchived = 0';
    return await db.rawQuery('''
      SELECT i.*,
             COALESCE(p.name, i.janCode, '未登録商品') AS name,
             COALESCE(p.imagePath, '') AS imagePath,
             COALESCE(p.salesPeriod, 0) AS salesPeriod
      FROM inventories i
      LEFT JOIN products p ON i.janCode = p.janCode
      $whereClause
      ORDER BY i.expirationDate ASC
    ''');
  }

  // ==================== Sync Queue Operations ====================

  /// Sync queue にローカル変更を追加
  Future<int> addToSyncQueue({
    required String entityType, // 'product' or 'inventory'
    required String entityId, // janCode for product, id for inventory
    required String operation, // 'create', 'update', 'delete'
    required String payload, // JSON string
    String status = 'pending',
    String? conflictResolution,
  }) async {
    Database db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.insert('sync_queue', {
      'entityType': entityType,
      'entityId': entityId,
      'operation': operation,
      'payload': payload,
      'createdAt': now,
      'updatedAtLocal': now,
      'status': status,
      'retryCount': 0,
      'conflictResolution': conflictResolution,
      'synced': 0,
    });
  }

  /// 未同期のキューアイテムを取得
  Future<List<Map<String, dynamic>>> getPendingSyncQueue() async {
    Database db = await database;
    return await db.query(
      'sync_queue',
      where: "status = 'pending'",
      orderBy: 'createdAt ASC',
    );
  }

  /// 特定のエンティティタイプの未同期キューを取得
  Future<List<Map<String, dynamic>>> getPendingSyncQueueByType(
    String entityType,
  ) async {
    Database db = await database;
    return await db.query(
      'sync_queue',
      where: "status = 'pending' AND entityType = ?",
      whereArgs: [entityType],
      orderBy: 'createdAt ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getSyncQueueByStatuses({
    required List<String> statuses,
    String? entityType,
  }) async {
    Database db = await database;
    final placeholders = List.filled(statuses.length, '?').join(',');
    final args = <Object?>[...statuses];
    var where = 'status IN ($placeholders)';
    if (entityType != null) {
      where = '$where AND entityType = ?';
      args.add(entityType);
    }

    return await db.query(
      'sync_queue',
      where: where,
      whereArgs: args,
      orderBy: 'createdAt ASC',
    );
  }

  /// キューアイテムを同期済みにマーク
  Future<int> markSyncQueueAsSynced(int id) async {
    Database db = await database;
    return await db.update(
      'sync_queue',
      {'synced': 1, 'status': 'synced'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateSyncQueueStatus(
    int id,
    String status, {
    String? lastError,
    String? conflictPayload,
    String? conflictResolution,
    bool incrementRetry = false,
  }) async {
    Database db = await database;
    final current = await db.query(
      'sync_queue',
      columns: ['retryCount'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    final retryCount = current.isNotEmpty
        ? (current.first['retryCount'] as int? ?? 0)
        : 0;

    return await db.update(
      'sync_queue',
      {
        'status': status,
        'lastError': lastError,
        'conflictPayload': conflictPayload,
        'conflictResolution': conflictResolution,
        'retryCount': incrementRetry ? retryCount + 1 : retryCount,
        'updatedAtLocal': DateTime.now().toIso8601String(),
        'synced': status == 'synced' ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getConflictedQueueItems() async {
    Database db = await database;
    return await db.query(
      'sync_queue',
      where: "status = 'conflict'",
      orderBy: 'createdAt ASC',
    );
  }

  /// キューアイテムを削除
  Future<int> deleteSyncQueueItem(int id) async {
    Database db = await database;
    return await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  /// 同期済みのキューアイテムをクリア
  Future<int> clearSyncedQueue() async {
    Database db = await database;
    return await db.delete(
      'sync_queue',
      where: "status = 'synced' OR synced = 1",
    );
  }

  /// キューをリセット（テスト用）
  Future<int> clearAllQueue() async {
    Database db = await database;
    return await db.delete('sync_queue');
  }

  Future<int> clearSyncQueueByEntityType(String entityType) async {
    Database db = await database;
    return await db.delete(
      'sync_queue',
      where: 'entityType = ?',
      whereArgs: [entityType],
    );
  }
}
