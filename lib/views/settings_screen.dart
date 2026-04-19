import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/app_config.dart';
import '../services/backup_server_service.dart';
import '../services/product_key_service.dart';
import '../services/sync_service.dart';
import '../services/version_check_service.dart';
import 'license_activation_screen.dart';
import 'sync_conflict_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _backupUrlController;
  late Future<PackageInfo> _packageInfoFuture;
  bool _syncing = false;
  bool _checkingUpdate = false;
  bool _checkingLicense = false;
  bool _checkingBackupServer = false;
  DateTime? _lastUpdateCheckedAt;
  String? _backupServerCheckMessage;
  bool? _backupServerCheckSucceeded;
  final _syncService = SyncService();
  final _backupServerService = BackupServerService();
  final _versionCheckService = VersionCheckService();
  final _productKeyService = ProductKeyService();

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _backupUrlController = TextEditingController(
      text: settings.backupServerUrl,
    );
    _packageInfoFuture = PackageInfo.fromPlatform();
    _loadLastCheckedAt();
  }

  Future<void> _loadLastCheckedAt() async {
    final checkedAt = await _versionCheckService.getLastCheckedAt();
    if (!mounted) return;
    setState(() {
      _lastUpdateCheckedAt = checkedAt;
    });
  }

  Future<void> _checkBackupServerConnection(SettingsProvider settings) async {
    final url = _backupUrlController.text.trim();
    await settings.setBackupServerUrl(url);

    setState(() {
      _checkingBackupServer = true;
      _backupServerCheckMessage = null;
      _backupServerCheckSucceeded = null;
    });

    try {
      final result = await _backupServerService.testConnection(url);
      if (!mounted) return;
      setState(() {
        _backupServerCheckMessage = result.message;
        _backupServerCheckSucceeded = result.success;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } finally {
      if (mounted) {
        setState(() {
          _checkingBackupServer = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _backupUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSection(
                context,
                title: 'バックアップサーバー設定',
                icon: Icons.cloud_upload_outlined,
                children: [
                  TextField(
                    controller: _backupUrlController,
                    decoration: const InputDecoration(
                      labelText: 'バックアップサーバー URL',
                      border: OutlineInputBorder(),
                      hintText: 'http://192.168.1.100:8080',
                    ),
                    keyboardType: TextInputType.visiblePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    onSubmitted: (v) => settings.setBackupServerUrl(v),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _checkingBackupServer
                        ? null
                        : () => _checkBackupServerConnection(settings),
                    icon: _checkingBackupServer
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_find),
                    label: Text(_checkingBackupServer ? '確認中...' : '接続確認'),
                  ),
                  if (_backupServerCheckMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _backupServerCheckMessage!,
                      style: TextStyle(
                        color: (_backupServerCheckSucceeded ?? false)
                            ? Colors.green.shade700
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '商品DBと在庫情報のバックアップ接続先として保存されます。'
                    '業務APIの同期先変更には使用しません。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              _buildSection(
                context,
                title: '通知設定',
                icon: Icons.notifications_none,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('プッシュ通知を有効にする'),
                    value: settings.pushNotificationsEnabled,
                    onChanged: (v) => settings.setPushNotificationsEnabled(v),
                  ),
                ],
              ),
              if (AppConfig.enableProductKeyAuth) ...[
                _buildSection(
                  context,
                  title: 'ライセンス設定',
                  icon: Icons.verified_user_outlined,
                  children: [
                    FutureBuilder<String>(
                      future: _productKeyService.getMaskedProductKey(),
                      builder: (context, snapshot) {
                        final masked = snapshot.data ?? '読み込み中...';
                        return Text('登録キー: $masked');
                      },
                    ),
                    const SizedBox(height: 4),
                    FutureBuilder<String>(
                      future: _productKeyService.getLicenseSummary(),
                      builder: (context, snapshot) {
                        final summary =
                            snapshot.data ?? 'status=unknown / mode=unknown';
                        return Text('ライセンス状態: $summary');
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => const LicenseActivationScreen(),
                          ),
                        );
                        if (!mounted) return;
                        if (result == true) {
                          setState(() {});
                        }
                      },
                      icon: const Icon(Icons.verified_user),
                      label: const Text('プロダクトキーを再登録する'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _checkingLicense
                          ? null
                          : () async {
                              setState(() => _checkingLicense = true);
                              try {
                                final result = await _productKeyService
                                    .checkLicenseStatus();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(result.message)),
                                );
                                setState(() {});
                              } finally {
                                if (mounted) {
                                  setState(() => _checkingLicense = false);
                                }
                              }
                            },
                      icon: _checkingLicense
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_done),
                      label: Text(_checkingLicense ? '確認中...' : 'ライセンス状態を確認する'),
                    ),
                  ],
                ),
              ],
              _buildSection(
                context,
                title: 'アップデート設定',
                icon: Icons.system_update_alt_outlined,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('起動時にアップデートを自動確認する'),
                    value: settings.autoCheckUpdateOnStartup,
                    onChanged: (v) => settings.setAutoCheckUpdateOnStartup(v),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _lastUpdateCheckedAt == null
                          ? '最終確認: 未実施'
                          : '最終確認: ${_lastUpdateCheckedAt!.toLocal().toString().substring(0, 19)}',
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _checkingUpdate
                        ? null
                        : () async {
                            setState(() => _checkingUpdate = true);
                            try {
                              final result = await _versionCheckService
                                  .checkForUpdate(force: true);
                              if (!context.mounted) return;

                              if (result.updateAvailable) {
                                final min =
                                    (result.minSupportedVersion == null ||
                                        result.minSupportedVersion!.isEmpty)
                                    ? ''
                                    : '\n最小対応: ${result.minSupportedVersion}';
                                showDialog<void>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('アップデートがあります'),
                                    content: Text(
                                      '現在: ${result.currentVersion}\n最新: ${result.latestVersion}$min',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext),
                                        child: const Text('閉じる'),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('最新版です。')),
                                );
                              }
                            } finally {
                              await _loadLastCheckedAt();
                              if (mounted) {
                                setState(() => _checkingUpdate = false);
                              }
                            }
                          },
                    icon: _checkingUpdate
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.system_update),
                    label: Text(_checkingUpdate ? '確認中...' : 'アップデートを確認する'),
                  ),
                ],
              ),
              _buildSection(
                context,
                title: '同期設定',
                icon: Icons.sync_outlined,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: settings.syncTiming,
                    decoration: const InputDecoration(labelText: '同期タイミング'),
                    items: ['Manual', 'On Startup', 'Every Hour', 'On Change']
                        .map((t) {
                          return DropdownMenuItem(value: t, child: Text(t));
                        })
                        .toList(),
                    onChanged: (v) =>
                        v != null ? settings.setSyncTiming(v) : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _syncing
                        ? null
                        : () async {
                            setState(() => _syncing = true);
                            try {
                              final result = await _syncService
                                  .manualFullSync();
                              if (!context.mounted) return;
                              final message = result.success
                                  ? '同期完了: push ${result.totalApplied}件 / pull ${result.totalReceived}件'
                                  : '同期失敗: ${result.productsResult.error ?? result.inventoriesResult.error ?? 'unknown error'}';
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(message)));
                            } finally {
                              if (mounted) {
                                setState(() => _syncing = false);
                              }
                            }
                          },
                    icon: _syncing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: Text(_syncing ? '同期中...' : '今すぐサーバーと同期する'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SyncConflictScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.warning_amber_rounded),
                    label: const Text('同期競合を解決する'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              FutureBuilder<PackageInfo>(
                future: _packageInfoFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final info = snapshot.data!;
                  return Center(
                    child: Text(
                      'バージョン ${info.version} (${info.buildNumber})',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
