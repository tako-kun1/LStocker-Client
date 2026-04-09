import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'api_service.dart';
import '../models/api_models.dart';
import '../models/product.dart';
import '../models/inventory.dart';

/// 同期サービス - オフラインキュー、手動/自動同期、競合解決
class SyncService {
  static final SyncService _instance = SyncService._internal();
  final _db = DatabaseHelper();
  final _api = ApiService();
  late SharedPreferences _prefs;

  factory SyncService() {
    return _instance;
  }

  SyncService._internal();

  /// 初期化
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ==================== Product Sync ====================

  /// ローカル商品変更をキューに追加
  Future<void> queueProductChange({
    required String janCode,
    required String name,
    String? description,
    String? imagePath,
    required int deptNumber,
    required int salesPeriod,
    required String operation, // 'create', 'update', 'delete'
  }) async {
    final payload = jsonEncode({
      'jan_code': janCode,
      'name': name,
      'description': description,
      'image_path': imagePath,
      'dept_number': deptNumber,
      'sales_period': salesPeriod,
    });

    await _db.addToSyncQueue(
      entityType: 'product',
      entityId: janCode,
      operation: operation,
      payload: payload,
    );
  }

  /// 商品を同期
  Future<ProductSyncResult> syncProducts() async {
    try {
      // 1. 未同期のキューアイテムを取得
      final queueItems = await _db.getPendingSyncQueueByType('product');

      if (queueItems.isEmpty) {
        // キューが空の場合は、サーバーの変更のみ取得
        final lastSyncTimestamp = _prefs.getString('last_sync_product_timestamp') ??
            DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

        final serverChanges = await _api.getProducts(
          since: lastSyncTimestamp,
        );

        return ProductSyncResult(
          appliedCount: 0,
          receivedFromServer: serverChanges.products.length,
          conflicts: [],
          success: true,
        );
      }

      // 2. リクエスト作成
      final products = queueItems.map((item) {
        final payload = jsonDecode(item['payload'] as String);
        return ProductUpdateDto(
          janCode: payload['jan_code'] ?? '',
          name: payload['name'] ?? '',
          description: payload['description'],
          imagePath: payload['image_path'],
          deptNumber: payload['dept_number'] ?? 0,
          salesPeriod: payload['sales_period'] ?? 0,
          operation: item['operation'] ?? 'update',
        );
      }).toList();

      final lastSyncTimestamp = _prefs.getString('last_sync_product_timestamp') ??
          DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

      final request = ProductSyncRequest(
        lastSyncTimestamp: lastSyncTimestamp,
        clientTimestamp: DateTime.now().toIso8601String(),
        products: products,
      );

      // 3. サーバーに送信
      final response = await _api.syncProducts(request);

      // 4. ローカル DB を更新（サーバー変更をマージ）
      for (var serverProduct in response.serverChanges) {
        final product = Product(
          janCode: serverProduct.janCode,
          name: serverProduct.name,
          description: serverProduct.description ?? '',
          imagePath: serverProduct.imagePath ?? '',
          deptNumber: serverProduct.deptNumber,
          salesPeriod: serverProduct.salesPeriod,
        );

        final existing = await _db.getProduct(serverProduct.janCode);
        if (existing != null) {
          await _db.updateProduct(product);
        } else {
          await _db.insertProduct(product);
        }
      }

      // 5. 同期済みのキューアイテムをマーク
      for (var item in queueItems) {
        await _db.markSyncQueueAsSynced(item['id']);
      }

      // 6. 最終同期タイムスタンプを保存
      await _prefs.setString(
        'last_sync_product_timestamp',
        response.serverTimestamp,
      );

      return ProductSyncResult(
        appliedCount: response.appliedCount,
        receivedFromServer: response.serverChanges.length,
        conflicts: response.conflicts,
        success: true,
      );
    } catch (e) {
      return ProductSyncResult(
        appliedCount: 0,
        receivedFromServer: 0,
        conflicts: [],
        success: false,
        error: e.toString(),
      );
    }
  }

  // ==================== Inventory Sync ====================

  /// ローカル在庫変更をキューに追加
  Future<void> queueInventoryChange({
    int? id,
    required String janCode,
    required int quantity,
    required String expirationDate,
    required String registrationDate,
    required bool isArchived,
    required String operation, // 'create', 'update', 'delete'
  }) async {
    final payload = jsonEncode({
      'id': id,
      'jan_code': janCode,
      'quantity': quantity,
      'expiration_date': expirationDate,
      'registration_date': registrationDate,
      'is_archived': isArchived,
    });

    await _db.addToSyncQueue(
      entityType: 'inventory',
      entityId: id?.toString() ?? 'temp_${DateTime.now().millisecondsSinceEpoch}',
      operation: operation,
      payload: payload,
    );
  }

