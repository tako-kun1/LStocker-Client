import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';

class ProductProvider with ChangeNotifier {
  List<Product> _products = [];
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SyncService _syncService = SyncService();

  List<Product> get products => _products;

  Future<void> fetchProducts() async {
    _products = await _dbHelper.getProducts();
    notifyListeners();
  }

  Future<void> addProduct(Product product) async {
    // ローカル DB に追加
    await _dbHelper.insertProduct(product, syncStatus: 'pending');

    // Sync queue に追加（サーバーがある場合）
    await _syncService.queueProductChange(
      janCode: product.janCode,
      name: product.name,
      description: product.description,
      imagePath: product.imagePath,
      deptNumber: product.deptNumber,
      salesPeriod: product.salesPeriod,
      operation: 'create',
    );

    await fetchProducts();
  }

  Future<void> updateProduct(Product product) async {
    // ローカル DB を更新
    await _dbHelper.updateProduct(product, syncStatus: 'pending');

    // Sync queue に追加（サーバーがある場合）
    await _syncService.queueProductChange(
      janCode: product.janCode,
      name: product.name,
      description: product.description,
      imagePath: product.imagePath,
      deptNumber: product.deptNumber,
      salesPeriod: product.salesPeriod,
      operation: 'update',
    );

    await fetchProducts();
  }

  Future<Product?> getProduct(String janCode) async {
    return await _dbHelper.getProduct(janCode);
  }

  Future<void> deleteProduct(Product product) async {
    await _dbHelper.markProductDeleted(product.janCode, syncStatus: 'pending');
    await _syncService.queueProductChange(
      janCode: product.janCode,
      name: product.name,
      description: product.description,
      imagePath: product.imagePath,
      deptNumber: product.deptNumber,
      salesPeriod: product.salesPeriod,
      operation: 'delete',
    );

    await fetchProducts();
  }
}
