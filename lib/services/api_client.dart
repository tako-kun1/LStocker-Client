import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_models.dart';

/// APIクライアント - Dio を使用した HTTP 通信と JWT トークン管理
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();

  Dio? _dio;
  SharedPreferences? _prefs;
  String? _baseUrl;
  bool _isInitialized = false;

  // トークンリフレッシュ中かどうかを追跡
  Future<void>? _refreshingFuture;

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal();

  /// 初期化 - アプリ起動時に呼び出す
  Future<void> initialize(String baseUrl) async {
    if (_isInitialized && _baseUrl == baseUrl) return;

    _baseUrl = baseUrl;
    _prefs ??= await SharedPreferences.getInstance();

    // ignore: avoid_print
    print('ApiClient initialized with baseUrl: $_baseUrl');

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      contentType: 'application/json',
    ));

    // JWT トークンインターセプター を追加
    _dio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );

    _isInitialized = true;
  }

  /// SharedPreferences を確実に取得するためのメソッド
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// リクエスト前処理 - JWT トークンをヘッダーに追加
  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  /// レスポンス処理
  Future<void> _onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    handler.next(response);
  }

  /// エラー処理 - 401 の場合はトークンリフレッシュを試みる
  Future<void> _onError(
    DioException dioError,
    ErrorInterceptorHandler handler,
  ) async {
    if (dioError.response?.statusCode == 401) {
      // トークンリフレッシュを試みる
      final refreshed = await _refreshAccessToken();

      if (refreshed) {
        // リクエストを再試行
        final options = dioError.requestOptions;
        final token = await getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        try {
          final response = await _dio!.request(
            options.path,
            options: Options(
              method: options.method,
              headers: options.headers,
            ),
            data: options.data,
            queryParameters: options.queryParameters,
          );
          handler.resolve(response);
          return;
        } on DioException catch (e) {
          handler.next(e);
        }
      } else {
        // リフレッシュ失敗 → ログアウト処理へ
        handler.next(dioError);
      }
    } else {
      handler.next(dioError);
    }
  }

  /// トークンリフレッシュ
  Future<bool> _refreshAccessToken() async {
    // 既にリフレッシュ中なら待機
    if (_refreshingFuture != null) {
      try {
        await _refreshingFuture;
        return (await getAccessToken()) != null;
      } catch (e) {
        return false;
      }
    }

    final refreshToken = await getRefreshToken();
    if (refreshToken == null) return false;

    // リフレッシュ処理自体を Future に保持する
    _refreshingFuture = _performRefresh(refreshToken);

    try {
      await _refreshingFuture;
      _refreshingFuture = null;
      return true;
    } catch (e) {
      _refreshingFuture = null;
      // ログアウト処理が必要（呼び出し側で判定）
      await clearTokens();
      return false;
    }
  }

  Future<void> _performRefresh(String refreshToken) async {
    if (_dio == null) return;
    
    final response = await _dio!.post(
      '/auth/refresh',
      data: RefreshTokenRequest(refreshToken: refreshToken).toJson(),
    );

    final refreshResponse = RefreshTokenResponse.fromJson(response.data['data']);
    await setAccessToken(refreshResponse.accessToken);
    await setAccessTokenExpiresAt(
      DateTime.now().add(Duration(seconds: refreshResponse.expiresIn)),
    );
  }

  // ==================== Token Management ====================

  /// アクセストークンを取得
  Future<String?> getAccessToken() async {
    final prefs = await _getPrefs();
    return prefs.getString('access_token');
  }

  /// アクセストークンを保存
  Future<void> setAccessToken(String token) async {
    final prefs = await _getPrefs();
    await prefs.setString('access_token', token);
  }

  /// リフレッシュトークンを取得
  Future<String?> getRefreshToken() async {
    final prefs = await _getPrefs();
    return prefs.getString('refresh_token');
  }

  /// リフレッシュトークンを保存
  Future<void> setRefreshToken(String token) async {
    final prefs = await _getPrefs();
    await prefs.setString('refresh_token', token);
  }

  /// アクセストークン有効期限
  Future<void> setAccessTokenExpiresAt(DateTime expiresAt) async {
    final prefs = await _getPrefs();
    await prefs.setInt('access_token_expires_at', expiresAt.millisecondsSinceEpoch);
  }

  Future<DateTime?> getAccessTokenExpiresAt() async {
    final prefs = await _getPrefs();
    final ms = prefs.getInt('access_token_expires_at');
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// リフレッシュトークン有効期限
  Future<void> setRefreshTokenExpiresAt(DateTime expiresAt) async {
    final prefs = await _getPrefs();
    await prefs.setInt('refresh_token_expires_at', expiresAt.millisecondsSinceEpoch);
  }

  Future<DateTime?> getRefreshTokenExpiresAt() async {
    final prefs = await _getPrefs();
    final ms = prefs.getInt('refresh_token_expires_at');
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// トークンをクリア（ログアウト時）
  Future<void> clearTokens() async {
    final prefs = await _getPrefs();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('access_token_expires_at');
    await prefs.remove('refresh_token_expires_at');
  }

  /// ユーザーID を保存
  Future<void> setUserId(int userId) async {
    final prefs = await _getPrefs();
    await prefs.setInt('user_id', userId);
  }

  /// ユーザーID を取得
  Future<int?> getUserId() async {
    final prefs = await _getPrefs();
    return prefs.getInt('user_id');
  }

  /// ユーザー名を保存
  Future<void> setUsername(String username) async {
    final prefs = await _getPrefs();
    await prefs.setString('username', username);
  }

  /// ユーザー名を取得
  Future<String?> getUsername() async {
    final prefs = await _getPrefs();
    return prefs.getString('username');
  }

  // ==================== HTTP Methods ====================

  /// GET リクエスト
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    if (_dio == null) throw StateError('ApiClient not initialized. Call initialize() first.');
    return _dio!.get(path, queryParameters: queryParameters);
  }

  /// POST リクエスト
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    if (_dio == null) throw StateError('ApiClient not initialized. Call initialize() first.');
    return _dio!.post(path, data: data, queryParameters: queryParameters);
  }

  /// PUT リクエスト
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    if (_dio == null) throw StateError('ApiClient not initialized. Call initialize() first.');
    return _dio!.put(path, data: data, queryParameters: queryParameters);
  }

  /// DELETE リクエスト
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    if (_dio == null) throw StateError('ApiClient not initialized. Call initialize() first.');
    return _dio!.delete(path, data: data, queryParameters: queryParameters);
  }

  /// Dio インスタンスを取得（直接使用時）
  Dio get dio {
    if (_dio == null) throw StateError('ApiClient not initialized. Call initialize() first.');
    return _dio!;
  }
}
