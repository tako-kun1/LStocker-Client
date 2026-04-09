import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/sync_service.dart';

class SyncConflictScreen extends StatefulWidget {
  const SyncConflictScreen({super.key});

  @override
  State<SyncConflictScreen> createState() => _SyncConflictScreenState();
}

class _SyncConflictScreenState extends State<SyncConflictScreen> {
  final _syncService = SyncService();
  bool _loading = false;
  List<SyncConflictItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _syncService.getConflicts();
      if (!mounted) return;
      setState(() => _items = items);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resolveServerWins(int queueId) async {
    await _syncService.resolveConflictServerWins(queueId);
    await _load();
  }

  Future<void> _resolveClientWins(int queueId) async {
    await _syncService.resolveConflictClientWins(queueId);
    final result = await _syncService.manualFullSync();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? '再送が完了しました'
              : '再送に失敗しました: ${result.productsResult.error ?? result.inventoriesResult.error ?? 'unknown'}',
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('同期競合の解決')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('未解決の競合はありません'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final payloadPretty = _prettyJson(item.payload);
                    final conflictPretty = _prettyJson(item.conflictPayload);
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.entityType} / ${item.entityId} / ${item.operation}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            if ((item.lastError ?? '').isNotEmpty)
                              Text(
                                'Error: ${item.lastError}',
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            const SizedBox(height: 6),
                            SelectableText('Local payload: $payloadPretty'),
                            const SizedBox(height: 6),
                            if (conflictPretty.isNotEmpty)
                              SelectableText('Conflict: $conflictPretty'),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _resolveServerWins(item.queueId),
                                    child: const Text('serverWins'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _resolveClientWins(item.queueId),
                                    child: const Text('clientWins で再送'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  String _prettyJson(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final decoded = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return raw;
    }
  }
}
