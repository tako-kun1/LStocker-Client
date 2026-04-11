import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
  static const _keyProduct = 'license_product_key';
  static const _keyActivated = 'license_is_activated';
  static const _keyActivatedAt = 'license_activated_at';
  static const _keyDeviceId = 'license_device_id';
  static const _keyLicenseId = 'license_id';
  static const _keyOfflineToken = 'license_offline_token';
  static const _keyLicenseStatus = 'license_status';
  static const _keyPolicyMode = 'license_policy_mode';
  static const _keyLastCheckedAt = 'license_last_checked_at';

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
      final packageInfo = await PackageInfo.fromPlatform();
      final deviceId = await _getOrCreateDeviceId(prefs);
      final challenge = _createChallenge();

      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/license/activate',
        data: {
          'product_key': normalized,
          'device': {
            'device_id': deviceId,
            'device_name': _deviceName(),
            'platform': _platformName(),
            'app_version': '${packageInfo.version}+${packageInfo.buildNumber}',
          },
          'challenge': challenge,
        },
      );

      final body = response.data ?? const <String, dynamic>{};
      final status = body['status'] as String?;
      if (status != 'success') {
        return ProductKeyActivationResult(
          success: false,
          message: _extractErrorMessage(body) ?? '認証サーバーの応答が不正です。',
        );
      }

      final data = (body['data'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      await prefs.setString(_keyProduct, normalized);
      await prefs.setBool(_keyActivated, true);
      await prefs.setString(_keyActivatedAt, DateTime.now().toIso8601String());
      await prefs.setString(_keyDeviceId, deviceId);
      await prefs.setString(_keyLicenseId, (data['license_id'] ?? '').toString());
      await prefs.setString(
        _keyOfflineToken,
        (data['offline_token'] ?? '').toString(),
      );
      await prefs.setString(
        _keyLicenseStatus,
        (data['license_status'] ?? 'active').toString(),
      );

      final policy = (data['policy'] as Map?)?.cast<String, dynamic>();
      await prefs.setString(
        _keyPolicyMode,
        (policy?['mode'] ?? 'full').toString(),
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
    final licenseId = prefs.getString(_keyLicenseId);
    final offlineToken = prefs.getString(_keyOfflineToken);
    final deviceId = prefs.getString(_keyDeviceId);

    if ((licenseId == null || licenseId.isEmpty) ||
        (offlineToken == null || offlineToken.isEmpty) ||
        (deviceId == null || deviceId.isEmpty)) {
      return const ProductKeyStatusResult(
        success: false,
        message: 'ライセンス情報が不足しています。再認証してください。',
      );
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/license/heartbeat',
        data: {
          'license_id': licenseId,
          'device_id': deviceId,
          'offline_token': offlineToken,
          'app_version': '${packageInfo.version}+${packageInfo.buildNumber}',
        },
      );

      final body = response.data ?? const <String, dynamic>{};
      final status = body['status'] as String?;
      if (status != 'success') {
        return ProductKeyStatusResult(
          success: false,
          message: _extractErrorMessage(body) ?? 'ライセンス確認に失敗しました。',
        );
      }

      final data = (body['data'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final licenseStatus = (data['license_status'] ?? 'unknown').toString();
      final policy = (data['policy'] as Map?)?.cast<String, dynamic>();
      final mode = (policy?['mode'] ?? 'full').toString();

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

  Future<String> getLicenseSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final status = prefs.getString(_keyLicenseStatus) ?? 'unknown';
    final mode = prefs.getString(_keyPolicyMode) ?? 'full';
    return 'status=$status / mode=$mode';
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
    return input.trim().toUpperCase().replaceAll(' ', '');
  }

  bool _isValidFormat(String key) {
    // 例: ABCD-1234-EFGH-5678
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

  String _createChallenge() {
    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    return base64UrlEncode(bytes);
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

  String _platformName() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  String _deviceName() {
    final host = Platform.localHostname.trim();
    if (host.isNotEmpty) {
      return host;
    }
    return _platformName();
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
    }
    return null;
  }
}
