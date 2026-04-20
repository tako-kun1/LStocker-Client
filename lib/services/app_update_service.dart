import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_config.dart';
import 'version_check_service.dart';

typedef AppUpdateProgressCallback =
    void Function(String message, double? progress);

class AppUpdateInstallResult {
  final bool started;
  final bool fallbackOpened;
  final String message;

  const AppUpdateInstallResult({
    required this.started,
    required this.fallbackOpened,
    required this.message,
  });
}

class AppUpdateService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 0),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  Future<AppUpdateInstallResult> installUpdate(
    VersionCheckResult result, {
    bool allowFallbackToReleasePage = true,
    AppUpdateProgressCallback? onProgress,
  }) async {
    if (!result.updateAvailable) {
      _emitProgress(onProgress, 'アップデートはありません。', null);
      return const AppUpdateInstallResult(
        started: false,
        fallbackOpened: false,
        message: 'アップデートはありません。',
      );
    }

    if (!Platform.isAndroid) {
      _emitProgress(onProgress, 'このプラットフォームでは自動更新できません。', null);
      return _openReleasePageFallback(
        message: 'このプラットフォームでは自動インストールに未対応のため、更新ページを開きます。',
        allowFallbackToReleasePage: allowFallbackToReleasePage,
        releasePageUrl: result.releasePageUrl,
      );
    }

    final apkUrl = result.apkUrl;
    if (apkUrl == null || apkUrl.isEmpty) {
      _emitProgress(onProgress, 'APK 取得先が見つかりません。', null);
      return _openReleasePageFallback(
        message: 'APK の取得先が見つからないため、更新ページを開きます。',
        allowFallbackToReleasePage: allowFallbackToReleasePage,
        releasePageUrl: result.releasePageUrl,
      );
    }

    try {
      _emitProgress(onProgress, 'アップデートをダウンロードしています...', 0);
      final apkPath = await _downloadApk(
        apkUrl: apkUrl,
        version: result.latestVersion,
        onProgress: onProgress,
      );

      _emitProgress(onProgress, 'インストーラーを起動しています...', 1);
      final openResult = await OpenFilex.open(
        apkPath,
        type: 'application/vnd.android.package-archive',
      );

      if (openResult.type == ResultType.done) {
        _emitProgress(onProgress, 'インストーラーを起動しました。', 1);
        return const AppUpdateInstallResult(
          started: true,
          fallbackOpened: false,
          message: 'アップデートを検出しました。インストーラーを起動します。',
        );
      }

      _emitProgress(onProgress, '更新ページへ切り替えます。', null);
      return _openReleasePageFallback(
        message: 'インストーラーを起動できなかったため、更新ページを開きます。',
        allowFallbackToReleasePage: allowFallbackToReleasePage,
        releasePageUrl: result.releasePageUrl,
      );
    } on DioException catch (e) {
      _emitProgress(onProgress, 'APK のダウンロードに失敗しました。', null);
      return _openReleasePageFallback(
        message: 'APK のダウンロードに失敗しました: ${_messageFromDioException(e)}',
        allowFallbackToReleasePage: allowFallbackToReleasePage,
        releasePageUrl: result.releasePageUrl,
      );
    } catch (e) {
      _emitProgress(onProgress, '自動更新を開始できませんでした。', null);
      return _openReleasePageFallback(
        message: '自動更新を開始できませんでした: $e',
        allowFallbackToReleasePage: allowFallbackToReleasePage,
        releasePageUrl: result.releasePageUrl,
      );
    }
  }

  Future<String> _downloadApk({
    required String apkUrl,
    required String version,
    AppUpdateProgressCallback? onProgress,
  }) async {
    final supportDir = await getApplicationSupportDirectory();
    final updateDir = Directory(path.join(supportDir.path, 'updates'));
    await updateDir.create(recursive: true);

    final apkPath = path.join(updateDir.path, 'lstocker-$version.apk');
    await _dio.download(
      apkUrl,
      apkPath,
      deleteOnError: true,
      onReceiveProgress: (received, total) {
        if (total <= 0) {
          _emitProgress(onProgress, 'アップデートをダウンロードしています...', null);
          return;
        }

        final progress = received / total;
        final percent = (progress * 100).clamp(0, 100).toStringAsFixed(0);
        _emitProgress(onProgress, 'アップデートをダウンロードしています... $percent%', progress);
      },
    );
    return apkPath;
  }

  Future<AppUpdateInstallResult> _openReleasePageFallback({
    required String message,
    required bool allowFallbackToReleasePage,
    String? releasePageUrl,
  }) async {
    if (!allowFallbackToReleasePage) {
      return AppUpdateInstallResult(
        started: false,
        fallbackOpened: false,
        message: message,
      );
    }

    final uri = Uri.tryParse(
      releasePageUrl ?? AppConfig.effectiveUpdateFallbackPageUrl,
    );
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return AppUpdateInstallResult(
        started: false,
        fallbackOpened: true,
        message: message,
      );
    }

    return AppUpdateInstallResult(
      started: false,
      fallbackOpened: false,
      message: message,
    );
  }

  String _messageFromDioException(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'タイムアウトしました。';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'ネットワークへ接続できませんでした。';
    }
    if (e.response?.statusCode != null) {
      return 'HTTP ${e.response!.statusCode}';
    }
    return e.message ?? '不明なエラーです。';
  }

  void _emitProgress(
    AppUpdateProgressCallback? onProgress,
    String message,
    double? progress,
  ) {
    onProgress?.call(message, progress);
  }
}
