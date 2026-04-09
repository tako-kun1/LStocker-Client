import 'dart:async';
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
    final offlineDbService = OfflineDbService();
    final offlinePath = await offlineDbService.getActiveDatabasePath();
    final path = offlinePath ?? join(await getDatabasesPath(), 'bardber.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create indexes for better performance
    await db.execute(
        'CREATE INDEX idx_sync_queue_synced ON sync_queue(synced)');
    await db.execute(
        'CREATE INDEX idx_sync_queue_createdAt ON sync_queue(createdAt)');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add columns for server sync tracking
      try {
        await db.execute(
            'ALTER TABLE products ADD COLUMN serverModifiedAt TEXT');
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
            'ALTER TABLE inventories ADD COLUMN serverModifiedAt TEXT');
      } catch (e) {
        // Column might already exist
      }

      try {
        await db.execute(
            'ALTER TABLE inventories ADD COLUMN modifiedBy INTEGER');
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
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute(
            'CREATE INDEX idx_sync_queue_synced ON sync_queue(synced)');
        await db.execute(
            'CREATE INDEX idx_sync_queue_createdAt ON sync_queue(createdAt)');
      } catch (e) {
        // Table might already exist
      }
    }
  }

  // Product operations
  Future<int> insertProduct(Product product) async {
    Database db = await database;
    return await db.insert('products', product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Product>> getProducts() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('products');
    return List.generate(maps.length, (i) {
      return Product.fromMap(maps[i]);
    });
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

  Future<int> updateProduct(Product product) async {
    Database db = await database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'janCode = ?',
      whereArgs: [product.janCode],
    );
  }

  // Inventory operations
  Future<int> insertInventory(Inventory inventory) async {
    Database db = await database;
    return await db.insert('inventories', inventory.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
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

  Future<int> archiveInventory(int id) async {
    Database db = await database;
    return await db.update(
      'inventories',
      {'isArchived': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateInventory(Inventory inventory) async {
    Database db = await database;
    return await db.update(
      'inventories',
      inventory.toMap(),
      where: 'id = ?',
      whereArgs: [inventory.id],
    );
  }

  Future<int> deleteInventory(int id) async {
    Database db = await database;
    return await db.delete(
      'inventories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getInventoriesWithProduct({bool includeArchived = false}) async {
    Database db = await database;
    String whereClause = includeArchived ? '' : 'WHERE i.isArchived = 0';
    return await db.rawQuery('''
      SELECT i.*, p.name, p.imagePath, p.salesPeriod
      FROM inventories i
      JOIN products p ON i.janCode = p.janCode
      $whereClause
      ORDER BY i.expirationDate ASC
    ''');
  }

  // ==================== Sync Queue Operations ====================

  /// Sync queue にローカル変更を追加
  Future<int> addToSyncQueue({
    required String entityType, // 'product' or 'inventory'
    required String entityId,    // janCode for product, id for inventory
    required String operation,   // 'create', 'update', 'delete'
    required String payload,     // JSON string
  }) async {
    Database db = await database;
    return await db.insert('sync_queue', {
      'entityType': entityType,
      'entityId': entityId,
      'operation': operation,
      'payload': payload,
      'createdAt': DateTime.now().toIso8601String(),
      'synced': 0,
    });
  }

  /// 未同期のキューアイテムを取得
  Future<List<Map<String, dynamic>>> getPendingSyncQueue() async {
    Database db = await database;
    return await db.query(
      'sync_queue',
      where: 'synced = 0',
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
      where: 'synced = 0 AND entityType = ?',
      whereArgs: [entityType],
      orderBy: 'createdAt ASC',
    );
  }

  /// キューアイテムを同期済みにマーク
  Future<int> markSyncQueueAsSynced(int id) async {
    Database db = await database;
    return await db.update(
      'sync_queue',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// キューアイテムを削除
  Future<int> deleteSyncQueueItem(int id) async {
    Database db = await database;
    return await db.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 同期済みのキューアイテムをクリア
  Future<int> clearSyncedQueue() async {
    Database db = await database;
    return await db.delete(
      'sync_queue',
      where: 'synced = 1',
    );
  }

  /// キューをリセット（テスト用）
  Future<int> clearAllQueue() async {
    Database db = await database;
    return await db.delete('sync_queue');
  }
}
