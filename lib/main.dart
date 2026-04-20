import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/product_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/settings_provider.dart';
import 'services/dept_service.dart';
import 'services/api_client.dart';
import 'services/app_config.dart';
import 'services/inventory_backup_scheduler.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';
import 'views/startup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sw = Stopwatch()..start();
  final settingsProvider = SettingsProvider();
  final syncService = SyncService();

  await Future.wait([
    DeptService.loadDepts(),
    settingsProvider.loadSettings(),
    syncService.initialize(),
  ]);
  await NotificationService().initialize(
    requestPermissions: settingsProvider.pushNotificationsEnabled,
  );
  debugPrint('[Main] bootstrap completed in ${sw.elapsedMilliseconds}ms');

  // API クライアント初期化
  final apiClient = ApiClient();
  final baseUrl = settingsProvider.backupServerUrl.isNotEmpty
      ? settingsProvider.backupServerUrl
      : AppConfig.defaultBaseUrl;
  if (baseUrl.isNotEmpty) {
    await apiClient.initialize(baseUrl);
    debugPrint('[Main] api client initialized for $baseUrl');
  }

  InventoryBackupScheduler().initialize(settingsProvider);

  unawaited(DeptService.loadDepts());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => settingsProvider),
      ],
      child: const LStockerApp(),
    ),
  );
}

class LStockerApp extends StatelessWidget {
  const LStockerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0E66AA),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF0E66AA),
        surfaceTintColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    return MaterialApp(
      title: 'LStocker',
      theme: baseTheme.copyWith(
        textTheme: GoogleFonts.notoSansJpTextTheme(baseTheme.textTheme),
        primaryTextTheme: GoogleFonts.notoSansJpTextTheme(
          baseTheme.primaryTextTheme,
        ),
      ),
      home: const StartupScreen(),
    );
  }
}
