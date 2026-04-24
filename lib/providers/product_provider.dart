import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../services/database_helper.dart';

class ProductProvider with ChangeNotifier {
  List<Product> _products = [];
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<Product> get products => _products;

  Future<void> fetchProducts() async {
    _products = await _dbHelper.getProducts();
    notifyListeners();
  }

  Future<void> addProduct(Product product) async {
    await _dbHelper.insertProduct(product, syncStatus: 'synced');

    await fetchProducts();
  }

  Future<void> updateProduct(Product product) async {
    await _dbHelper.updateProduct(product, syncStatus: 'synced');

    await fetchProducts();
  }

  Future<Product?> getProduct(String janCode) async {
    // まずメモリ上のリストを検索（DBと一覧のズレを防ぐ）
    final cached = _products.where((p) => p.janCode == janCode).firstOrNull;
    if (cached != null) return cached;
    // フォールバック: DBを直接クエリ
    return await _dbHelper.getProduct(janCode);
  }

  Future<void> deleteProduct(Product product) async {
    await _dbHelper.markProductDeleted(product.janCode, syncStatus: 'synced');

    await fetchProducts();
  }
}
