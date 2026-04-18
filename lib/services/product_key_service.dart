import 'dart:math';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

class ProductKeyActivationResult {
  final bool success;
  final String message;

  const ProductKeyActivationResult({
    required this.success,
    required this.message,
  });
}

class ProductKeyStatusResult {
  final bool success;
  final String message;
  final String? licenseStatus;
  final String? policyMode;

  const ProductKeyStatusResult({
    required this.success,
    required this.message,
    this.licenseStatus,
    this.policyMode,
  });
}

class ProductKeyService {
  // Product key format: XXXX-XXXX-XXXX-XXXX (A-Z, 0-9)
  static const String keyFormatPattern = 'XXXX-XXXX-XXXX-XXXX';
  static const int keyRawLength = 16;
  static const _keyProduct = 'license_product_key';
  static const _keyActivated = 'license_is_activated';
  static const _keyActivatedAt = 'license_activated_at';
  static const _keyDeviceId = 'license_device_id';
  static const _keyLicenseId = 'license_id';
  static const _keyOfflineToken = 'license_offline_token';
  static const _keyLicenseStatus = 'license_status';
  static const _keyPolicyMode = 'license_policy_mode';
  static const _keyLastCheckedAt = 'license_last_checked_at';
  static const Duration _autoCheckInterval = Duration(hours: 24);
  static const String _statusOk = 'ok';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.licenseAuthServerBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      contentType: 'application/json',
    ),
  );

  Future<bool> isActivated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyActivated) ?? false;
  }

  Future<String?> getProductKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyProduct);
  }

  Future<String> getMaskedProductKey() async {
    final key = await getProductKey();
    if (key == null || key.isEmpty) {
      return '未登録';
    }

    if (key.length <= 8) {
      return '****';
    }

    return '${key.substring(0, 4)}****${key.substring(key.length - 4)}';
  }

  Future<ProductKeyActivationResult> activateProductKey(String input) async {
    final normalized = _normalize(input);
    if (!_isValidFormat(normalized)) {
      return const ProductKeyActivationResult(
        success: false,
        message: 'プロダクトキーの形式が不正です。',
      );
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = await _getOrCreateDeviceId(prefs);
      final idempotencyKey = _createIdempotencyKey();

      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/license/activate',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Idempotency-Key': idempotencyKey,
          },
        ),
        data: {
          'license_key': normalized,
          'device_id': deviceId,
        },
      );

      final body = response.data ?? const <String, dynamic>{};
      final status = body['status'] as String?;
      if (status != _statusOk) {
        return ProductKeyActivationResult(
          success: false,
          message: _extractErrorMessage(body) ?? '認証サーバーの応答が不正です。',
        );
      }

      final data = (body['data'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final result = (data['result'] ?? '').toString();
      if (result != _statusOk) {
        return ProductKeyActivationResult(
          success: false,
          message: _extractErrorMessage(body) ?? '認証サーバーの応答が不正です。',
        );
      }

      final responseLicenseKey = (data['license_key'] ?? '').toString();
      if (responseLicenseKey.isEmpty) {
        return const ProductKeyActivationResult(
          success: false,
          message: 'ライセンスキーがレスポンスに含まれていません。',
        );
      }

      await prefs.setString(_keyProduct, normalized);
      await prefs.setBool(_keyActivated, true);
      await prefs.setString(_keyActivatedAt, DateTime.now().toIso8601String());
      await prefs.setString(_keyDeviceId, deviceId);
      // 互換のため license_id は保持（未提供なら空文字）
      await prefs.setString(_keyLicenseId, (data['license_id'] ?? '').toString());
      await prefs.setString(
        _keyOfflineToken,
        (data['offline_token'] ?? '').toString(),
      );
      await prefs.setString(
        _keyLicenseStatus,
        (data['status'] ?? 'unknown').toString(),
      );

      final policy = (data['policy'] ?? 'full').toString();
      await prefs.setString(
        _keyPolicyMode,
        policy,
      );
      await prefs.setString(_keyLastCheckedAt, DateTime.now().toIso8601String());

      return const ProductKeyActivationResult(
        success: true,
        message: 'プロダクトキーを認証しました。',
      );
    } on DioException catch (e) {
      return ProductKeyActivationResult(
        success: false,
        message: _messageFromDio(e),
      );
    } catch (_) {
      return const ProductKeyActivationResult(
        success: false,
        message: '認証中に予期しないエラーが発生しました。',
      );
    }
  }

  Future<ProductKeyStatusResult> checkLicenseStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final licenseKey = prefs.getString(_keyProduct);
    final offlineToken = prefs.getString(_keyOfflineToken);
    final deviceId = prefs.getString(_keyDeviceId);

    if ((licenseKey == null || licenseKey.isEmpty) ||
        (deviceId == null || deviceId.isEmpty)) {
      return const ProductKeyStatusResult(
        success: false,
        message: 'ライセンス情報が不足しています。再認証してください。',
      );
    }

    try {
      final idempotencyKey = _createIdempotencyKey();
      final request = <String, dynamic>{
        'license_key': licenseKey,
        'device_id': deviceId,
      };
      if (offlineToken != null && offlineToken.isNotEmpty) {
        request['offline_token'] = offlineToken;
      }

      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/license/heartbeat',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Idempotency-Key': idempotencyKey,
          },
        ),
        data: request,
      );

      final body = response.data ?? const <String, dynamic>{};
      final status = body['status'] as String?;
      if (status != _statusOk) {
        return ProductKeyStatusResult(
          success: false,
          message: _extractErrorMessage(body) ?? 'ライセンス確認に失敗しました。',
        );
      }

      final data = (body['data'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final result = (data['result'] ?? '').toString();
      if (result != _statusOk) {
        return ProductKeyStatusResult(
          success: false,
          message: _extractErrorMessage(body) ?? 'ライセンス確認に失敗しました。',
        );
      }

      final licenseStatus = (data['status'] ?? 'unknown').toString();
      final mode = (data['policy'] ?? 'full').toString();

      await prefs.setString(_keyLicenseStatus, licenseStatus);
      await prefs.setString(_keyPolicyMode, mode);
      await prefs.setString(_keyLastCheckedAt, DateTime.now().toIso8601String());

      final rotatedToken = (data['offline_token'] ?? '').toString();
      if (rotatedToken.isNotEmpty) {
        await prefs.setString(_keyOfflineToken, rotatedToken);
      }

      return ProductKeyStatusResult(
        success: true,
        message: 'ライセンス状態を更新しました。',
        licenseStatus: licenseStatus,
        policyMode: mode,
      );
    } on DioException catch (e) {
      return ProductKeyStatusResult(
        success: false,
        message: _messageFromDio(e),
      );
    } catch (_) {
      return const ProductKeyStatusResult(
        success: false,
        message: 'ライセンス確認中に予期しないエラーが発生しました。',
      );
    }
  }

  Future<ProductKeyStatusResult> checkLicenseStatusIfDue() async {
    final due = await _isDailyCheckDue();
    if (!due) {
      return const ProductKeyStatusResult(
        success: true,
        message: 'ライセンス確認は本日実施済みです。',
      );
    }

    return checkLicenseStatus();
  }

  Future<String> getLicenseSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final status = prefs.getString(_keyLicenseStatus) ?? 'unknown';
    final mode = prefs.getString(_keyPolicyMode) ?? 'full';
    return 'status=$status / mode=$mode';
  }

  Future<bool> _isDailyCheckDue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyLastCheckedAt);
    if (raw == null || raw.isEmpty) {
      return true;
    }

    final lastChecked = DateTime.tryParse(raw);
    if (lastChecked == null) {
      return true;
    }

    return DateTime.now().difference(lastChecked) >= _autoCheckInterval;
  }

  Future<void> clearActivation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyProduct);
    await prefs.remove(_keyActivated);
    await prefs.remove(_keyActivatedAt);
    await prefs.remove(_keyLicenseId);
    await prefs.remove(_keyOfflineToken);
    await prefs.remove(_keyLicenseStatus);
    await prefs.remove(_keyPolicyMode);
    await prefs.remove(_keyLastCheckedAt);
  }

  String _normalize(String input) {
    final raw = input
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (raw.length != keyRawLength) {
      return raw;
    }

    return '${raw.substring(0, 4)}-'
        '${raw.substring(4, 8)}-'
        '${raw.substring(8, 12)}-'
        '${raw.substring(12, 16)}';
  }

  bool _isValidFormat(String key) {
    // 形式: XXXX-XXXX-XXXX-XXXX（A-Z,0-9）
    final regex = RegExp(r'^[A-Z0-9]{4}(?:-[A-Z0-9]{4}){3}$');
    return regex.hasMatch(key);
  }

  Future<String> _getOrCreateDeviceId(SharedPreferences prefs) async {
    final existing = prefs.getString(_keyDeviceId);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final created = _createPseudoUuid();
    await prefs.setString(_keyDeviceId, created);
    return created;
  }

  String _createIdempotencyKey() {
    return _createPseudoUuid();
  }

  String _createPseudoUuid() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

  String _messageFromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final message = ((data['error'] as Map?)?['message'])?.toString();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return '認証サーバーに接続できません。通信状態を確認してください。';
    }
    return '認証に失敗しました。(${e.response?.statusCode ?? 'network'})';
  }

  String? _extractErrorMessage(Map<String, dynamic> body) {
    final error = body['error'];
    if (error is Map) {
      final message = error['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }

      final code = error['code'];
      if (code is String && code.isNotEmpty) {
        return code;
      }
    }
    return null;
  }
}
