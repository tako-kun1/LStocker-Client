import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/inventory.dart';
import 'app_config.dart';
import 'database_helper.dart';
import 'product_key_service.dart';

class InventoryBackupDownloadResult {
  final bool success;
  final String message;
  final int restoredCount;

  const InventoryBackupDownloadResult({
    required this.success,
    required this.message,
    required this.restoredCount,
  });
}

class InventoryBackupUploadResult {
  final bool success;
  final String message;
  final int uploadedCount;

  const InventoryBackupUploadResult({
    required this.success,
    required this.message,
    required this.uploadedCount,
  });
}

class InventoryBackupService {
  static const String _backupServerUrlKey = 'backupServerUrl';

  final DatabaseHelper _db = DatabaseHelper();
  final ProductKeyService _productKeyService = ProductKeyService();

  Future<InventoryBackupDownloadResult>
  downloadLatestBackupForCurrentKey() async {
    final productKey = await _productKeyService.getProductKey();
    if (productKey == null || productKey.isEmpty) {
      return const InventoryBackupDownloadResult(
        success: false,
        message: 'プロダクトキーが未登録です。',
        restoredCount: 0,
      );
    }

    final baseUrl = await _resolveBaseUrl();
    if (baseUrl == null) {
      return const InventoryBackupDownloadResult(
        success: false,
        message: 'バックアップサーバー URL が未設定です。',
        restoredCount: 0,
      );
    }

    final dio = _createDio(baseUrl);

    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/api/v1/backups/inventories/latest',
        data: {'product_key': productKey},
      );

      final payload = _extractData(response.data ?? const <String, dynamic>{});
      final rawInventories = _extractInventoryList(payload);
      final inventories = rawInventories
          .map(_mapToInventory)
          .toList(growable: false);

      await _db.replaceAllInventories(inventories);
      await _db.clearSyncQueueByEntityType('inventory');

      return InventoryBackupDownloadResult(
        success: true,
        message: inventories.isEmpty
            ? '該当する在庫バックアップはありませんでした。'
            : '在庫バックアップを ${inventories.length} 件復元しました。',
        restoredCount: inventories.length,
      );
    } on DioException catch (e) {
      return InventoryBackupDownloadResult(
        success: false,
        message: _messageFromDio(e),
        restoredCount: 0,
      );
    } catch (e) {
      return InventoryBackupDownloadResult(
        success: false,
        message: '在庫バックアップの復元に失敗しました: $e',
        restoredCount: 0,
      );
    }
  }

  Future<InventoryBackupUploadResult> uploadCurrentInventoryBackup() async {
    final productKey = await _productKeyService.getProductKey();
    if (productKey == null || productKey.isEmpty) {
      return const InventoryBackupUploadResult(
        success: false,
        message: 'プロダクトキーが未登録です。',
        uploadedCount: 0,
      );
    }

    final baseUrl = await _resolveBaseUrl();
    if (baseUrl == null) {
      return const InventoryBackupUploadResult(
        success: false,
        message: 'バックアップサーバー URL が未設定です。',
        uploadedCount: 0,
      );
    }

    final dio = _createDio(baseUrl);
    final inventories = await _db.getInventories(includeArchived: true);

    try {
      await dio.post<Map<String, dynamic>>(
        '/api/v1/backups/inventories/upload',
        data: {
          'product_key': productKey,
          'inventories': inventories
              .map(_inventoryToBackupPayload)
              .toList(growable: false),
        },
      );

      return InventoryBackupUploadResult(
        success: true,
        message: '在庫バックアップを ${inventories.length} 件送信しました。',
        uploadedCount: inventories.length,
      );
    } on DioException catch (e) {
      return InventoryBackupUploadResult(
        success: false,
        message: _messageFromDio(e),
        uploadedCount: 0,
      );
    } catch (e) {
      return InventoryBackupUploadResult(
        success: false,
        message: '在庫バックアップの送信に失敗しました: $e',
        uploadedCount: 0,
      );
    }
  }

  Dio _createDio(String baseUrl) {
    return Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        contentType: 'application/json',
      ),
    );
  }

  Future<String?> _resolveBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final configured = prefs.getString(_backupServerUrlKey)?.trim() ?? '';
    if (configured.isNotEmpty) {
      return configured;
    }

    final fallback = AppConfig.defaultBaseUrl.trim();
    if (fallback.isNotEmpty) {
      return fallback;
    }
    return null;
  }

  Map<String, dynamic> _extractData(Map<String, dynamic> root) {
    final data = root['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return root;
  }

  List<Map<String, dynamic>> _extractInventoryList(
    Map<String, dynamic> payload,
  ) {
    final candidates = [
      payload['inventories'],
      payload['items'],
      payload['records'],
    ];
    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      }
    }
    return const <Map<String, dynamic>>[];
  }

  Inventory _mapToInventory(Map<String, dynamic> raw) {
    final id = _readInt(raw, ['id']);
    final janCode = _readString(raw, ['jan_code', 'janCode']) ?? '';
    final quantity = _readInt(raw, ['quantity']) ?? 0;
    final expirationDate =
        DateTime.tryParse(
          _readString(raw, ['expiration_date', 'expirationDate']) ?? '',
        ) ??
        DateTime.now();
    final registrationDate =
        DateTime.tryParse(
          _readString(raw, ['registration_date', 'registrationDate']) ?? '',
        ) ??
        DateTime.now();
    final isArchived = _readBool(raw, ['is_archived', 'isArchived']) ?? false;

    return Inventory(
      id: id,
      janCode: janCode,
      quantity: quantity,
      expirationDate: expirationDate,
      registrationDate: registrationDate,
      isArchived: isArchived,
    );
  }

  Map<String, dynamic> _inventoryToBackupPayload(Inventory inventory) {
    return {
      'id': inventory.id,
      'jan_code': inventory.janCode,
      'quantity': inventory.quantity,
      'expiration_date': inventory.expirationDate.toIso8601String(),
      'registration_date': inventory.registrationDate.toIso8601String(),
      'is_archived': inventory.isArchived,
    };
  }

  String? _readString(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = raw[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  int? _readInt(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = raw[key];
      if (value is int) {
        return value;
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  bool? _readBool(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = raw[key];
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') {
          return true;
        }
        if (normalized == 'false' || normalized == '0') {
          return false;
        }
      }
    }
    return null;
  }

  String _messageFromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final message = ((data['error'] as Map?)?['message'])?.toString();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }
    if (e.response?.statusCode != null) {
      return 'サーバー通信に失敗しました: HTTP ${e.response!.statusCode}';
    }
    return e.message ?? 'サーバー通信に失敗しました。';
  }
}
