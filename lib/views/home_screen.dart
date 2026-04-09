import 'package:flutter/material.dart';
import 'product_registration_screen.dart';
import 'product_list_screen.dart';
import 'inventory_registration_screen.dart';
import 'inventory_status_screen.dart';
import 'notification_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LStocker'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _buildMenuCard(
              context,
              '商品登録',
              Icons.add_shopping_cart,
              Colors.blue,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductRegistrationScreen())),
            ),
            _buildMenuCard(
              context,
              '登録商品一覧',
              Icons.list_alt,
              Colors.green,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListScreen())),
            ),
            _buildMenuCard(
              context,
              '在庫登録',
              Icons.inventory,
              Colors.orange,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryRegistrationScreen())),
            ),
            _buildMenuCard(
              context,
              '在庫状況確認',
              Icons.fact_check,
              Colors.teal,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryStatusScreen())),
            ),
            _buildMenuCard(
              context,
              '通知',
              Icons.notifications,
              Colors.redAccent,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
            ),
            _buildMenuCard(
              context,
              '設定',
              Icons.settings,
              Colors.grey,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
