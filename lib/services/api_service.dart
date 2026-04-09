import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/api_models.dart';

/// API サービス - 各エンドポイントの呼び出し
class ApiService {
  static final ApiService _instance = ApiService._internal();
  final _apiClient = ApiClient();

  factory ApiService() {
    return _instance;
  }

  ApiService._internal();

  // ==================== Health / Bootstrap ====================

  Future<void> health() async {
    try {
      await _apiClient.get('/health');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Map<String, dynamic>> info() async {
    try {
      final response = await _apiClient.get('/info');
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> activate() async {
    try {
      await _apiClient.post('/activate');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ==================== Products ====================

  /// 商品一覧を取得
  Future<ProductListResponse> getProducts({
    String? since,
    int limit = 1000,
    int offset = 0,
  }) async {
    try {
      final queryParameters = {
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      if (since != null) {
        queryParameters['since'] = since;
      }

      final response = await _apiClient.get(
        '/products',
        queryParameters: queryParameters,
      );

      final successResponse = SuccessResponse.fromJson(
        response.data,
        (json) => ProductListResponse.fromJson(json as Map<String, dynamic>),
      );

      return successResponse.data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 商品を同期（送信 + サーバー変更受信）
  Future<ProductSyncResponse> syncProducts(
    ProductSyncRequest request,
  ) async {
    try {
      final response = await _apiClient.post(
        '/products/sync',
        data: request.toJson(),
      );

      final successResponse = SuccessResponse.fromJson(
        response.data,
        (json) => ProductSyncResponse.fromJson(json as Map<String, dynamic>),
      );

      return successResponse.data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Map<String, dynamic>> syncProductsRaw(
    Map<String, dynamic> request,
  ) async {
    try {
      final response = await _apiClient.post('/products/sync', data: request);
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<ProductDto> getProduct(String janCode) async {
    try {
      final response = await _apiClient.get('/products/$janCode');
      final successResponse = SuccessResponse.fromJson(
        response.data,
        (json) => ProductDto.fromJson(json as Map<String, dynamic>),
      );
      return successResponse.data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> createProduct(ProductUpdateDto request) async {
    try {
      await _apiClient.post('/products', data: request.toJson());
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> updateProduct(String janCode, ProductUpdateDto request) async {
    try {
      await _apiClient.put('/products/$janCode', data: request.toJson());
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> deleteProduct(String janCode) async {
    try {
      await _apiClient.delete('/products/$janCode');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ==================== Inventories ====================

  /// 在庫一覧を取得
  Future<InventoryListResponse> getInventories({
    String? since,
    int limit = 1000,
    int offset = 0,
    String? janCode,
  }) async {
    try {
      final queryParameters = {
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      if (since != null) {
        queryParameters['since'] = since;
      }

      if (janCode != null) {
        queryParameters['jan_code'] = janCode;
      }

      final response = await _apiClient.get(
        '/inventories',
        queryParameters: queryParameters,
      );

      final successResponse = SuccessResponse.fromJson(
        response.data,
        (json) => InventoryListResponse.fromJson(json as Map<String, dynamic>),
      );

      return successResponse.data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 在庫を同期（送信 + サーバー変更受信）
  Future<InventorySyncResponse> syncInventories(
    InventorySyncRequest request,
  ) async {
    try {
      final response = await _apiClient.post(
        '/inventories/sync',
        data: request.toJson(),
      );

      final successResponse = SuccessResponse.fromJson(
        response.data,
        (json) => InventorySyncResponse.fromJson(json as Map<String, dynamic>),
      );

      return successResponse.data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Map<String, dynamic>> syncInventoriesRaw(
    Map<String, dynamic> request,
  ) async {
    try {
      final response = await _apiClient.post('/inventories/sync', data: request);
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<InventoryDto> getInventory(int id) async {
    try {
      final response = await _apiClient.get('/inventories/$id');
      final successResponse = SuccessResponse.fromJson(
        response.data,
        (json) => InventoryDto.fromJson(json as Map<String, dynamic>),
      );
      return successResponse.data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> createInventory(InventoryUpdateDto request) async {
    try {
      await _apiClient.post('/inventories', data: request.toJson());
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> updateInventory(int id, InventoryUpdateDto request) async {
    try {
      await _apiClient.put('/inventories/$id', data: request.toJson());
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> deleteInventory(int id) async {
    try {
      await _apiClient.delete('/inventories/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ==================== Departments ====================

  /// 部門一覧を取得
  Future<DepartmentListResponse> getDepartments() async {
    try {
      final response = await _apiClient.get('/departments');

      final successResponse = SuccessResponse.fromJson(
        response.data,
        (json) => DepartmentListResponse.fromJson(json as Map<String, dynamic>),
      );

      return successResponse.data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<int>> getImageBytes(String id) async {
    try {
      final response = await _apiClient.dio.get<List<int>>(
        '/images/$id',
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? <int>[];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

/// API エラー
class ApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final dynamic originalError;

  ApiException({
    required this.message,
    this.code,
    this.statusCode,
    this.originalError,
  });

  factory ApiException.fromDioException(DioException e) {
    String message;
    String? code;
    int? statusCode = e.response?.statusCode;

    if (e.response?.data is Map) {
      final responseData = e.response!.data as Map;
      if (responseData.containsKey('error')) {
        final error = responseData['error'] as Map?;
        message = error?['message'] ?? e.message ?? 'Unknown error';
        code = error?['code'] as String?;
      } else {
        message = e.message ?? 'Unknown error';
      }
    } else {
      message = e.message ?? 'Unknown error';
    }

    return ApiException(
      message: message,
      code: code,
      statusCode: statusCode,
      originalError: e,
    );
  }

  @override
  String toString() => 'ApiException($statusCode): $message${code != null ? ' ($code)' : ''}';

  /// 認証エラーか判定
  bool get isAuthError => statusCode == 401;

  /// バリデーションエラーか判定
  bool get isValidationError => statusCode == 400;

  bool get isValidation422 => statusCode == 422;

  /// リソースが見つからないか判定
  bool get isNotFound => statusCode == 404;

  /// 競合エラーか判定
  bool get isConflict => statusCode == 409;

  bool get isServerError => statusCode != null && statusCode! >= 500;
}
