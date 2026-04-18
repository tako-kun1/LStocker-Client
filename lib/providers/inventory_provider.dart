import 'package:flutter/foundation.dart';
import '../models/inventory.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';

class InventoryProvider with ChangeNotifier {
  List<Inventory> _inventories = [];
  List<Map<String, dynamic>> _inventoriesWithProduct = [];
  bool _isLoading = false;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SyncService _syncService = SyncService();

  List<Inventory> get inventories => _inventories;
  List<Map<String, dynamic>> get inventoriesWithProduct =>
      _inventoriesWithProduct;
  bool get isLoading => _isLoading;
  int get nearExpirationNotificationCount =>
      getNearExpirationInventories().length;

  Future<void> fetchInventories() async {
    _isLoading = true;
    notifyListeners();

    try {
      final sw = Stopwatch()..start();
      final inventoriesWithProduct = await _dbHelper
          .getInventoriesWithProduct();
      _inventoriesWithProduct = inventoriesWithProduct;
      _inventories = inventoriesWithProduct
          .map((item) => Inventory.fromMap(item))
          .toList(growable: false);
      try {
        await NotificationService().syncNearExpirationNotifications(
          _inventoriesWithProduct,
        );
      } catch (e) {
        debugPrint('[InventoryProvider] notification sync failed: $e');
      }
      debugPrint(
        '[InventoryProvider] loaded ${_inventories.length} inventories in ${sw.elapsedMilliseconds}ms',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 期限間近の通知データを取得
  List<Map<String, dynamic>> getNearExpirationInventories() {
    final now = DateTime.now();
    return _inventoriesWithProduct.where((item) {
      final expirationDate = DateTime.parse(item['expirationDate']);
      final salesPeriod = item['salesPeriod'] as int;
      final notificationDate = expirationDate.subtract(
        Duration(days: salesPeriod),
      );

      final diff = notificationDate.difference(now).inDays;
      return diff <= 3;
    }).toList();
  }

  Future<void> addInventory(Inventory inventory) async {
    _isLoading = true;
    notifyListeners();

    try {
      // ローカル DB に追加
      final insertedId = await _dbHelper.insertInventory(
        inventory,
        syncStatus: 'pending',
      );

      // Sync queue に追加
      await _syncService.queueInventoryChange(
        id: insertedId,
        janCode: inventory.janCode,
        quantity: inventory.quantity,
        expirationDate: inventory.expirationDate.toIso8601String().split(
          'T',
        )[0],
        registrationDate: inventory.registrationDate.toIso8601String().split(
          'T',
        )[0],
        isArchived: inventory.isArchived,
        operation: 'create',
      );

      await fetchInventories();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> archiveInventory(int id) async {
    await _dbHelper.archiveInventory(id, syncStatus: 'pending');

    // Sync queue に追加
    final inventory = _inventories.firstWhere((i) => i.id == id);
    await _syncService.queueInventoryChange(
      id: id,
      janCode: inventory.janCode,
      quantity: inventory.quantity,
      expirationDate: inventory.expirationDate.toIso8601String().split('T')[0],
      registrationDate: inventory.registrationDate.toIso8601String().split(
        'T',
      )[0],
      isArchived: true,
      operation: 'update',
    );

    await fetchInventories();
  }

  Future<void> deleteInventory(int id) async {
    await _dbHelper.archiveInventory(id, syncStatus: 'pending');

    // Sync queue に追加
    final inventory = _inventories.firstWhere(
      (i) => i.id == id,
      orElse: () => Inventory(
        id: id,
        janCode: '',
        expirationDate: DateTime.now(),
        quantity: 0,
        registrationDate: DateTime.now(),
      ),
    );

    await _syncService.queueInventoryChange(
      id: id,
      janCode: inventory.janCode,
      quantity: inventory.quantity,
      expirationDate: inventory.expirationDate.toIso8601String().split('T')[0],
      registrationDate: inventory.registrationDate.toIso8601String().split(
        'T',
      )[0],
      isArchived: true,
      operation: 'delete',
    );

    await fetchInventories();
  }
}
