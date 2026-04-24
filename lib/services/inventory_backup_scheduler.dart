import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/settings_provider.dart';
import 'inventory_backup_service.dart';

class InventoryBackupScheduler with WidgetsBindingObserver {
  static const bool _isTemporarilyDisabled = true;
  static const String _disabledMessage =
      '現在、在庫バックアップは一時的に無効化されています。';
  static const String _lastBackupUploadedAtKey =
      'inventoryBackupLastUploadedAt';
  static const Duration _hourlyInterval = Duration(hours: 1);

  static final InventoryBackupScheduler _instance =
      InventoryBackupScheduler._internal();

  final InventoryBackupService _backupService = InventoryBackupService();
  SettingsProvider? _settingsProvider;
  Timer? _hourlyTimer;
  bool _isUploading = false;
  bool _observerAttached = false;

  factory InventoryBackupScheduler() {
    return _instance;
  }

  InventoryBackupScheduler._internal();

  void initialize(SettingsProvider settingsProvider) {
    if (!identical(_settingsProvider, settingsProvider)) {
      _settingsProvider?.removeListener(_handleSettingsChanged);
      _settingsProvider = settingsProvider;
      _settingsProvider?.addListener(_handleSettingsChanged);
    }

    if (!_observerAttached) {
      WidgetsBinding.instance.addObserver(this);
      _observerAttached = true;
    }

    _applySchedule();
  }

  Future<void> handleAppReady() async {
    if (_isTemporarilyDisabled) {
      return;
    }

    _applySchedule();

    final timing =
        _settingsProvider?.syncTiming ?? SettingsProvider.backupTimingManual;
    if (timing == SettingsProvider.backupTimingOnStartup) {
      await _runAutoBackup(reason: 'startup');
      return;
    }

    if (timing == SettingsProvider.backupTimingEveryHour) {
      await _runAutoBackupIfDue(reason: 'startup-hourly');
    }
  }

  Future<void> handleInventoryChanged() async {
    if (_isTemporarilyDisabled) {
      return;
    }

    final timing =
        _settingsProvider?.syncTiming ?? SettingsProvider.backupTimingManual;
    if (timing != SettingsProvider.backupTimingOnChange) {
      return;
    }
    await _runAutoBackup(reason: 'inventory-changed');
  }

  Future<InventoryBackupUploadResult> uploadNow({
    String reason = 'manual',
  }) async {
    if (_isTemporarilyDisabled) {
      return const InventoryBackupUploadResult(
        success: false,
        message: _disabledMessage,
        uploadedCount: 0,
      );
    }

    if (_isUploading) {
      return const InventoryBackupUploadResult(
        success: false,
        message: 'バックアップを実行中です。しばらく待ってから再試行してください。',
        uploadedCount: 0,
      );
    }

    _isUploading = true;
    try {
      final result = await _backupService.uploadCurrentInventoryBackup();
      if (result.success) {
        await _setLastUploadedAt(DateTime.now());
        debugPrint('[InventoryBackupScheduler] backup succeeded ($reason)');
      } else {
        debugPrint(
          '[InventoryBackupScheduler] backup failed ($reason): ${result.message}',
        );
      }
      return result;
    } finally {
      _isUploading = false;
    }
  }

  Future<DateTime?> getLastUploadedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastBackupUploadedAtKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isTemporarilyDisabled) {
      return;
    }

    if (state != AppLifecycleState.resumed) {
      return;
    }

    final timing =
        _settingsProvider?.syncTiming ?? SettingsProvider.backupTimingManual;
    if (timing == SettingsProvider.backupTimingEveryHour) {
      unawaited(_runAutoBackupIfDue(reason: 'resume-hourly'));
    }
  }

  void _handleSettingsChanged() {
    _applySchedule();
  }

  void _applySchedule() {
    _hourlyTimer?.cancel();
    _hourlyTimer = null;

    if (_isTemporarilyDisabled) {
      return;
    }

    final timing =
        _settingsProvider?.syncTiming ?? SettingsProvider.backupTimingManual;
    if (timing == SettingsProvider.backupTimingEveryHour) {
      _hourlyTimer = Timer.periodic(_hourlyInterval, (_) {
        unawaited(_runAutoBackupIfDue(reason: 'periodic-hourly'));
      });
    }
  }

  Future<void> _runAutoBackup({required String reason}) async {
    final result = await uploadNow(reason: reason);
    if (!result.success) {
      debugPrint(
        '[InventoryBackupScheduler] auto backup skipped/failed ($reason): ${result.message}',
      );
    }
  }

  Future<void> _runAutoBackupIfDue({required String reason}) async {
    final lastUploadedAt = await getLastUploadedAt();
    if (lastUploadedAt != null &&
        DateTime.now().difference(lastUploadedAt) < _hourlyInterval) {
      return;
    }
    await _runAutoBackup(reason: reason);
  }

  Future<void> _setLastUploadedAt(DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastBackupUploadedAtKey,
      timestamp.toIso8601String(),
    );
  }
}
