import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/inventory.dart';
import '../services/database_helper.dart';
import '../services/inventory_backup_scheduler.dart';
import '../services/notification_service.dart';

class InventoryProvider with ChangeNotifier {
  static const String _lastSeenNotificationSignatureKey =
      'lastSeenNearExpirationNotificationSignature';

  List<Inventory> _inventories = [];
  List<Map<String, dynamic>> _inventoriesWithProduct = [];
  bool _isLoading = false;
  bool _hasUnreadNearExpirationNotifications = false;

  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<Inventory> get inventories => _inventories;
  List<Map<String, dynamic>> get inventoriesWithProduct =>
      _inventoriesWithProduct;
  bool get isLoading => _isLoading;
    bool get hasUnreadNearExpirationNotifications =>
      _hasUnreadNearExpirationNotifications;
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

      final notifications = getNearExpirationInventories();
      final currentSignature = _buildNotificationSignature(notifications);
      final prefs = await SharedPreferences.getInstance();
      final seenSignature =
          prefs.getString(_lastSeenNotificationSignatureKey) ?? '';
      _hasUnreadNearExpirationNotifications =
          notifications.isNotEmpty && currentSignature != seenSignature;

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
      final salesPeriod = (item['salesPeriod'] as num?)?.toInt() ?? 0;
      final notificationDate = expirationDate.subtract(
        Duration(days: salesPeriod),
      );

      final diff = notificationDate.difference(now).inDays;
      return diff <= 3;
    }).toList();
  }

  Future<void> markNearExpirationNotificationsAsRead() async {
    final notifications = getNearExpirationInventories();
    final currentSignature = _buildNotificationSignature(notifications);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSeenNotificationSignatureKey, currentSignature);

    if (_hasUnreadNearExpirationNotifications) {
      _hasUnreadNearExpirationNotifications = false;
      notifyListeners();
    }
  }

  String _buildNotificationSignature(List<Map<String, dynamic>> notifications) {
    if (notifications.isEmpty) {
      return '';
    }

    final keys = notifications.map((item) {
      final id = item['id']?.toString() ?? '';
      final expiration = item['expirationDate']?.toString() ?? '';
      final salesPeriod = item['salesPeriod']?.toString() ?? '';
      return '$id|$expiration|$salesPeriod';
    }).toList()
      ..sort();

    return keys.join('||');
  }

  Future<void> addInventory(Inventory inventory) async {
    _isLoading = true;
    notifyListeners();

    try {
      // ローカル DB に追加
      await _dbHelper.insertInventory(inventory, syncStatus: 'synced');

      await fetchInventories();
      unawaited(InventoryBackupScheduler().handleInventoryChanged());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> archiveInventory(int id) async {
    await _dbHelper.archiveInventory(id, syncStatus: 'synced');

    await fetchInventories();
    unawaited(InventoryBackupScheduler().handleInventoryChanged());
  }

  Future<void> deleteInventory(int id) async {
    await _dbHelper.archiveInventory(id, syncStatus: 'synced');

    await fetchInventories();
    unawaited(InventoryBackupScheduler().handleInventoryChanged());
  }
}
