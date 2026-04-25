import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/product_provider.dart';
import '../providers/settings_provider.dart';
import '../services/app_config.dart';
import '../services/app_update_service.dart';
import '../services/backup_server_service.dart';
import '../services/csv_product_import_scheduler.dart';
import '../services/inventory_backup_scheduler.dart';
import '../services/product_key_service.dart';
import '../services/support_contact.dart';
import '../services/version_check_service.dart';
import 'license_activation_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const bool _inventoryBackupTemporarilyDisabled = true;
  late TextEditingController _backupUrlController;
  late Future<PackageInfo> _packageInfoFuture;
  bool _checkingUpdate = false;
  bool _checkingLicense = false;
  bool _checkingBackupServer = false;
  bool _uploadingBackup = false;
  bool _importingCsv = false;
  DateTime? _lastUpdateCheckedAt;
  DateTime? _lastBackupUploadedAt;
  DateTime? _lastCsvImportedAt;
  String? _backupServerCheckMessage;
  bool? _backupServerCheckSucceeded;
  String? _csvImportMessage;
  bool? _csvImportSucceeded;
  String? _updateProgressMessage;
  double? _updateProgressValue;
  final _appUpdateService = AppUpdateService();
  final _backupServerService = BackupServerService();
  final _csvImportScheduler = CsvProductImportScheduler();
  final _inventoryBackupScheduler = InventoryBackupScheduler();
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
    _loadLastBackupUploadedAt();
    _loadLastCsvImportedAt();
  }

  Future<void> _loadLastCheckedAt() async {
    final checkedAt = await _versionCheckService.getLastCheckedAt();
    if (!mounted) return;
    setState(() {
      _lastUpdateCheckedAt = checkedAt;
    });
  }

  Future<void> _loadLastBackupUploadedAt() async {
    final uploadedAt = await _inventoryBackupScheduler.getLastUploadedAt();
    if (!mounted) return;
    setState(() {
      _lastBackupUploadedAt = uploadedAt;
    });
  }

  Future<void> _loadLastCsvImportedAt() async {
    final importedAt = await _csvImportScheduler.getLastImportedAt();
    if (!mounted) return;
    setState(() {
      _lastCsvImportedAt = importedAt;
    });
  }

  Future<void> _runCsvImport() async {
    final productProvider = context.read<ProductProvider>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _importingCsv = true;
      _csvImportMessage = null;
      _csvImportSucceeded = null;
    });

    final result = await _csvImportScheduler.importNow(
      reason: 'manual',
    );
    if (!mounted) return;

    setState(() {
      _csvImportMessage = result.message;
      _csvImportSucceeded = result.success;
    });

    if (result.success && result.insertedCount > 0) {
      await productProvider.fetchProducts();
      await _loadLastCsvImportedAt();
    }

    messenger.showSnackBar(SnackBar(content: Text(result.message)));

    if (mounted) {
      setState(() {
        _importingCsv = false;
      });
    }
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

  void _handleUpdateProgress(String message, double? progress) {
    if (!mounted) {
      return;
    }
    setState(() {
      _updateProgressMessage = message;
      _updateProgressValue = progress;
    });
  }

  Future<void> _openSupportContact() async {
    if (!SupportContact.hasUrl) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('お問い合わせ先URLが未設定です。')),
      );
      return;
    }

    final uri = Uri.tryParse(SupportContact.effectiveUrl);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('お問い合わせ先URLの形式が不正です。')),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('お問い合わせ先を開けませんでした。')),
    );
  }

  @override
  void dispose() {
    _backupUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supportName = SupportContact.effectiveName;
    final supportEmail = SupportContact.effectiveEmail;
    final supportPhone = SupportContact.effectivePhone;
    final supportUrl = SupportContact.effectiveUrl;

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
                    'バックアップ同期設定と手動同期はこの接続先を使用します。',
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
              _buildSection(
                context,
                title: 'バーコード読取設定',
                icon: Icons.qr_code_scanner,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: settings.barcodeScanMethod,
                    decoration: const InputDecoration(
                      labelText: '読取方式',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: SettingsProvider.barcodeScanMethodCamera,
                        child: Text('カメラ読取'),
                      ),
                      DropdownMenuItem(
                        value: SettingsProvider.barcodeScanMethodDeviceReader,
                        child: Text('端末スキャナ読取 (Zebra EMDK)'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        settings.setBarcodeScanMethod(value);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    settings.barcodeScanMethod ==
                            SettingsProvider.barcodeScanMethodDeviceReader
                        ? 'Zebra端末のスキャナユニットを直接使用します。'
                        : '端末カメラを使ってバーコードを読み取ります。',
                    style: Theme.of(context).textTheme.bodySmall,
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
                              setState(() {
                                _updateProgressMessage = null;
                                _updateProgressValue = null;
                              });
                              final result = await _versionCheckService
                                  .checkForUpdate(force: true);
                              if (!context.mounted) return;

                              if (result.updateAvailable) {
                                final installResult = await _appUpdateService
                                    .installUpdate(
                                      result,
                                      onProgress: _handleUpdateProgress,
                                    );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(installResult.message),
                                  ),
                                );
                              } else {
                                setState(() {
                                  _updateProgressMessage = null;
                                  _updateProgressValue = null;
                                });
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
                  if (_updateProgressMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(_updateProgressMessage!),
                  ],
                  if (_updateProgressValue != null) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: _updateProgressValue),
                  ],
                ],
              ),
              _buildSection(
                context,
                title: 'CSV商品取込設定',
                icon: Icons.file_download_outlined,
                children: [
                  Text('取込元: https://lsdb.nazono.cloud/db.csv'),
                  const SizedBox(height: 4),
                  Text('実行間隔: 1日ごと（起動時に1回実行）'),
                  const SizedBox(height: 8),
                  Text(
                    _lastCsvImportedAt == null
                        ? '最終CSV取込: 未実施'
                        : '最終CSV取込: ${_lastCsvImportedAt!.toLocal().toString().substring(0, 19)}',
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _importingCsv
                        ? null
                        : () => _runCsvImport(),
                    icon: _importingCsv
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(_importingCsv ? '取込中...' : '今すぐCSV商品取込を実行する'),
                  ),
                  if (_csvImportMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _csvImportMessage!,
                      style: TextStyle(
                        color: (_csvImportSucceeded ?? false)
                            ? Colors.green.shade700
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
              _buildSection(
                context,
                title: '在庫バックアップ設定',
                icon: Icons.cloud_upload_outlined,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: settings.syncTiming,
                    decoration: const InputDecoration(
                      labelText: 'バックアップ実行タイミング',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: SettingsProvider.backupTimingManual,
                        child: Text('手動のみ'),
                      ),
                      DropdownMenuItem(
                        value: SettingsProvider.backupTimingOnStartup,
                        child: Text('起動時'),
                      ),
                      DropdownMenuItem(
                        value: SettingsProvider.backupTimingEveryHour,
                        child: Text('1時間ごと'),
                      ),
                      DropdownMenuItem(
                        value: SettingsProvider.backupTimingOnChange,
                        child: Text('在庫更新時'),
                      ),
                    ],
                    onChanged: _inventoryBackupTemporarilyDisabled
                        ? null
                        : (value) {
                      if (value != null) {
                        settings.setSyncTiming(value);
                      }
                    },
                  ),
                  if (_inventoryBackupTemporarilyDisabled) ...[
                    const SizedBox(height: 8),
                    Text(
                      '現在、在庫バックアップは一時的に無効化されています。',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    _lastBackupUploadedAt == null
                        ? '最終バックアップ: 未実施'
                        : '最終バックアップ: ${_lastBackupUploadedAt!.toLocal().toString().substring(0, 19)}',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'バックアップ対象は在庫状況データのみです。\n'
                    '最新バックアップのダウンロードは、プロダクトキー認証成功時に自動で実行されます。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _inventoryBackupTemporarilyDisabled
                        ? null
                        : _uploadingBackup
                        ? null
                        : () async {
                            setState(() => _uploadingBackup = true);
                            try {
                              final result = await _inventoryBackupScheduler
                                  .uploadNow();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(result.message)),
                              );
                              await _loadLastBackupUploadedAt();
                            } finally {
                              if (mounted) {
                                setState(() => _uploadingBackup = false);
                              }
                            }
                          },
                    icon: _uploadingBackup
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload),
                    label: Text(
                      _inventoryBackupTemporarilyDisabled
                          ? '在庫バックアップは一時停止中'
                          : _uploadingBackup
                          ? 'バックアップ送信中...'
                          : '今すぐ在庫バックアップを保存する',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '選択したタイミングで自動保存できます。手動保存もいつでも実行できます。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              if (SupportContact.hasAny)
                _buildSection(
                  context,
                  title: 'お問い合わせ',
                  icon: Icons.support_agent,
                  children: [
                    if (SupportContact.hasName)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('お問い合わせ先名'),
                        subtitle: Text(supportName),
                      ),
                    if (SupportContact.hasEmail)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.mail_outline),
                        title: const Text('メールアドレス'),
                        subtitle: Text(supportEmail),
                      ),
                    if (SupportContact.hasPhone)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.phone_outlined),
                        title: const Text('電話番号'),
                        subtitle: Text(supportPhone),
                      ),
                    if (SupportContact.hasUrl)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.open_in_new),
                        title: const Text('お問い合わせ先を開く'),
                        subtitle: Text(supportUrl),
                        onTap: _openSupportContact,
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
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
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
