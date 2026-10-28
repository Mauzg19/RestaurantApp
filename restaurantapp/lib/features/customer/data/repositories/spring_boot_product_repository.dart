import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/network/api_config.dart';
import '../../../../core/network/http_client_service.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';

class SpringBootProductRepository implements ProductRepository {
  SpringBootProductRepository({required this.httpClient});

  final HttpClientService httpClient;
  final List<Product> _products = [];
  final Map<String, Map<String, dynamic>> _rawFoods = {};
  final Map<String, int> _categoryIds = {};
  final List<ProductCategoryOption> _categories = [];
  int? _restaurantId;

  int? get restaurantId => _restaurantId;

  @override
  List<Product> getProducts() => List.unmodifiable(_products);

  @override
  Future<List<ProductCategoryOption>> getCategories() async {
    final restaurantId = _restaurantId;
    if (restaurantId == null) {
      throw StateError('No se encontró un restaurante activo en el sistema.');
    }

    final response = await httpClient.get(
      ApiConfig.categoryRestaurantUrl(restaurantId),
    );
    if (response is! List) {
      throw const FormatException(
        'Spring Boot devolvió las categorías con un formato inválido.',
      );
    }

    _categoryIds.clear();
    _categories
      ..clear()
      ..addAll(
        response.whereType<Map>().map((row) {
          final category = Map<String, dynamic>.from(row);
          final id = _asInt(category['id']);
          final name = category['name']?.toString().trim();
          if (id == null || name == null || name.isEmpty) {
            throw const FormatException(
              'El backend devolvió una categoría sin id o nombre.',
            );
          }
          _categoryIds[name.toLowerCase()] = id;
          return ProductCategoryOption(id: id, name: name);
        }),
      );

    return List.unmodifiable(_categories);
  }

  @override
  Future<void> load() async {
    _rawFoods.clear();
    _categoryIds.clear();
    final restaurants = await httpClient.get(ApiConfig.restaurantsUrl);
    if (restaurants is List && restaurants.isNotEmpty) {
      final firstRestaurant = restaurants.first;
      if (firstRestaurant is Map) {
        _restaurantId = _asInt(firstRestaurant['id']);
      }
    }

    final response = await httpClient.get(ApiConfig.foodsUrl);
    if (response is! List) {
      throw const FormatException(
        'Spring Boot devolvió un menú con formato inválido.',
      );
    }

    _products
      ..clear()
      ..addAll(
        response.whereType<Map>().map((row) {
          final food = Map<String, dynamic>.from(row);
          final id = food['id']?.toString();
          if (id == null || id.isEmpty) {
            throw const FormatException(
              'El backend devolvió un producto sin id.',
            );
          }
          _rawFoods[id] = food;
          final restaurant = food['restaurant'];
          if (_restaurantId == null && restaurant is Map) {
            _restaurantId = _asInt(restaurant['id']);
          }
          final foodCategory = food['foodCategory'];
          if (foodCategory is Map) {
            final id = _asInt(foodCategory['id']);
            final name = foodCategory['name']?.toString();
            if (id != null && name != null) {
              _categoryIds[_categoryFromName(name).label] = id;
            }
          }
          return _toProduct(food);
        }),
      );
  }

