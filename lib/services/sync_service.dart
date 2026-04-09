import 'dart:convert';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/api_models.dart';
import '../models/inventory.dart';
import '../models/product.dart';
import 'api_client.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'database_helper.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();

  final _db = DatabaseHelper();
  final _api = ApiService();
  final _auth = AuthService();
  final _connectivity = Connectivity();
  late SharedPreferences _prefs;

  factory SyncService() {
    return _instance;
  }

  SyncService._internal();

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> queueProductChange({
    required String janCode,
    required String name,
    String? description,
    String? imagePath,
    required int deptNumber,
    required int salesPeriod,
    required String operation,
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

    if (operation == 'delete') {
      await _db.markProductDeleted(janCode, syncStatus: 'pending');
    } else {
      await _db.setProductSyncStatus(janCode, 'pending');
    }
  }

  Future<void> queueInventoryChange({
    int? id,
    required String janCode,
    required int quantity,
    required String expirationDate,
    required String registrationDate,
    required bool isArchived,
    required String operation,
  }) async {
    final payload = jsonEncode({
      'id': id,
      'jan_code': janCode,
      'quantity': quantity,
      'expiration_date': expirationDate,
      'registration_date': registrationDate,
      'is_archived': isArchived,
    });

    final entityId = id?.toString() ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';

    await _db.addToSyncQueue(
      entityType: 'inventory',
      entityId: entityId,
      operation: operation,
      payload: payload,
    );

    if (id != null) {
      await _db.setInventorySyncStatus(id, 'pending');
    }
  }

  Future<ProductSyncResult> syncProducts() async {
    return _syncProducts(push: true, includePull: true);
  }

  Future<InventorySyncResult> syncInventories() async {
    return _syncInventories(push: true, includePull: true);
  }

  Future<FullSyncResult> manualFullSync() async {
    if (!await _isOnline()) {
      return FullSyncResult(
        productsResult: ProductSyncResult(
          appliedCount: 0,
          receivedFromServer: 0,
          conflicts: const [],
          success: false,
          error: 'offline',
        ),
        inventoriesResult: InventorySyncResult(
          appliedCount: 0,
          receivedFromServer: 0,
          conflicts: const [],
          success: false,
          error: 'offline',
        ),
        timestamp: DateTime.now(),
      );
    }

    try {
      await _retryWithBackoff(() => _api.health());
    } catch (e) {
      return FullSyncResult(
        productsResult: ProductSyncResult(
          appliedCount: 0,
          receivedFromServer: 0,
          conflicts: const [],
          success: false,
          error: 'health_check_failed: $e',
        ),
        inventoriesResult: InventorySyncResult(
          appliedCount: 0,
          receivedFromServer: 0,
          conflicts: const [],
          success: false,
          error: 'health_check_failed: $e',
        ),
        timestamp: DateTime.now(),
      );
    }

    final canAuth = await _ensureAccessToken();
    if (!canAuth) {
      return FullSyncResult(
        productsResult: ProductSyncResult(
          appliedCount: 0,
          receivedFromServer: 0,
          conflicts: const [],
          success: false,
          error: 'auth_failed',
        ),
        inventoriesResult: InventorySyncResult(
          appliedCount: 0,
          receivedFromServer: 0,
          conflicts: const [],
          success: false,
          error: 'auth_failed',
        ),
        timestamp: DateTime.now(),
      );
    }

    await _safeActivate();

    final productPull = await _syncProducts(push: false, includePull: true);
    final inventoryPull = await _syncInventories(push: false, includePull: true);

    final productPush = await _syncProducts(push: true, includePull: false);
    final inventoryPush = await _syncInventories(push: true, includePull: false);

    await _db.clearSyncedQueue();

    return FullSyncResult(
      productsResult: ProductSyncResult(
        appliedCount: productPush.appliedCount,
        receivedFromServer: productPull.receivedFromServer + productPush.receivedFromServer,
        conflicts: [...productPull.conflicts, ...productPush.conflicts],
        success: productPull.success && productPush.success,
        error: productPush.error ?? productPull.error,
      ),
      inventoriesResult: InventorySyncResult(
        appliedCount: inventoryPush.appliedCount,
        receivedFromServer:
            inventoryPull.receivedFromServer + inventoryPush.receivedFromServer,
        conflicts: [...inventoryPull.conflicts, ...inventoryPush.conflicts],
        success: inventoryPull.success && inventoryPush.success,
        error: inventoryPush.error ?? inventoryPull.error,
      ),
      timestamp: DateTime.now(),
    );
  }

  Future<int> getPendingSyncCount() async {
    final queue = await _db.getSyncQueueByStatuses(
      statuses: const ['pending', 'failed', 'conflict'],
    );
    return queue.length;
  }

  Future<void> clearQueue() async {
    await _db.clearAllQueue();
  }

  Future<void> clearSyncedQueue() async {
    await _db.clearSyncedQueue();
  }

  String? getLastSyncTimestamp() {
    return _prefs.getString('last_sync_timestamp');
  }

  Future<void> updateLastSyncTimestamp() async {
    await _prefs.setString('last_sync_timestamp', DateTime.now().toIso8601String());
  }

  Future<List<SyncConflictItem>> getConflicts() async {
    final rows = await _db.getConflictedQueueItems();
    return rows
        .map(
          (row) => SyncConflictItem(
            queueId: row['id'] as int,
            entityType: row['entityType'] as String,
            entityId: row['entityId'] as String,
            operation: row['operation'] as String,
            lastError: row['lastError'] as String?,
            payload: row['payload'] as String,
            conflictPayload: row['conflictPayload'] as String?,
          ),
        )
        .toList();
  }

  Future<void> resolveConflictServerWins(int queueId) async {
    await _db.deleteSyncQueueItem(queueId);
  }

  Future<void> resolveConflictClientWins(int queueId) async {
    await _db.updateSyncQueueStatus(
      queueId,
      'pending',
      conflictResolution: 'client_wins',
      lastError: null,
      conflictPayload: null,
    );
  }

  Future<ProductSyncResult> _syncProducts({
    required bool push,
    required bool includePull,
    bool retriedAuth = false,
  }) async {
    final queueItems = push
        ? await _db.getSyncQueueByStatuses(
            statuses: const ['pending', 'failed'],
            entityType: 'product',
          )
        : <Map<String, dynamic>>[];

    final lastSyncTimestamp = _prefs.getString('last_sync_product_timestamp') ??
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

    final productsPayload = <Map<String, dynamic>>[];
    for (final item in queueItems) {
      final data = jsonDecode(item['payload'] as String) as Map<String, dynamic>;
      data['operation'] = item['operation'];
      final resolution = item['conflictResolution'] as String?;
      if (resolution != null && resolution.isNotEmpty) {
        data['resolution'] = resolution;
      }
      productsPayload.add(data);
      await _db.updateSyncQueueStatus(item['id'] as int, 'syncing');
    }

    final request = {
      'last_sync_timestamp': includePull ? lastSyncTimestamp : DateTime.now().toIso8601String(),
      'client_timestamp': DateTime.now().toIso8601String(),
      'products': push ? productsPayload : <Map<String, dynamic>>[],
    };

    try {
      final responseMap = await _retryWithBackoff(
        () => _api.syncProductsRaw(request),
      );
      final data = _extractResponseData(responseMap);

      final serverChangesRaw = (data['server_changes'] as List<dynamic>? ?? const []);
      for (final raw in serverChangesRaw) {
        final dto = ProductDto.fromJson(Map<String, dynamic>.from(raw as Map));
        final product = Product(
          janCode: dto.janCode,
          name: dto.name,
          description: dto.description ?? '',
          imagePath: dto.imagePath ?? '',
          deptNumber: dto.deptNumber,
          salesPeriod: dto.salesPeriod,
        );
        await _db.insertProduct(product, syncStatus: 'synced', isDeleted: false);
      }

      final conflicts = <ProductConflict>[];
      final conflictJanCodes = <String>{};
      final conflictsRaw = (data['conflicts'] as List<dynamic>? ?? const []);
      for (final raw in conflictsRaw) {
        final map = Map<String, dynamic>.from(raw as Map);
        final conflict = ProductConflict.fromJson(map);
        conflicts.add(conflict);
        conflictJanCodes.add(conflict.janCode);
      }

      if (push) {
        for (final item in queueItems) {
          final entityId = item['entityId'] as String;
          final queueId = item['id'] as int;
          if (conflictJanCodes.contains(entityId)) {
            await _db.updateSyncQueueStatus(
              queueId,
              'conflict',
              lastError: '409 conflict',
              conflictPayload: jsonEncode(
                conflictsRaw.where((e) {
                  final map = Map<String, dynamic>.from(e as Map);
                  return map['jan_code'] == entityId;
                }).toList(),
              ),
            );
            await _db.setProductSyncStatus(entityId, 'conflict');
          } else {
            await _db.markSyncQueueAsSynced(queueId);
            await _db.deleteSyncQueueItem(queueId);
            await _db.setProductSyncStatus(entityId, 'synced');
          }
        }
      }

      final serverTimestamp = data['server_timestamp'] as String?;
      if (serverTimestamp != null && serverTimestamp.isNotEmpty) {
        await _prefs.setString('last_sync_product_timestamp', serverTimestamp);
      }

      final appliedCount = data['applied_count'] as int? ?? 0;
      return ProductSyncResult(
        appliedCount: appliedCount,
        receivedFromServer: serverChangesRaw.length,
        conflicts: conflicts,
        success: true,
      );
    } on ApiException catch (e) {
      if (e.isAuthError && !retriedAuth) {
        final refreshed = await _auth.refreshAccessToken();
        if (refreshed) {
          return _syncProducts(
            push: push,
            includePull: includePull,
            retriedAuth: true,
          );
        }
      }

      if (push) {
        await _markQueueFailure(queueItems, e);
      }

      return ProductSyncResult(
        appliedCount: 0,
        receivedFromServer: 0,
        conflicts: const [],
        success: false,
        error: e.toString(),
      );
    } catch (e) {
      if (push) {
        await _markUnknownFailure(queueItems, e.toString());
      }
      return ProductSyncResult(
        appliedCount: 0,
        receivedFromServer: 0,
        conflicts: const [],
        success: false,
        error: e.toString(),
      );
    }
  }

  Future<InventorySyncResult> _syncInventories({
    required bool push,
    required bool includePull,
    bool retriedAuth = false,
  }) async {
    final queueItems = push
        ? await _db.getSyncQueueByStatuses(
            statuses: const ['pending', 'failed'],
            entityType: 'inventory',
          )
        : <Map<String, dynamic>>[];

    final lastSyncTimestamp = _prefs.getString('last_sync_inventory_timestamp') ??
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

    final inventoriesPayload = <Map<String, dynamic>>[];
    for (final item in queueItems) {
      final data = jsonDecode(item['payload'] as String) as Map<String, dynamic>;
      data['operation'] = item['operation'];
      final resolution = item['conflictResolution'] as String?;
      if (resolution != null && resolution.isNotEmpty) {
        data['resolution'] = resolution;
      }
      inventoriesPayload.add(data);
      await _db.updateSyncQueueStatus(item['id'] as int, 'syncing');
    }

    final request = {
      'last_sync_timestamp': includePull ? lastSyncTimestamp : DateTime.now().toIso8601String(),
      'client_timestamp': DateTime.now().toIso8601String(),
      'inventories': push ? inventoriesPayload : <Map<String, dynamic>>[],
    };

    try {
      final responseMap = await _retryWithBackoff(
        () => _api.syncInventoriesRaw(request),
      );
      final data = _extractResponseData(responseMap);

      final createdIdsRaw = (data['created_ids'] as List<dynamic>? ?? const []);
      for (final mappingRaw in createdIdsRaw) {
        final map = Map<String, dynamic>.from(mappingRaw as Map);
        final localIdRaw = map['client_temp_id']?.toString();
        final serverId = map['server_id'] as int?;
        final localId = int.tryParse(localIdRaw ?? '');
        if (localId != null && serverId != null) {
          await _db.remapInventoryId(localId: localId, serverId: serverId);
        }
      }

      final serverChangesRaw = (data['server_changes'] as List<dynamic>? ?? const []);
      for (final raw in serverChangesRaw) {
        final dto = InventoryDto.fromJson(Map<String, dynamic>.from(raw as Map));
        final inventory = Inventory(
          id: dto.id,
          janCode: dto.janCode,
          quantity: dto.quantity,
          expirationDate: DateTime.parse(dto.expirationDate),
          registrationDate: DateTime.parse(dto.registrationDate),
          isArchived: dto.isArchived,
        );
        await _db.insertInventory(inventory, syncStatus: 'synced');
      }

      final conflicts = <InventoryConflict>[];
      final conflictIds = <String>{};
      final conflictsRaw = (data['conflicts'] as List<dynamic>? ?? const []);
      for (final raw in conflictsRaw) {
        final map = Map<String, dynamic>.from(raw as Map);
        final conflict = InventoryConflict.fromJson(map);
        conflicts.add(conflict);
        conflictIds.add(conflict.id.toString());
      }

      if (push) {
        for (final item in queueItems) {
          final entityId = item['entityId'] as String;
          final queueId = item['id'] as int;
          if (conflictIds.contains(entityId)) {
            await _db.updateSyncQueueStatus(
              queueId,
              'conflict',
              lastError: '409 conflict',
              conflictPayload: jsonEncode(
                conflictsRaw.where((e) {
                  final map = Map<String, dynamic>.from(e as Map);
                  return map['id'].toString() == entityId;
                }).toList(),
              ),
            );
            final id = int.tryParse(entityId);
            if (id != null) {
              await _db.setInventorySyncStatus(id, 'conflict');
            }
          } else {
            await _db.markSyncQueueAsSynced(queueId);
            await _db.deleteSyncQueueItem(queueId);
            final id = int.tryParse(entityId);
            if (id != null) {
              await _db.setInventorySyncStatus(id, 'synced');
            }
          }
        }
      }

      final serverTimestamp = data['server_timestamp'] as String?;
      if (serverTimestamp != null && serverTimestamp.isNotEmpty) {
        await _prefs.setString('last_sync_inventory_timestamp', serverTimestamp);
      }

      final appliedCount = data['applied_count'] as int? ?? 0;
      return InventorySyncResult(
        appliedCount: appliedCount,
        receivedFromServer: serverChangesRaw.length,
        conflicts: conflicts,
        success: true,
      );
    } on ApiException catch (e) {
      if (e.isAuthError && !retriedAuth) {
        final refreshed = await _auth.refreshAccessToken();
        if (refreshed) {
          return _syncInventories(
            push: push,
            includePull: includePull,
            retriedAuth: true,
          );
        }
      }

      if (push) {
        await _markQueueFailure(queueItems, e);
      }

      return InventorySyncResult(
        appliedCount: 0,
        receivedFromServer: 0,
        conflicts: const [],
        success: false,
        error: e.toString(),
      );
    } catch (e) {
      if (push) {
        await _markUnknownFailure(queueItems, e.toString());
      }
      return InventorySyncResult(
        appliedCount: 0,
        receivedFromServer: 0,
        conflicts: const [],
        success: false,
        error: e.toString(),
      );
    }
  }

  Future<void> _markQueueFailure(
    List<Map<String, dynamic>> queueItems,
    ApiException e,
  ) async {
    for (final item in queueItems) {
      final queueId = item['id'] as int;

      if (e.isConflict) {
        await _db.updateSyncQueueStatus(
          queueId,
          'conflict',
          lastError: e.message,
          incrementRetry: true,
        );
      } else if (e.isValidationError || e.isValidation422) {
        await _db.updateSyncQueueStatus(
          queueId,
          'failed',
          lastError: e.message,
          incrementRetry: true,
        );
      } else {
        await _db.updateSyncQueueStatus(
          queueId,
          'failed',
          lastError: e.message,
          incrementRetry: true,
        );
      }
    }
  }

  Future<void> _markUnknownFailure(
    List<Map<String, dynamic>> queueItems,
    String message,
  ) async {
    for (final item in queueItems) {
      await _db.updateSyncQueueStatus(
        item['id'] as int,
        'failed',
        lastError: message,
        incrementRetry: true,
      );
    }
  }

  Future<bool> _isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<bool> _ensureAccessToken() async {
    final token = await ApiClient().getAccessToken();
    if (token == null) {
      return false;
    }

    final expiresAt = await ApiClient().getAccessTokenExpiresAt();
    if (expiresAt == null) {
      return await _auth.refreshAccessToken();
    }

    final needsRefresh = DateTime.now().isAfter(
      expiresAt.subtract(const Duration(minutes: 2)),
    );

    if (!needsRefresh) {
      return true;
    }

    return await _auth.refreshAccessToken();
  }

  Future<void> _safeActivate() async {
    try {
      await _retryWithBackoff(() => _api.activate());
    } catch (_) {
      // activate 失敗は同期本体を止めない
    }
  }

  Map<String, dynamic> _extractResponseData(Map<String, dynamic> responseMap) {
    final data = responseMap['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  Future<T> _retryWithBackoff<T>(
    Future<T> Function() action, {
    int maxAttempts = 3,
  }) async {
    var attempt = 0;
    while (true) {
      attempt += 1;
      try {
        return await action();
      } on ApiException catch (e) {
        final retryable = e.isServerError || _looksLikeTimeout(e.message);
        if (!retryable || attempt >= maxAttempts) {
          rethrow;
        }
      }

      final backoff = Duration(milliseconds: 400 * pow(2, attempt - 1).toInt());
      await Future.delayed(backoff);
    }
  }

  bool _looksLikeTimeout(String message) {
    final lower = message.toLowerCase();
    return lower.contains('timeout') ||
        lower.contains('connection') ||
        lower.contains('socket');
  }
}

class SyncConflictItem {
  final int queueId;
  final String entityType;
  final String entityId;
  final String operation;
  final String? lastError;
  final String payload;
  final String? conflictPayload;

  SyncConflictItem({
    required this.queueId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.lastError,
    required this.payload,
    required this.conflictPayload,
  });
}

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

  bool get hasConflicts =>
      productsResult.hasConflicts || inventoriesResult.hasConflicts;

  int get totalApplied =>
      productsResult.appliedCount + inventoriesResult.appliedCount;

  int get totalReceived =>
      productsResult.receivedFromServer + inventoriesResult.receivedFromServer;
}
