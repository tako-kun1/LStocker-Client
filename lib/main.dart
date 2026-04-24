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
import 'services/csv_product_import_scheduler.dart';
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
  CsvProductImportScheduler().initialize();

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
    const brandColor = Color(0xFF0B5FA5);
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandColor,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF7FAFC),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF7FAFC),
        foregroundColor: Color(0xFF0B5FA5),
        surfaceTintColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        color: Colors.white,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blueGrey.shade100),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blueGrey.shade100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandColor, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: brandColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.blueGrey.shade200),
          foregroundColor: const Color(0xFF1C4E80),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: brandColor,
        foregroundColor: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.blueGrey.shade900,
        contentTextStyle: const TextStyle(color: Colors.white),
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
