import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/inventory_provider.dart';
import '../providers/product_provider.dart';
import '../providers/settings_provider.dart';
import '../services/offline_db_service.dart';
import '../services/sync_service.dart';
import '../services/version_check_service.dart';
import 'home_screen.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  final OfflineDbService _offlineDbService = OfflineDbService();
  final SyncService _syncService = SyncService();
  final VersionCheckService _versionCheckService = VersionCheckService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    final productProvider = context.read<ProductProvider>();
    final inventoryProvider = context.read<InventoryProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    if (!mounted) {
      return;
    }

    final shouldPrompt = await _offlineDbService.shouldPromptForExistingOfflineDb();

    if (!mounted) {
      return;
    }

    if (shouldPrompt) {
      final shouldLoad = await _showImportDialog();
      if (!mounted) {
        return;
      }

      if (!shouldLoad) {
        await _offlineDbService.archiveExistingOfflineDb();
      }

      await _offlineDbService.markFirstLaunchHandled();
    } else {
      await _offlineDbService.markFirstLaunchHandled();
    }

    if (!mounted) {
      return;
    }

    final updateResult = settingsProvider.autoCheckUpdateOnStartup
      ? await _versionCheckService.checkForUpdate()
      : await _versionCheckService.getCachedResult();

    if (!mounted) {
      return;
    }

    if (updateResult != null &&
        updateResult.updateAvailable &&
        updateResult.isRequired &&
        (updateResult.apkUrl?.isNotEmpty ?? false)) {
      await _showRequiredUpdateDialog(updateResult);
      return;
    }

    await Future.wait([
      productProvider.fetchProducts(),
      inventoryProvider.fetchInventories(),
    ]);

    _runStartupSyncInBackground(productProvider, inventoryProvider);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
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
            'Documents/LStocker に既存のオフラインDBが見つかりました。\n'
            'このデータをアプリ内DBとして読み込みますか？',
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
                final apkUrl = result.apkUrl;
                if (apkUrl == null || apkUrl.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('APK URLが見つかりません。リリース設定を確認してください。')),
                  );
                  return;
                }

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
