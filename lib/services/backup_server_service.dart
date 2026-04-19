import 'package:dio/dio.dart';

class BackupServerConnectionResult {
  final bool success;
  final String message;

  const BackupServerConnectionResult({
    required this.success,
    required this.message,
  });
}

class BackupServerService {
  Future<BackupServerConnectionResult> testConnection(String rawUrl) async {
    final normalizedUrl = rawUrl.trim();
    if (normalizedUrl.isEmpty) {
      return const BackupServerConnectionResult(
        success: false,
        message: 'バックアップサーバー URL を入力してください。',
      );
    }

    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return const BackupServerConnectionResult(
        success: false,
        message: 'URL 形式が正しくありません。http:// または https:// で入力してください。',
      );
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: normalizedUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        sendTimeout: const Duration(seconds: 8),
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    try {
      final healthResponse = await dio.get('/health');
      if (_isSuccess(healthResponse.statusCode)) {
        return BackupServerConnectionResult(
          success: true,
          message: '接続成功: /health に応答がありました。',
        );
      }

      final rootResponse = await dio.get('/');
      if (_isSuccess(rootResponse.statusCode)) {
        return BackupServerConnectionResult(
          success: true,
          message: '接続成功: サーバーに応答がありました。',
        );
      }

      return BackupServerConnectionResult(
        success: false,
        message:
            '接続失敗: HTTP ${healthResponse.statusCode ?? rootResponse.statusCode ?? 'unknown'} が返されました。',
      );
    } on DioException catch (e) {
      return BackupServerConnectionResult(
        success: false,
        message: '接続失敗: ${_messageFromDioException(e)}',
      );
    } catch (e) {
      return BackupServerConnectionResult(success: false, message: '接続失敗: $e');
    }
  }

  bool _isSuccess(int? statusCode) {
    return statusCode != null && statusCode >= 200 && statusCode < 300;
  }

  String _messageFromDioException(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'タイムアウトしました。';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'サーバーに接続できませんでした。';
    }
    if (e.response?.statusCode != null) {
      return 'HTTP ${e.response!.statusCode}';
    }
    return e.message ?? '不明なエラーです。';
  }
}