  @override
  Future<void> saveProduct(
    Product product, {
    ProductCategoryOption? category,
  }) async {
    final existing = _rawFoods[product.id];

    final categoryName =
        category?.name ?? product.categoryName ?? product.category.label;
    final categoryId =
        category?.id ??
        _asInt((existing?['foodCategory'] as Map?)?['id']) ??
        _categoryIds[categoryName.trim().toLowerCase()];

    if (existing != null) {
      final images = _imagesFor(product);
      await httpClient.put(
        '${ApiConfig.foodByIdUrl(product.id)}/details',
        body: {
          'name': product.name,
          'description': product.description ?? '',
          'price': product.price.round(),
          'images': images,
          'categoryId': categoryId,
        },
      );
    } else {
      final restaurantId = _restaurantId;
      if (restaurantId == null) {
        throw StateError(
          'Error: No se encontró un restaurante activo en el sistema.',
        );
      }
      if (categoryId == null) {
        throw StateError(
          'La categoría "$categoryName" no existe en el servidor. '
          'Por favor, selecciona una categoría existente.',
        );
      }
      await httpClient.post(
        '${ApiConfig.baseUrl}/api/admin/food',
        body: {
          'name': product.name,
          'description': product.description ?? '',
          'price': product.price.round(),
          'category': {'id': categoryId},
          'images': _imagesFor(product),
          'restaurantId': restaurantId,
          'vegetarian': false,
          'seasonal': false,
        },
      );
    }
    await load();
  }

  @override
  Future<void> updateProductAvailability(
    String productId,
    bool isAvailable,
  ) async {
    await httpClient.put(
      ApiConfig.foodAvailabilityUrl(productId),
      body: {'available': isAvailable},
    );
    final index = _products.indexWhere((product) => product.id == productId);
    if (index != -1) {
      _products[index] = _products[index].copyWith(isAvailable: isAvailable);
    }
    final food = _rawFoods[productId];
    if (food != null) food['available'] = isAvailable;
  }

  @override
  Future<String?> uploadProductImage(String filePath, String productId) async {
    final scheme = Uri.tryParse(filePath)?.scheme;
    if (scheme == 'http' || scheme == 'https') return filePath;
    final file = File(filePath);
    return uploadProductImageBytes(
      await file.readAsBytes(),
      filePath.split(RegExp(r'[/\\]')).last,
      productId,
    );
  }

  @override
  Future<String?> uploadProductImageBytes(
    Uint8List bytes,
    String fileName,
    String productId,
  ) async {
    final response = await httpClient.postMultipartBytes(
      ApiConfig.foodImageUploadUrl(productId),
      bytes: bytes,
      fileName: fileName,
    );
    if (response is! Map || response['url'] is! String) {
      throw const FormatException(
        'El backend devolvió una URL de imagen inválida.',
      );
    }
    return Uri.parse(ApiConfig.baseUrl)
        .resolve(response['url'] as String)
        .toString();
  }

  Product _toProduct(Map<String, dynamic> food) {
    final category = (food['foodCategory'] as Map?)?['name']?.toString() ?? '';
    final productCategory = _categoryFromName(category);
    final rawImages = food['images'];
    final image = rawImages is List && rawImages.isNotEmpty
        ? rawImages.first?.toString()
        : null;
    final restaurant = food['restaurant'];
    if (_restaurantId == null && restaurant is Map) {
      _restaurantId = _asInt(restaurant['id']);
    }
    return Product(
      id: food['id'].toString(),
      name: food['name']?.toString() ?? '',
      category: productCategory,
      categoryName: category,
      price: _asDouble(food['price']),
      icon: productCategory.icon,
      accentColor: const Color(0xFFC95D32),
      isAvailable: food['available'] == true,
      imagePath: image,
      description: food['description']?.toString(),
    );
  }

  ProductCategory _categoryFromName(String value) {
    final name = value.toLowerCase();
    if (name.contains('burrito')) return ProductCategory.burritos;
    if (name.contains('taco')) return ProductCategory.tacos;
    if (name.contains('bowl')) return ProductCategory.bowls;
    if (name.contains('drink') || name.contains('bebida')) {
      return ProductCategory.drinks;
    }
    return ProductCategory.sides;
  }

  List<String> _imagesFor(Product product) {
    final image = product.imagePath;
    if (image == null || image.isEmpty) return const [];
    final scheme = Uri.tryParse(image)?.scheme;
    if (scheme != 'http' && scheme != 'https') return const [];
    return [image];
  }

  int? _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value');

  double _asDouble(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}
