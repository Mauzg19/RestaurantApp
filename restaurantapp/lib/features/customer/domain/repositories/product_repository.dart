import 'dart:typed_data';

import '../entities/product.dart';

abstract interface class ProductRepository {
  List<Product> getProducts();

  Future<List<ProductCategoryOption>> getCategories();

  Future<void> load();

  Future<void> saveProduct(Product product, {ProductCategoryOption? category});

  Future<void> updateProductAvailability(String productId, bool isAvailable);

  Future<String?> uploadProductImage(String filePath, String productId);

  Future<String?> uploadProductImageBytes(
    Uint8List bytes,
    String fileName,
    String productId,
  );
}
