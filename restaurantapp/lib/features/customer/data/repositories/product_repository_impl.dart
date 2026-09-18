import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  final List<Product> _products = [
    const Product(
      id: 'burrito-pollo',
      name: 'Burrito de pollo',
      category: ProductCategory.burritos,
      price: 8.75,
      icon: Icons.lunch_dining,
      accentColor: Color(0xFFC95D32),
    ),
    const Product(
      id: 'bowl-bbq',
      name: 'Bowl BBQ',
      category: ProductCategory.bowls,
      price: 8.25,
      icon: Icons.rice_bowl,
      accentColor: Color(0xFFC95D32),
    ),
    const Product(
      id: 'tacos-picantes',
      name: 'Tacos picantes',
      category: ProductCategory.tacos,
      price: 7.25,
      icon: Icons.local_pizza,
      accentColor: Color(0xFFE9A24E),
    ),
    const Product(
      id: 'fries',
      name: 'Patatas deluxe',
      category: ProductCategory.sides,
      price: 4.5,
      icon: Icons.fastfood,
      accentColor: Color(0xFFF2B366),
    ),
    const Product(
      id: 'agua-citrus',
      name: 'Agua cítrica',
      category: ProductCategory.drinks,
      price: 2.75,
      icon: Icons.local_drink,
      accentColor: Color(0xFFF2B366),
    ),
  ];

  @override
  List<Product> getProducts() => List.unmodifiable(_products);

  @override
  void saveProduct(Product product) {
    final index = _products.indexWhere((current) => current.id == product.id);
    if (index == -1) {
      _products.add(product);
    } else {
      _products[index] = product;
    }
  }

  @override
  Future<String?> uploadProductImage(String filePath, String productId) async =>
      filePath;

  @override
  Future<String?> uploadProductImageBytes(
    Uint8List bytes,
    String fileName,
    String productId,
  ) async => fileName;
}
