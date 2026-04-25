import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../providers/inventory_provider.dart';
import '../services/inventory_pdf_service.dart';
import '../services/inventory_print_service.dart';

class InventoryStatusScreen extends StatefulWidget {
  const InventoryStatusScreen({super.key});

  @override
  State<InventoryStatusScreen> createState() => _InventoryStatusScreenState();
}

class _InventoryStatusScreenState extends State<InventoryStatusScreen> {
  final _pdfService = InventoryPdfService();
  final _printService = InventoryPrintService();
  bool _exportingPdf = false;
  bool _printing = false;

  Future<void> _exportInventoryPdf() async {
    final provider = context.read<InventoryProvider>();
    final inventories = provider.inventoriesWithProduct;

    if (inventories.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('出力対象の在庫データがありません。')));
      return;
    }

    setState(() => _exportingPdf = true);
    try {
      final dataResult = await _pdfService.buildInventoryPdfBytes(inventories);
      if (!mounted) return;
      if (!dataResult.success || dataResult.bytes == null || dataResult.fileName == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(dataResult.message)));
        return;
      }

      final saveResult = await _pdfService.savePdfBytes(
        bytes: dataResult.bytes!,
        fileName: dataResult.fileName!,
      );
      if (!mounted) return;
      if (!saveResult.success || saveResult.filePath == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(saveResult.message)));
        return;
      }

      await OpenFilex.open(saveResult.filePath!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDFを保存しました: ${saveResult.filePath}')),
      );
    } finally {
      if (mounted) {
        setState(() => _exportingPdf = false);
      }
    }
  }

  Future<void> _printInventoryPdf() async {
    final provider = context.read<InventoryProvider>();
    final inventories = provider.inventoriesWithProduct;

    if (inventories.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('印刷対象の在庫データがありません。')));
      return;
    }

    setState(() => _printing = true);
    try {
      final dataResult = await _pdfService.buildInventoryPdfBytes(inventories);
      if (!mounted) return;
      if (!dataResult.success || dataResult.bytes == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(dataResult.message)));
        return;
      }

      final printResult = await _printService.printPdfBytes(
        pdfBytes: dataResult.bytes!,
        jobName: '在庫状況一覧',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(printResult.message)));
    } finally {
      if (mounted) {
        setState(() => _printing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy/MM/dd');

    return Scaffold(
      appBar: AppBar(
        title: const Text('在庫状況確認'),
        actions: [
          IconButton(
            tooltip: 'PDF出力',
            onPressed: (_exportingPdf || _printing) ? null : _exportInventoryPdf,
            icon: _exportingPdf
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf),
          ),
          IconButton(
            tooltip: '印刷',
            onPressed: (_exportingPdf || _printing) ? null : _printInventoryPdf,
            icon: _printing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print),
          ),
        ],
      ),
      body: Consumer<InventoryProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final inventoryData = provider.inventoriesWithProduct;

          if (inventoryData.isEmpty) {
            return Center(
              child: Text(
                '在庫がありません',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            itemCount: inventoryData.length,
            itemBuilder: (context, index) {
              final item = inventoryData[index];
              final registrationDate = DateTime.parse(item['registrationDate']);
              final expirationDate = DateTime.parse(item['expirationDate']);
              final salesPeriod = (item['salesPeriod'] as num?)?.toInt() ?? 0;
              final imagePath = (item['imagePath'] ?? '').toString();
              final itemName = (item['name'] ?? item['janCode'] ?? '未登録商品')
                  .toString();

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                color: expirationDate.isBefore(DateTime.now())
                    ? Colors.red.shade100
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (imagePath.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(imagePath),
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            const Icon(Icons.image_not_supported, size: 50),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  itemName,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text('登録日: ${df.format(registrationDate)}'),
                                Text('賞味期限: ${df.format(expirationDate)}'),
                                Text('数量: ${item['quantity']}'),
                                Text('販売許容期間: $salesPeriod日'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              provider.archiveInventory(item['id']),
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 18,
                          ),
                          label: const Text(
                            '完売/対応済み',
                            style: TextStyle(fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
