import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/inventory_provider.dart';
import '../providers/product_provider.dart';
import '../providers/settings_provider.dart';
import '../services/app_config.dart';
import '../services/app_update_service.dart';
import '../services/csv_product_import_scheduler.dart';
import '../services/inventory_backup_scheduler.dart';
import '../services/offline_db_service.dart';
import '../services/product_key_service.dart';
import '../services/startup_permission_service.dart';
import '../services/version_check_service.dart';
import 'home_screen.dart';
import 'license_activation_screen.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  final OfflineDbService _offlineDbService = OfflineDbService();
  final VersionCheckService _versionCheckService = VersionCheckService();
  final AppUpdateService _appUpdateService = AppUpdateService();
  final ProductKeyService _productKeyService = ProductKeyService();
  final StartupPermissionService _startupPermissionService =
      StartupPermissionService();
  String? _updateProgressMessage;
  double? _updateProgressValue;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    final sw = Stopwatch()..start();
    final productProvider = context.read<ProductProvider>();
    final inventoryProvider = context.read<InventoryProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    debugPrint('[Startup] initialize started');

    try {
      await _startupPermissionService.requestPermissionsIfFirstLaunchOfVersion();
    } catch (e) {
      debugPrint('[Startup] startup permission request failed: $e');
    }

    // 起動体験を優先し、独立タスクは先に並列で開始する。
    final legacyPromptFuture = _offlineDbService
        .shouldPromptForLegacyImport()
        .timeout(const Duration(seconds: 2), onTimeout: () => false);
    final activatedFuture = AppConfig.enableProductKeyAuth
        ? _productKeyService.isActivated()
        : Future<bool>.value(true);
    final cachedUpdateResultFuture = _versionCheckService.getCachedResult();

    if (!mounted) {
      return;
    }

    final shouldPrompt = await legacyPromptFuture;
    debugPrint(
      '[Startup] legacy check finished in ${sw.elapsedMilliseconds}ms; shouldPrompt=$shouldPrompt',
    );

    if (!mounted) {
      return;
    }

    if (shouldPrompt) {
      final shouldLoad = await _showImportDialog();
      if (!mounted) {
        return;
      }

      if (shouldLoad) {
        await _offlineDbService.importLegacyDatabaseToActive();
        debugPrint('[Startup] legacy import completed');
      } else {
        await _offlineDbService.archiveLegacySourceDatabase();
        debugPrint('[Startup] legacy database archived by user choice');
      }

      await _offlineDbService.markLegacyImportHandled();
    }

    if (!mounted) {
      return;
    }

    final activated = await activatedFuture;
    debugPrint(
      '[Startup] activation state resolved in ${sw.elapsedMilliseconds}ms; activated=$activated',
    );
    if (!mounted) {
      return;
    }

    if (AppConfig.enableProductKeyAuth && !activated) {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const LicenseActivationScreen()),
      );
      if (!mounted) {
        return;
      }
      if (result != true) {
        await SystemNavigator.pop();
        return;
      }
    } else if (AppConfig.enableProductKeyAuth) {
      unawaited(
        Future<void>(() async {
          try {
            await _productKeyService.checkLicenseStatusIfDue();
          } catch (_) {}
        }),
      );
    }

    final cachedUpdateResult = await cachedUpdateResultFuture;
    debugPrint(
      '[Startup] cached update check resolved in ${sw.elapsedMilliseconds}ms',
    );
    if (settingsProvider.autoCheckUpdateOnStartup &&
        (cachedUpdateResult == null || !cachedUpdateResult.updateAvailable)) {
      _runUpdateCheckInBackground();
    }

    if (!mounted) {
      return;
    }

    if (cachedUpdateResult != null && cachedUpdateResult.updateAvailable) {
      final installResult = await _appUpdateService.installUpdate(
        cachedUpdateResult,
        onProgress: _handleUpdateProgress,
      );
      if (cachedUpdateResult.isRequired && installResult.started) {
        return;
      }
      if (cachedUpdateResult.isRequired && !installResult.started) {
        await _showRequiredUpdateDialog(
          cachedUpdateResult,
          installResult.message,
        );
        return;
      }
    }

    await _loadInitialDataSafely(productProvider, inventoryProvider);
    debugPrint(
      '[Startup] initial data loaded in ${sw.elapsedMilliseconds}ms; products=${productProvider.products.length} inventories=${inventoryProvider.inventories.length}',
    );

    unawaited(InventoryBackupScheduler().handleAppReady());
    unawaited(CsvProductImportScheduler().handleAppReady());

    if (!mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    debugPrint('[Startup] home displayed: ${sw.elapsedMilliseconds}ms');
  }

  void _runUpdateCheckInBackground() {
    unawaited(
      Future<void>(() async {
        try {
          final result = await _versionCheckService.checkForUpdate();
          if (!result.updateAvailable) {
            return;
          }
          await _appUpdateService.installUpdate(
            result,
            onProgress: _handleUpdateProgress,
          );
        } catch (_) {
          // 起動体験を優先するため、更新確認失敗は無視。
        }
      }),
    );
  }

  void _handleUpdateProgress(String message, double? progress) {
    if (!mounted) {
      return;
    }
    setState(() {
      _updateProgressMessage = message;
      _updateProgressValue = progress;
    });
  }

  Future<void> _loadInitialDataSafely(
    ProductProvider productProvider,
    InventoryProvider inventoryProvider,
  ) async {
    final sw = Stopwatch()..start();
    await Future.wait([
      productProvider
          .fetchProducts()
          .timeout(const Duration(seconds: 2), onTimeout: () {})
          .catchError((_) {}),
      inventoryProvider
          .fetchInventories()
          .timeout(const Duration(seconds: 2), onTimeout: () {})
          .catchError((_) {}),
    ]);
    debugPrint(
      '[Startup] _loadInitialDataSafely finished in ${sw.elapsedMilliseconds}ms',
    );
  }

  Future<bool> _showImportDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('オフラインデータを検出しました'),
          content: const Text(
            '旧バージョンのローカルDBが見つかりました。\n'
            '現在の保存先へデータを移行して読み込みますか？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('読み込まない'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('読み込む'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _showRequiredUpdateDialog(
    VersionCheckResult result,
    String failureMessage,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('アップデートが必要です'),
          content: Text(
            '現在のバージョン: ${result.currentVersion}\n'
            '最新バージョン: ${result.latestVersion}\n\n'
            '自動更新を開始できませんでした。\n'
            '$failureMessage',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await SystemNavigator.pop();
              },
              child: const Text('終了'),
            ),
            ElevatedButton(
              onPressed: () async {
                final uri = Uri.tryParse(
                  result.releasePageUrl ??
                      result.apkUrl ??
                      AppConfig.effectiveUpdateFallbackPageUrl,
                );
                if (uri == null) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('APK URLの形式が不正です。')),
                  );
                  return;
                }

                await launchUrl(uri, mode: LaunchMode.externalApplication);
                await SystemNavigator.pop();
              },
              child: const Text('更新ページを開く'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(_updateProgressMessage ?? '起動準備中...'),
              if (_updateProgressValue != null) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: _updateProgressValue),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
