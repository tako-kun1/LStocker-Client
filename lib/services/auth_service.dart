import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import '../models/api_models.dart';

/// 認証サービス - ログイン、ログアウト、トークン管理
class AuthService {
  static final AuthService _instance = AuthService._internal();
  final _apiClient = ApiClient();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  /// ユーザーがログイン済みかどうかを確認
  Future<bool> isLoggedIn() async {
    final token = await _apiClient.getAccessToken();
    if (token == null) return false;

    final expiresAt = await _apiClient.getAccessTokenExpiresAt();
    if (expiresAt == null) return false;

    // バッファ（5分）を考慮して、有効期限を確認
    return DateTime.now().isBefore(expiresAt.subtract(const Duration(minutes: 5)));
  }

  /// ログイン
  Future<LoginResponse> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        '/auth/login',
        data: LoginRequest(username: username, password: password).toJson(),
      );

      final successResponse = SuccessResponse.fromJson(
        response.data,
        (json) => LoginResponse.fromJson(json as Map<String, dynamic>),
      );

      // トークンを保存
      final loginData = successResponse.data;
      await _apiClient.setAccessToken(loginData.accessToken);
      await _apiClient.setRefreshToken(loginData.refreshToken);
      await _apiClient.setUserId(loginData.userId);
      await _apiClient.setUsername(loginData.username);

      // トークン有効期限を保存
      final expiresAt = DateTime.now().add(Duration(seconds: loginData.expiresIn));
      await _apiClient.setAccessTokenExpiresAt(expiresAt);

      // リフレッシュトークンは7日有効
      final refreshExpiresAt = DateTime.now().add(const Duration(days: 7));
      await _apiClient.setRefreshTokenExpiresAt(refreshExpiresAt);

      return loginData;
    } on Exception catch (e) {
      throw _parseException(e);
    }
  }

  /// ログアウト
  Future<void> logout() async {
    try {
      await _apiClient.clearTokens();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('username');
      await prefs.remove('last_sync_timestamp');
      await prefs.remove('last_sync_product_timestamp');
      await prefs.remove('last_sync_inventory_timestamp');
    } on Exception catch (e) {
      throw _parseException(e);
    }
  }

  /// 現在のユーザーID を取得
  Future<int?> getCurrentUserId() async {
    return await _apiClient.getUserId();
  }

  /// 現在のユーザー名を取得
  Future<String?> getCurrentUsername() async {
    return await _apiClient.getUsername();
  }

  /// アクセストークンを手動でリフレッシュ
  Future<bool> refreshAccessToken() async {
    try {
      final refreshToken = await _apiClient.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await _apiClient.post(
        '/auth/refresh',
        data: RefreshTokenRequest(refreshToken: refreshToken).toJson(),
      );

      final successResponse = SuccessResponse.fromJson(
        response.data,
        (json) => RefreshTokenResponse.fromJson(json as Map<String, dynamic>),
      );

      final refreshData = successResponse.data;
      await _apiClient.setAccessToken(refreshData.accessToken);

      final expiresAt = DateTime.now().add(Duration(seconds: refreshData.expiresIn));
      await _apiClient.setAccessTokenExpiresAt(expiresAt);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// トークンの残り有効期限（秒）を取得
  Future<int?> getAccessTokenRemainingSeconds() async {
    final expiresAt = await _apiClient.getAccessTokenExpiresAt();
    if (expiresAt == null) return null;

    final remaining = expiresAt.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  // ==================== Error Parsing ====================

  Exception _parseException(Exception e) {
    return AuthException(message: e.toString());
  }
}

/// 認証エラー
class AuthException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AuthException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'AuthException: $message';
}
