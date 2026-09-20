import 'dart:typed_data';

import '../entities/product.dart';

abstract interface class ProductRepository {
  List<Product> getProducts();

  Future<void> load();

  void saveProduct(Product product);

  Future<void> updateProductAvailability(String productId, bool isAvailable);

  Future<String?> uploadProductImage(String filePath, String productId);

  Future<String?> uploadProductImageBytes(
    Uint8List bytes,
    String fileName,
    String productId,
  );
}
