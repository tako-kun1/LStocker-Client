import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/product_provider.dart';
import '../services/dept_service.dart';
import 'product_registration_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  String _searchQuery = '';
  int? _selectedDeptNumber;

  List<Product> _filterProducts(List<Product> products) {
    final query = _searchQuery.trim().toLowerCase();

    return products.where((product) {
      final matchesDept =
          _selectedDeptNumber == null ||
          product.deptNumber == _selectedDeptNumber;
      if (!matchesDept) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final deptName = DeptService.getDeptName(product.deptNumber).toLowerCase();
      return product.name.toLowerCase().contains(query) ||
          product.janCode.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query) ||
          deptName.contains(query) ||
          product.deptNumber.toString().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final deptIds = DeptService.getAvailableDeptIds();

    return Scaffold(
      appBar: AppBar(
        title: const Text('登録商品一覧'),
        actions: [
          IconButton(
            tooltip: 'ローカルデータを再読み込み',
            onPressed: () {
              context.read<ProductProvider>().fetchProducts();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          final filteredProducts = _filterProducts(provider.products);

          if (provider.products.isEmpty) {
            return Center(
              child: Text(
                '商品が登録されていません',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: '商品名・JAN・DEPTで検索',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int?>(
                      initialValue: _selectedDeptNumber,
                      decoration: const InputDecoration(
                        labelText: 'DEPTで絞り込み',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('すべて表示'),
                        ),
                        ...deptIds.map(
                          (deptId) => DropdownMenuItem<int?>(
                            value: deptId,
                            child: Text(
                              '$deptId: ${DeptService.getDeptName(deptId)}',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedDeptNumber = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('表示件数: ${filteredProducts.length} / ${provider.products.length}'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredProducts.isEmpty
                    ? Center(
                        child: Text(
                          '条件に一致する商品がありません',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
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
                                  : const Icon(
                                      Icons.image_not_supported,
                                      size: 60,
                                    ),
                              title: Text(
                                product.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                'JAN: ${product.janCode}\nDEPT: ${product.deptNumber}: ${DeptService.getDeptName(product.deptNumber)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              isThreeLine: true,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProductRegistrationScreen(
                                    editProduct: product,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
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
