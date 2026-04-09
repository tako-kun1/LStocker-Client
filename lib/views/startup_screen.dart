import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/inventory_provider.dart';
import '../providers/product_provider.dart';
import '../services/offline_db_service.dart';
import 'home_screen.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  final OfflineDbService _offlineDbService = OfflineDbService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
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

    await context.read<ProductProvider>().fetchProducts();
    await context.read<InventoryProvider>().fetchInventories();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
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

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
