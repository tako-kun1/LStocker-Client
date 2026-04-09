import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlController;
  late Future<PackageInfo> _packageInfoFuture;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _urlController = TextEditingController(text: settings.serverUrl);
    _packageInfoFuture = PackageInfo.fromPlatform();
  }

  @override
  void dispose() {
    _urlController.dispose();
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
              const Text('サーバー設定', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'サーバーIPアドレス / URL',
                  border: OutlineInputBorder(),
                  hintText: 'http://192.168.1.100:8080',
                ),
                onSubmitted: (v) => settings.setServerUrl(v),
              ),
              const SizedBox(height: 24),
              const Text('通知設定', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SwitchListTile(
                title: const Text('プッシュ通知を有効にする'),
                value: settings.pushNotificationsEnabled,
                onChanged: (v) => settings.setPushNotificationsEnabled(v),
              ),
              const SizedBox(height: 24),
              const Text('同期設定', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              DropdownButtonFormField<String>(
                initialValue: settings.syncTiming,
                decoration: const InputDecoration(labelText: '同期タイミング'),
                items: ['Manual', 'On Startup', 'Every Hour', 'On Change'].map((t) {
                  return DropdownMenuItem(value: t, child: Text(t));
                }).toList(),
                onChanged: (v) => v != null ? settings.setSyncTiming(v) : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('手動同期を開始します... (機能未実装)')),
                  );
                },
                icon: const Icon(Icons.sync),
                label: const Text('今すぐサーバーと同期する'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
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
}