  /// 在庫を同期
  Future<InventorySyncResult> syncInventories() async {
    try {
      // 1. 未同期のキューアイテムを取得
      final queueItems = await _db.getPendingSyncQueueByType('inventory');

      if (queueItems.isEmpty) {
        // キューが空の場合は、サーバーの変更のみ取得
        final lastSyncTimestamp = _prefs.getString('last_sync_inventory_timestamp') ??
            DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

        final serverChanges = await _api.getInventories(
          since: lastSyncTimestamp,
        );

        return InventorySyncResult(
          appliedCount: 0,
          receivedFromServer: serverChanges.inventories.length,
          conflicts: [],
          success: true,
        );
      }

      // 2. リクエスト作成
      final inventories = queueItems.map((item) {
        final payload = jsonDecode(item['payload'] as String);
        return InventoryUpdateDto(
          id: payload['id'],
          janCode: payload['jan_code'] ?? '',
          quantity: payload['quantity'] ?? 0,
          expirationDate: payload['expiration_date'] ?? '',
          registrationDate: payload['registration_date'] ?? '',
          isArchived: payload['is_archived'] ?? false,
          operation: item['operation'] ?? 'update',
        );
      }).toList();

      final lastSyncTimestamp = _prefs.getString('last_sync_inventory_timestamp') ??
          DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

      final request = InventorySyncRequest(
        lastSyncTimestamp: lastSyncTimestamp,
        clientTimestamp: DateTime.now().toIso8601String(),
        inventories: inventories,
      );

      // 3. サーバーに送信
      final response = await _api.syncInventories(request);

      // 4. ローカル DB を更新（サーバー変更をマージ）
      for (var serverInventory in response.serverChanges) {
        final inventory = Inventory(
          id: serverInventory.id,
          janCode: serverInventory.janCode,
          quantity: serverInventory.quantity,
          expirationDate: DateTime.parse(serverInventory.expirationDate),
          registrationDate: DateTime.parse(serverInventory.registrationDate),
          isArchived: serverInventory.isArchived,
        );

        // insertInventory は ConflictAlgorithm.replace なのでこれだけで OK
        await _db.insertInventory(inventory);
      }

      // 5. 同期済みのキューアイテムをマーク
      for (var item in queueItems) {
        await _db.markSyncQueueAsSynced(item['id']);
      }

      // 6. 最終同期タイムスタンプを保存
      await _prefs.setString(
        'last_sync_inventory_timestamp',
        response.serverTimestamp,
      );

      return InventorySyncResult(
        appliedCount: response.appliedCount,
        receivedFromServer: response.serverChanges.length,
        conflicts: response.conflicts,
        success: true,
      );
    } catch (e) {
      return InventorySyncResult(
        appliedCount: 0,
        receivedFromServer: 0,
        conflicts: [],
        success: false,
        error: e.toString(),
      );
    }
  }

  // ==================== Manual Full Sync ====================

  /// 手動で両方同期
  Future<FullSyncResult> manualFullSync() async {
    final productResult = await syncProducts();
    final inventoryResult = await syncInventories();

    return FullSyncResult(
      productsResult: productResult,
      inventoriesResult: inventoryResult,
      timestamp: DateTime.now(),
    );
  }

  // ==================== Queue Management ====================

  /// 未同期アイテム数を取得
  Future<int> getPendingSyncCount() async {
    final queue = await _db.getPendingSyncQueue();
    return queue.length;
  }

  /// キューをクリア
  Future<void> clearQueue() async {
    await _db.clearAllQueue();
  }

  /// 同期済みキューをクリア
  Future<void> clearSyncedQueue() async {
    await _db.clearSyncedQueue();
  }

  // ==================== Timestamps ====================

  /// 最後の同期タイムスタンプを取得
  String? getLastSyncTimestamp() {
    return _prefs.getString('last_sync_timestamp');
  }

  /// 最後の同期タイムスタンプを更新
  Future<void> updateLastSyncTimestamp() async {
    await _prefs.setString(
      'last_sync_timestamp',
      DateTime.now().toIso8601String(),
    );
  }
}

// ==================== Result Models ====================

class ProductSyncResult {
  final int appliedCount;
  final int receivedFromServer;
  final List<ProductConflict> conflicts;
  final bool success;
  final String? error;

  ProductSyncResult({
    required this.appliedCount,
    required this.receivedFromServer,
    required this.conflicts,
    required this.success,
    this.error,
  });

  bool get hasConflicts => conflicts.isNotEmpty;
}

class InventorySyncResult {
  final int appliedCount;
  final int receivedFromServer;
  final List<InventoryConflict> conflicts;
  final bool success;
  final String? error;

  InventorySyncResult({
    required this.appliedCount,
    required this.receivedFromServer,
    required this.conflicts,
    required this.success,
    this.error,
  });

  bool get hasConflicts => conflicts.isNotEmpty;
}

class FullSyncResult {
  final ProductSyncResult productsResult;
  final InventorySyncResult inventoriesResult;
  final DateTime timestamp;

  FullSyncResult({
    required this.productsResult,
    required this.inventoriesResult,
    required this.timestamp,
  });

  bool get success => productsResult.success && inventoriesResult.success;

  bool get hasConflicts => productsResult.hasConflicts || inventoriesResult.hasConflicts;

  int get totalApplied =>
      productsResult.appliedCount + inventoriesResult.appliedCount;

  int get totalReceived =>
      productsResult.receivedFromServer + inventoriesResult.receivedFromServer;
}
