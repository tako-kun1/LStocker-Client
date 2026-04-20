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
    return await _dbHelper.getProduct(janCode);
  }

  Future<void> deleteProduct(Product product) async {
    await _dbHelper.markProductDeleted(product.janCode, syncStatus: 'synced');

    await fetchProducts();
  }
}
