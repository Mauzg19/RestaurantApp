import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';

class SupabaseProductRepository implements ProductRepository {
  SupabaseProductRepository(this.client, {List<Product> fallback = const []})
    : _products = [...fallback];

  final SupabaseClient client;
  final List<Product> _products;

  @override
  Future<void> load() async {
    try {
      final rows = await client
          .from('products')
          .select()
          .order('created_at');
      final remoteProducts = rows.map(_fromRow).toList();
      _products
        ..clear()
        ..addAll(remoteProducts);
    } catch (_) {
      // Keep the local fallback when the database is unavailable.
    }
  }

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
    unawaited(_upsert(product));
  }

  @override
  Future<void> updateProductAvailability(
    String productId,
    bool isAvailable,
  ) async {
    final rows = await client
        .from('products')
        .update({'is_available': isAvailable})
        .eq('id', productId)
        .select('id, is_available');
    if (rows.isEmpty) {
      throw StateError(
        'No se pudo actualizar la disponibilidad del producto. Verifica el rol de administrador y que el producto exista.',
      );
    }

    final index = _products.indexWhere((product) => product.id == productId);
    if (index != -1) {
      _products[index] = _products[index].copyWith(isAvailable: isAvailable);
    }
  }

  @override
  Future<String?> uploadProductImage(String filePath, String productId) async {
    try {
      final extension = filePath.contains('.')
          ? filePath.split('.').last.toLowerCase()
          : 'jpg';
      final storagePath = '$productId.$extension';
      await client.storage
          .from('product-images')
          .upload(
            storagePath,
            File(filePath),
            fileOptions: const FileOptions(upsert: true),
          );
      return client.storage.from('product-images').getPublicUrl(storagePath);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> uploadProductImageBytes(
    Uint8List bytes,
    String fileName,
    String productId,
  ) async {
    try {
      final extension = fileName.contains('.')
          ? fileName.split('.').last.toLowerCase()
          : 'jpg';
      final storagePath = '$productId.$extension';
      await client.storage
          .from('product-images')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/$extension',
            ),
          );
      return client.storage.from('product-images').getPublicUrl(storagePath);
    } catch (_) {
      return null;
    }
  }

  Future<void> _upsert(Product product) async {
    try {
      await client.from('products').upsert({
        'id': product.id,
        'name': product.name,
        'category': product.category.name,
        'price': product.price,
        'image_url': product.imagePath,
        'is_available': product.isAvailable,
      });
    } catch (_) {
      // The in-memory cache remains usable while the request is retried later.
    }
  }

  Product _fromRow(Map<String, dynamic> row) {
    final category = ProductCategory.values.firstWhere(
      (value) => value.name == row['category'],
      orElse: () => ProductCategory.bowls,
    );
    return Product(
      id: row['id'] as String,
      name: row['name'] as String,
      category: category,
      price: (row['price'] as num).toDouble(),
      icon: category.icon,
      accentColor: const Color(0xFFC95D32),
      imagePath: row['image_url'] as String?,
      isAvailable: row['is_available'] as bool? ?? true,
    );
  }
}
