import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../services/dept_service.dart';
import 'product_registration_screen.dart';

class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登録商品一覧')),
      body: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          if (provider.products.isEmpty) {
            return Center(
              child: Text(
                '商品が登録されていません',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            itemCount: provider.products.length,
            itemBuilder: (context, index) {
              final product = provider.products[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  leading: product.imagePath.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(product.imagePath),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.image_not_supported, size: 60),
                  title: Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'JAN: ${product.janCode}\nDEPT: ${product.deptNumber}: ${DeptService.getDeptName(product.deptNumber)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  isThreeLine: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ProductRegistrationScreen(editProduct: product),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProductRegistrationScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
