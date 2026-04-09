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
      appBar: AppBar(
        title: const Text('登録商品一覧'),
      ),
      body: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          if (provider.products.isEmpty) {
            return const Center(child: Text('商品が登録されていません'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: provider.products.length,
            itemBuilder: (context, index) {
              final product = provider.products[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
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
                  title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'JAN: ${product.janCode}\nDEPT: ${product.deptNumber}: ${DeptService.getDeptName(product.deptNumber)}',
                  ),
                  isThreeLine: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductRegistrationScreen(editProduct: product),
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
