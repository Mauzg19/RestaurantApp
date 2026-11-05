import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/network/api_config.dart';
import '../../../../core/network/http_client_service.dart';
import '../../../../core/offline/offline_database.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';

class SpringBootProductRepository implements ProductRepository {
  SpringBootProductRepository({
    required this.httpClient,
    this.offlineDatabase,
    this.currentOwnerEmail,
    this.serverReachable,
  });

  final HttpClientService httpClient;
  final OfflineDatabase? offlineDatabase;
  final String? Function()? currentOwnerEmail;
  final bool Function()? serverReachable;
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
    await _loadCachedCategories();
    final restaurantId = _restaurantId;
    if (restaurantId == null) {
      await _loadCachedProducts();
    }
    if (_restaurantId == null) {
      return List.unmodifiable(_categories);
    }
    if (_categories.isNotEmpty && serverReachable?.call() == false) {
      return List.unmodifiable(_categories);
    }

    try {
      final response = await httpClient.get(
        ApiConfig.categoryRestaurantUrl(_restaurantId!),
      );
      if (response is! List) {
        throw const FormatException(
          'Spring Boot devolvió las categorías con un formato inválido.',
        );
      }

      _setCategories(response.whereType<Map>());
      final database = offlineDatabase;
      if (database != null) {
        await database.replaceRecords(
          scope: 'categories',
          ownerEmail: _owner,
          records: _categories
              .where((category) => category.id != null)
              .map(
                (category) => {
                  'recordId': category.id.toString(),
                  'id': category.id,
                  'name': category.name,
                },
              )
              .toList(),
        );
      }
      return List.unmodifiable(_categories);
    } on NetworkUnavailableException {
      await _loadCachedCategories();
      return List.unmodifiable(_categories);
    }
  }

  @override
  Future<void> load() async {
    await _loadCachedProducts();
    try {
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

      final remoteFoods = response.whereType<Map>().map((row) {
        final food = Map<String, dynamic>.from(row);
        final id = food['id']?.toString();
        if (id == null || id.isEmpty) {
          throw const FormatException(
            'El backend devolvió un producto sin id.',
          );
        }
        final restaurant = food['restaurant'];
        if (_restaurantId == null && restaurant is Map) {
          _restaurantId = _asInt(restaurant['id']);
        }
        return food;
      }).toList();
      await _mergePendingProducts(remoteFoods);
      _setProducts(remoteFoods);
      await _cacheProducts();
    } on NetworkUnavailableException {
      await _loadCachedProducts();
    }
  }

  void _setProducts(List<Map<String, dynamic>> foods) {
    _rawFoods
      ..clear()
      ..addEntries(
        foods.map((food) {
          final id = food['id'].toString();
          final foodCategory = food['foodCategory'];
          if (foodCategory is Map) {
            final id = _asInt(foodCategory['id']);
            final name = foodCategory['name']?.toString();
            if (id != null && name != null) {
              _categoryIds[name.trim().toLowerCase()] = id;
            }
          }
          return MapEntry(id, food);
        }),
      );
    _products
      ..clear()
      ..addAll(foods.map(_toProduct));
  }

  void _setCategories(Iterable<Map> rows) {
    _categoryIds.clear();
    _categories
      ..clear()
      ..addAll(
        rows.map((row) {
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
  }

  @override
  Future<String?> saveProduct(
    Product product, {
    ProductCategoryOption? category,
  }) async {
    final existing = _rawFoods[product.id];
    final isOfflineProduct = existing?['_offline'] == true;
    final isCreate = existing == null || isOfflineProduct;

    final categoryName =
        category?.name ?? product.categoryName ?? product.category.label;
    final categoryId =
        category?.id ??
        _asInt((existing?['foodCategory'] as Map?)?['id']) ??
        _categoryIds[categoryName.trim().toLowerCase()];
    final clientOperationId =
        existing?['_clientOperationId']?.toString() ??
        (offlineDatabase == null ? null : OfflineDatabase.newOperationId());

    if (isCreate && _restaurantId == null) {
      throw StateError(
        'No se encontró un restaurante activo para guardar el producto.',
      );
    }
    if (categoryId == null) {
      throw StateError(
        'La categoría "$categoryName" no existe en el servidor. '
        'Selecciona una categoría previamente sincronizada.',
      );
    }

    final createBody = <String, dynamic>{
      'name': product.name,
      'description': product.description ?? '',
      'price': product.price.round(),
      'category': {'id': categoryId},
      'images': _imagesFor(product),
      'restaurantId': _restaurantId,
      'vegetarian': false,
      'seasonal': false,
      'available': product.isAvailable,
      'clientOperationId': ?clientOperationId,
    };
    final updateBody = <String, dynamic>{
      'name': product.name,
      'description': product.description ?? '',
      'price': product.price.round(),
      'images': _imagesFor(product),
      'categoryId': categoryId,
      'available': product.isAvailable,
    };

    try {
      final response = isCreate
          ? await httpClient.post(
              '${ApiConfig.baseUrl}/api/admin/food',
              body: createBody,
            )
          : await httpClient.put(
              '${ApiConfig.foodByIdUrl(product.id)}/details',
              body: updateBody,
            );
      if (response is Map && response['id'] != null) {
        final saved = Map<String, dynamic>.from(response);
        saved.remove('_offline');
        saved.remove('_clientOperationId');
        await _upsertRawFood(saved);
      }
      await load();
      return response is Map && response['id'] != null
          ? response['id'].toString()
          : product.id;
    } on NetworkUnavailableException {
      final database = offlineDatabase;
      if (database == null) rethrow;
      if (isCreate && clientOperationId == null) {
        throw StateError('No se pudo asignar una clave idempotente al producto.');
      }
      final localFood = _localFood(
        product,
        categoryId: categoryId,
        categoryName: categoryName,
        offline: isCreate || isOfflineProduct,
        clientOperationId: clientOperationId,
      );
      await database.enqueueOperation(
        ownerEmail: _owner,
        entityType: 'product',
        entityId: product.id,
        operationType: isCreate ? 'CREATE' : 'UPDATE',
        payload: isCreate ? createBody : updateBody,
        operationId: isCreate ? clientOperationId : null,
      );
      await _upsertRawFood(localFood);
      return product.id;
    }
  }

  Map<String, dynamic> _localFood(
    Product product, {
    required int categoryId,
    required String categoryName,
    required bool offline,
    String? clientOperationId,
  }) => {
    'id': product.id,
    'name': product.name,
    'description': product.description ?? '',
    'price': product.price.round(),
    'available': product.isAvailable,
    'images': product.imagePath == null ? [] : [product.imagePath],
    'foodCategory': {'id': categoryId, 'name': categoryName},
    'restaurant': {'id': _restaurantId},
    if (offline) '_offline': true,
    '_clientOperationId': ?clientOperationId,
  };

  Future<void> _upsertRawFood(Map<String, dynamic> food) async {
    final id = food['id']?.toString();
    if (id == null || id.isEmpty) return;
    _rawFoods[id] = food;
    final product = _toProduct(food);
    final index = _products.indexWhere((current) => current.id == id);
    if (index == -1) {
      _products.add(product);
    } else {
      _products[index] = product;
    }
    final database = offlineDatabase;
    if (database != null) {
      await database.cacheRecord(
        scope: 'products',
        ownerEmail: _owner,
        recordId: id,
        payload: food,
      );
    }
  }

  Future<void> _cacheProducts() async {
    final database = offlineDatabase;
    if (database == null) return;
    final foods = _rawFoods.values
        .map((food) => {'recordId': food['id'].toString(), ...food})
        .toList();
    await database.replaceRecords(
      scope: 'products',
      ownerEmail: _owner,
      records: foods,
    );
  }

  Future<void> _mergePendingProducts(
    List<Map<String, dynamic>> remoteFoods,
  ) async {
    final database = offlineDatabase;
    if (database == null) return;
    final pending = await database.getPendingOperations(
      _owner,
      entityType: 'product',
    );
    if (pending.isEmpty) return;
    final cached = await database.readRecords(
      scope: 'products',
      ownerEmail: _owner,
    );
    for (final operation in pending) {
      if (operation.operationType == 'DELETE') {
        remoteFoods.removeWhere(
          (food) => food['id']?.toString() == operation.entityId,
        );
        continue;
      }
      for (final row in cached) {
        if (row['recordId'] != operation.entityId) continue;
        final local = Map<String, dynamic>.from(row)..remove('recordId');
        remoteFoods.removeWhere(
          (food) => food['id']?.toString() == operation.entityId,
        );
        remoteFoods.add(local);
      }
    }
  }

  Future<void> _loadCachedProducts() async {
    final database = offlineDatabase;
    if (database == null) return;
    var cached = await database.readRecords(
      scope: 'products',
      ownerEmail: _owner,
    );
    if (cached.isEmpty && _owner != 'public') {
      cached = await database.readRecords(
        scope: 'products',
        ownerEmail: 'public',
      );
    }
    if (cached.isNotEmpty) {
      final foods = cached.map((row) {
        final food = Map<String, dynamic>.from(row)..remove('recordId');
        return food;
      }).toList();
      _setProducts(foods);
      if (_restaurantId == null) {
        for (final food in foods) {
          final restaurant = food['restaurant'];
          if (restaurant is Map) {
            _restaurantId = _asInt(restaurant['id']);
            if (_restaurantId != null) break;
          }
        }
      }
    }
    await _loadCachedCategories();
  }

  Future<void> _loadCachedCategories() async {
    final database = offlineDatabase;
    if (database == null) return;
    var rows = await database.readRecords(
      scope: 'categories',
      ownerEmail: _owner,
    );
    if (rows.isEmpty && _owner != 'public') {
      rows = await database.readRecords(
        scope: 'categories',
        ownerEmail: 'public',
      );
    }
    if (rows.isEmpty) return;
    _setCategories(rows.map((row) => Map<String, dynamic>.from(row)));
  }

  String get _owner => currentOwnerEmail?.call()?.trim().toLowerCase() ?? 'public';

  @override
  Future<void> updateProductAvailability(
    String productId,
    bool isAvailable,
  ) async {
    final existing = _rawFoods[productId];
    if (existing == null) {
      throw StateError('No se encontró el producto $productId.');
    }
    try {
      final response = await httpClient.put(
        ApiConfig.foodAvailabilityUrl(productId),
        body: {'available': isAvailable},
      );
      if (response is Map) {
        await _upsertRawFood(Map<String, dynamic>.from(response));
        return;
      }
      existing['available'] = isAvailable;
      await _upsertRawFood(existing);
    } on NetworkUnavailableException {
      final database = offlineDatabase;
      if (database == null) rethrow;
      final isOfflineProduct = existing['_offline'] == true;
      final updatedProduct = _toProduct(existing).copyWith(
        isAvailable: isAvailable,
      );
      final category = existing['foodCategory'] is Map
          ? Map<String, dynamic>.from(existing['foodCategory'] as Map)
          : const <String, dynamic>{};
      final categoryId = _asInt(category['id']);
      if (categoryId == null) {
        throw StateError('El producto no tiene una categoría sincronizada.');
      }
      final operationType = isOfflineProduct ? 'CREATE' : 'UPDATE';
      final operationId = existing['_clientOperationId']?.toString();
      await database.enqueueOperation(
        ownerEmail: _owner,
        entityType: 'product',
        entityId: productId,
        operationType: operationType,
        payload: isOfflineProduct
            ? {
                'name': updatedProduct.name,
                'description': updatedProduct.description ?? '',
                'price': updatedProduct.price.round(),
                'category': {'id': categoryId},
                'images': _imagesFor(updatedProduct),
                'restaurantId': _restaurantId,
                'vegetarian': false,
                'seasonal': false,
                'available': isAvailable,
                'clientOperationId': operationId,
              }
            : {'available': isAvailable},
        operationId: operationType == 'CREATE' ? operationId : null,
      );
      existing['available'] = isAvailable;
      await _upsertRawFood(existing);
    }
  }

  @override
  Future<void> deleteProduct(String productId) async {
    final existing = _rawFoods[productId];
    if (existing == null) {
      throw StateError('No se encontró el producto $productId.');
    }
    try {
      await httpClient.delete('${ApiConfig.baseUrl}/api/admin/food/$productId');
      await _removeCachedProduct(productId);
    } on NetworkUnavailableException {
      final database = offlineDatabase;
      if (database == null) rethrow;
      await database.cancelPendingOperations(
        ownerEmail: _owner,
        entityType: 'product_image',
        entityId: productId,
      );
      await database.enqueueOperation(
        ownerEmail: _owner,
        entityType: 'product',
        entityId: productId,
        operationType: 'DELETE',
        payload: const {},
      );
      await _removeCachedProduct(productId);
    }
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
    dynamic response;
    try {
      response = await httpClient.postMultipartBytes(
        ApiConfig.foodImageUploadUrl(productId),
        bytes: bytes,
        fileName: fileName,
      );
    } on NetworkUnavailableException {
      final database = offlineDatabase;
      if (database == null) rethrow;
      await database.enqueueOperation(
        ownerEmail: _owner,
        entityType: 'product_image',
        entityId: productId,
        operationType: 'UPDATE',
        payload: {'fileName': fileName, 'bytes': base64Encode(bytes)},
      );
      return null;
    }
    if (response is! Map || response['url'] is! String) {
      throw const FormatException(
        'El backend devolvió una URL de imagen inválida.',
      );
    }
    final imageUrl = Uri.parse(ApiConfig.baseUrl)
        .resolve(response['url'] as String)
        .toString();
    final food = _rawFoods[productId];
    if (food != null) {
      food['images'] = [imageUrl];
      await _upsertRawFood(food);
    }
    return imageUrl;
  }

  Future<bool> syncPendingOperations() async {
    final database = offlineDatabase;
    if (database == null) return false;
    final operations = await database.getReadyOperations(_owner);
    final serverIds = <String, String>{};
    var synchronized = false;
    Object? firstError;
    for (final operation in operations.where(
      (candidate) =>
          candidate.entityType == 'product' ||
          candidate.entityType == 'product_image',
    )) {
      await database.markOperationInFlight(operation.id);
      try {
        final serverId = serverIds[operation.entityId] ?? operation.entityId;
        if (operation.entityType == 'product_image') {
          final response = await httpClient.postMultipartBytes(
            ApiConfig.foodImageUploadUrl(serverId),
            bytes: base64Decode(operation.payload['bytes'] as String),
            fileName: operation.payload['fileName'] as String,
          );
          if (response is! Map || response['url'] is! String) {
            throw const FormatException(
              'El backend devolvió una URL de imagen inválida.',
            );
          }
          final raw = _rawFoods[serverId];
          if (raw != null) {
            raw['images'] = [
              Uri.parse(ApiConfig.baseUrl)
                  .resolve(response['url'] as String)
                  .toString(),
            ];
            await _upsertRawFood(raw);
          }
        } else if (operation.operationType == 'CREATE') {
          final response = await httpClient.post(
            '${ApiConfig.baseUrl}/api/admin/food',
            body: operation.payload,
          );
          if (response is! Map || response['id'] == null) {
            throw const FormatException(
              'Spring Boot no devolvió el id del producto sincronizado.',
            );
          }
          final raw = Map<String, dynamic>.from(response);
          final newId = raw['id'].toString();
          serverIds[operation.entityId] = newId;
          await _removeCachedProduct(operation.entityId);
          await _upsertRawFood(raw);
          await database.remapPendingEntity(
            ownerEmail: _owner,
            entityType: 'product',
            oldId: operation.entityId,
            newId: newId,
          );
          await database.remapPendingEntity(
            ownerEmail: _owner,
            entityType: 'product_image',
            oldId: operation.entityId,
            newId: newId,
          );
        } else if (operation.operationType == 'DELETE') {
          try {
            await httpClient.delete(
              '${ApiConfig.baseUrl}/api/admin/food/$serverId',
            );
          } on HttpApiException catch (error) {
            if (error.statusCode != 404) rethrow;
          }
          await _removeCachedProduct(serverId);
        } else if (operation.operationType == 'UPDATE') {
          final payload = operation.payload;
          if (payload.containsKey('name')) {
            await httpClient.put(
              '${ApiConfig.foodByIdUrl(serverId)}/details',
              body: {
                'name': payload['name'],
                'description': payload['description'],
                'price': payload['price'],
                'images': payload['images'],
                'categoryId': payload['categoryId'],
              },
            );
          }
          if (payload['available'] is bool) {
            await httpClient.put(
              ApiConfig.foodAvailabilityUrl(serverId),
              body: {'available': payload['available']},
            );
          }
          final raw = _rawFoods[serverId];
          if (raw != null) {
            raw
              ..addAll(payload)
              ..remove('_offline');
            await _upsertRawFood(raw);
          }
        } else {
          throw StateError('Operación de producto offline desconocida.');
        }
        await database.completeOperation(operation.id);
        synchronized = true;
      } catch (error) {
        await database.markOperationFailed(operation.id, error);
        firstError ??= error;
      }
    }
    if (firstError != null) {
      throw StateError('No se pudieron sincronizar los productos: $firstError');
    }
    return synchronized;
  }

  Future<void> _removeCachedProduct(String productId) async {
    _products.removeWhere((product) => product.id == productId);
    _rawFoods.remove(productId);
    await offlineDatabase?.deleteRecord(
      scope: 'products',
      ownerEmail: _owner,
      recordId: productId,
    );
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
