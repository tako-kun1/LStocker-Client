import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';

class InventoryStatusScreen extends StatefulWidget {
  const InventoryStatusScreen({super.key});

  @override
  State<InventoryStatusScreen> createState() => _InventoryStatusScreenState();
}

class _InventoryStatusScreenState extends State<InventoryStatusScreen> {
  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy/MM/dd');

    return Scaffold(
      appBar: AppBar(title: const Text('在庫状況確認')),
      body: Consumer<InventoryProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final inventoryData = provider.inventoriesWithProduct;

          if (inventoryData.isEmpty) {
            return const Center(child: Text('在庫がありません'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
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
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: expirationDate.isBefore(DateTime.now())
                    ? Colors.red.shade100
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(8),
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
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
