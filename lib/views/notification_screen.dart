import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import 'inventory_status_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy/MM/dd');

    return Scaffold(
      appBar: AppBar(title: const Text('通知')),
      body: Consumer<InventoryProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = provider.getNearExpirationInventories();

          if (notifications.isEmpty) {
            return Center(
              child: Text(
                '現在通知はありません',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final item = notifications[index];
              final expirationDate = DateTime.parse(item['expirationDate']);
              final salesPeriod = (item['salesPeriod'] as num?)?.toInt() ?? 0;
              final itemName = (item['name'] ?? item['janCode'] ?? '未登録商品')
                  .toString();
              final notificationDate = expirationDate.subtract(
                Duration(days: salesPeriod),
              );
              final isOverdue = notificationDate.isBefore(DateTime.now());

              return Card(
                color: isOverdue
                    ? const Color.fromARGB(255, 199, 227, 249)
                    : Colors.blue[50],
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  leading: Icon(
                    Icons.warning_amber_rounded,
                    color: isOverdue
                        ? const Color.fromARGB(255, 255, 145, 0)
                        : const Color.fromARGB(200, 245, 127, 42),
                    size: 40,
                  ),
                  title: Text(
                    '$itemName の期限が近づいています',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '賞味期限: ${df.format(expirationDate)}\n販売制限開始: ${df.format(notificationDate)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const InventoryStatusScreen(),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
