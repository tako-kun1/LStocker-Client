import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/inventory_provider.dart';
import '../providers/product_provider.dart';
import '../providers/settings_provider.dart';
import '../services/app_config.dart';
import '../services/offline_db_service.dart';
import '../services/product_key_service.dart';
import '../services/sync_service.dart';
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
  final SyncService _syncService = SyncService();
  final VersionCheckService _versionCheckService = VersionCheckService();
  final ProductKeyService _productKeyService = ProductKeyService();

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

    // 起動体験を優先し、独立タスクは先に並列で開始する。
    final legacyPromptFuture = _offlineDbService
        .shouldPromptForLegacyImport()
        .timeout(const Duration(seconds: 2), onTimeout: () => false);
    final activatedFuture = _productKeyService.isActivated();
    final cachedUpdateResultFuture = _versionCheckService.getCachedResult();

    if (!mounted) {
      return;
    }

    final shouldPrompt = await legacyPromptFuture;
    debugPrint('[Startup] legacy check: ${sw.elapsedMilliseconds}ms');

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
      } else {
        await _offlineDbService.archiveLegacySourceDatabase();
      }

      await _offlineDbService.markLegacyImportHandled();
    }

    if (!mounted) {
      return;
    }

    final activated = await activatedFuture;
    if (!mounted) {
      return;
    }

    if (!activated) {
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
    } else {
      unawaited(
        Future<void>(() async {
          try {
            await _productKeyService.checkLicenseStatusIfDue();
          } catch (_) {}
        }),
      );
    }

    final cachedUpdateResult = await cachedUpdateResultFuture;
    if (settingsProvider.autoCheckUpdateOnStartup) {
      _runUpdateCheckInBackground();
    }

    if (!mounted) {
      return;
    }

    if (cachedUpdateResult != null &&
        cachedUpdateResult.updateAvailable &&
        cachedUpdateResult.isRequired) {
      await _showRequiredUpdateDialog(cachedUpdateResult);
        return;
    }

    await _loadInitialDataSafely(productProvider, inventoryProvider);
    debugPrint('[Startup] initial data loaded: ${sw.elapsedMilliseconds}ms');

    _runStartupSyncInBackground(productProvider, inventoryProvider);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
    debugPrint('[Startup] home displayed: ${sw.elapsedMilliseconds}ms');
  }

  void _runUpdateCheckInBackground() {
    unawaited(
      Future<void>(() async {
        try {
          await _versionCheckService.checkForUpdate();
        } catch (_) {
          // 起動体験を優先するため、更新確認失敗は無視。
        }
      }),
    );
  }

  Future<void> _loadInitialDataSafely(
    ProductProvider productProvider,
    InventoryProvider inventoryProvider,
  ) async {
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
  }

  void _runStartupSyncInBackground(
    ProductProvider productProvider,
    InventoryProvider inventoryProvider,
  ) {
    unawaited(
      Future<void>(() async {
        try {
          await _syncService.manualFullSync().timeout(const Duration(seconds: 8));
          await Future.wait([
            productProvider.fetchProducts(),
            inventoryProvider.fetchInventories(),
          ]);
        } catch (_) {
          // 起動体験を優先するため、同期失敗はここでは握りつぶす。
        }
      }),
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

  Future<void> _showRequiredUpdateDialog(VersionCheckResult result) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('アップデートが必要です'),
          content: Text(
            '現在のバージョン: ${result.currentVersion}\n'
            '最新バージョン: ${result.latestVersion}\n\n'
            'アプリを利用するには更新が必要です。',
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
                final apkUrl = result.apkUrl ?? AppConfig.githubReleasesPageUrl;

                final uri = Uri.tryParse(apkUrl);
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
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
