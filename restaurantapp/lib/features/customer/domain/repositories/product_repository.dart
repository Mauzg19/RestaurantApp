import 'dart:typed_data';

import '../entities/product.dart';

abstract interface class ProductRepository {
  List<Product> getProducts();

  void saveProduct(Product product);

  Future<String?> uploadProductImage(String filePath, String productId);

  Future<String?> uploadProductImageBytes(
    Uint8List bytes,
    String fileName,
    String productId,
  );
}
