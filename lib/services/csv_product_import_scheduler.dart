import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'csv_product_import_service.dart';

class CsvProductImportScheduler with WidgetsBindingObserver {
  static const String _lastImportedAtKey = 'csvProductImportLastImportedAt';
  static const String _csvUrl = 'https://lsdb.nazono.cloud/db.csv';
  static const Duration _interval = Duration(days: 1);

  static final CsvProductImportScheduler _instance =
      CsvProductImportScheduler._internal();

  final CsvProductImportService _importService = CsvProductImportService();
  final ValueNotifier<bool> importingNotifier = ValueNotifier<bool>(false);
  Timer? _timer;
  bool _isImporting = false;
  bool _observerAttached = false;

  factory CsvProductImportScheduler() {
    return _instance;
  }

  CsvProductImportScheduler._internal();

  void initialize() {
    if (!_observerAttached) {
      WidgetsBinding.instance.addObserver(this);
      _observerAttached = true;
    }

    _applySchedule();
  }

  Future<void> handleAppReady() async {
    _applySchedule();
    await importNow(reason: 'startup');
  }

  Future<CsvProductImportResult> importNow({
    String reason = 'manual',
  }) async {
    if (_isImporting) {
      return const CsvProductImportResult(
        success: false,
        message: 'CSV取込を実行中です。しばらく待ってから再試行してください。',
        totalRows: 0,
        insertedCount: 0,
        skippedExistingCount: 0,
        skippedDuplicateCount: 0,
        invalidRowCount: 0,
      );
    }

    _isImporting = true;
    importingNotifier.value = true;
    try {
      final result = await _importService.importFromUrl(_csvUrl);
      if (result.success) {
        await _setLastImportedAt(DateTime.now());
        debugPrint('[CsvProductImportScheduler] import succeeded ($reason)');
      } else {
        debugPrint(
          '[CsvProductImportScheduler] import failed ($reason): ${result.message}',
        );
      }
      return result;
    } catch (e) {
      debugPrint('[CsvProductImportScheduler] import exception ($reason): $e');
      return CsvProductImportResult(
        success: false,
        message: 'CSV取込中にエラーが発生しました: $e',
        totalRows: 0,
        insertedCount: 0,
        skippedExistingCount: 0,
        skippedDuplicateCount: 0,
        invalidRowCount: 0,
      );
    } finally {
      _isImporting = false;
      importingNotifier.value = false;
    }
  }

  Future<DateTime?> getLastImportedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastImportedAtKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    unawaited(_runImportIfDue(reason: 'resume-daily'));
  }

  void _applySchedule() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) {
      unawaited(_runImportIfDue(reason: 'periodic'));
    });
  }

  Future<void> _runImportIfDue({required String reason}) async {
    final lastImportedAt = await getLastImportedAt();
    if (lastImportedAt != null &&
        DateTime.now().difference(lastImportedAt) < _interval) {
      return;
    }

    await importNow(reason: reason);
  }

  Future<void> _setLastImportedAt(DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastImportedAtKey, timestamp.toIso8601String());
  }
}
