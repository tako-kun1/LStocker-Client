import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/inventory_provider.dart';
import 'product_registration_screen.dart';
import 'product_list_screen.dart';
import 'inventory_registration_screen.dart';
import 'inventory_status_screen.dart';
import 'notification_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth >= 1100
        ? 4
        : screenWidth >= 760
        ? 3
        : 2;
    final childAspectRatio = screenWidth >= 760 ? 1.06 : 0.96;

    return Scaffold(
      appBar: AppBar(title: const Text('LStocker')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: GridView.count(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
          children: [
            _buildMenuCard(
              context,
              '商品登録',
              Icons.add_shopping_cart,
              Colors.blue,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProductRegistrationScreen(),
                ),
              ),
            ),
            _buildMenuCard(
              context,
              '登録商品一覧',
              Icons.list_alt,
              Colors.green,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductListScreen()),
              ),
            ),
            _buildMenuCard(
              context,
              '在庫登録',
              Icons.inventory,
              Colors.orange,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InventoryRegistrationScreen(),
                ),
              ),
            ),
            _buildMenuCard(
              context,
              '在庫状況確認',
              Icons.fact_check,
              Colors.teal,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InventoryStatusScreen(),
                ),
              ),
            ),
            Consumer<InventoryProvider>(
              builder: (context, inventoryProvider, child) {
                return _buildMenuCard(
                  context,
                  '通知',
                  Icons.notifications,
                  Colors.redAccent,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationScreen(),
                    ),
                  ),
                  showNotificationBadge:
                      inventoryProvider.nearExpirationNotificationCount > 0,
                );
              },
            ),
            _buildMenuCard(
              context,
              '設定',
              Icons.settings,
              Colors.grey,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool showNotificationBadge = false,
  }) {
    final cardColor = color.withValues(alpha: 0.09);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [cardColor, Colors.white],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(icon, size: 32, color: color),
                    ),
                    if (showNotificationBadge)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
