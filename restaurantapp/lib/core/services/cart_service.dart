import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/customer/domain/entities/product.dart';

class CartItem {
  final String productId;
  final int quantity;
  final String? notes;

  CartItem({
    required this.productId,
    required this.quantity,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'quantity': quantity,
        'notes': notes,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        productId: json['productId'] as String,
        quantity: json['quantity'] as int,
        notes: json['notes'] as String?,
      );
}

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final Map<String, CartItem> _items = {};
  static const String _storageKey = 'customer_cart_persistence';
  static const String _checkoutRequestKey = 'customer_checkout_request_id';

  Map<String, CartItem> get items => Map.unmodifiable(_items);

  int get totalCount => _items.values.fold(0, (sum, item) => sum + item.quantity);

  /// Carga el carrito desde SharedPreferences al iniciar la app
  Future<void> loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cartJson = prefs.getString(_storageKey);
    if (cartJson != null) {
      final Map<String, dynamic> decoded = jsonDecode(cartJson);
      final Map<String, CartItem> loadedItems = {};

      decoded.forEach((key, value) {
        loadedItems[key] = CartItem.fromJson(value);
      });

      _items.clear();
      _items.addAll(loadedItems);
      notifyListeners();
    }
  }

  /// Guarda el estado actual del carrito en el dispositivo
  Future<void> _saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, Map<String, dynamic>> jsonMap = {};

    _items.forEach((key, item) {
      jsonMap[key] = item.toJson();
    });

    await prefs.setString(_storageKey, jsonEncode(jsonMap));
  }

  /// Añade o incrementa un producto en el carrito
  void addToCart(Product product, {String? notes}) {
    final key = _generateKey(product.id, notes);
    final existing = _items[key];

    if (existing != null) {
      _items[key] = CartItem(
        productId: product.id,
        quantity: existing.quantity + 1,
        notes: existing.notes,
      );
    } else {
      _items[key] = CartItem(
        productId: product.id,
        quantity: 1,
        notes: notes,
      );
    }

    _saveToDisk();
    notifyListeners();
  }

  /// Reduce la cantidad o elimina el producto si llega a 0
  void removeFromCart(String key) {
    if (!_items.containsKey(key)) return;

    final item = _items[key]!;
    if (item.quantity > 1) {
      _items[key] = CartItem(
        productId: item.productId,
        quantity: item.quantity - 1,
        notes: item.notes,
      );
    } else {
      _items.remove(key);
    }

    _saveToDisk();
    notifyListeners();
  }

  /// Limpia el carrito (se usa al confirmar pedido exitosamente)
  Future<void> clearCart() async {
    _items.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    notifyListeners();
  }

  Future<String> getOrCreateCheckoutRequestId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_checkoutRequestKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final value = List<int>.generate(16, (_) => random.nextInt(256));
    value[6] = (value[6] & 0x0f) | 0x40;
    value[8] = (value[8] & 0x3f) | 0x80;
    final hex = value.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final requestId =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    await prefs.setString(_checkoutRequestKey, requestId);
    return requestId;
  }

  Future<String?> getCheckoutRequestId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_checkoutRequestKey);
  }

  Future<void> clearCheckoutRequestId({String? expectedRequestId}) async {
    final prefs = await SharedPreferences.getInstance();
    if (expectedRequestId != null &&
        prefs.getString(_checkoutRequestKey) != expectedRequestId) {
      return;
    }
    await prefs.remove(_checkoutRequestKey);
  }

  Future<void> removePurchasedItems(Iterable<CartItem> purchasedItems) async {
    for (final purchased in purchasedItems) {
      final key = _generateKey(purchased.productId, purchased.notes);
      final current = _items[key];
      if (current == null) continue;

      final remaining = current.quantity - purchased.quantity;
      if (remaining > 0) {
        _items[key] = CartItem(
          productId: current.productId,
          quantity: remaining,
          notes: current.notes,
        );
      } else {
        _items.remove(key);
      }
    }
    await _saveToDisk();
    notifyListeners();
  }

  String _generateKey(String productId, String? notes) {
    final trimmedNotes = notes?.trim();
    return '$productId|${trimmedNotes == null || trimmedNotes.isEmpty ? 'none' : trimmedNotes}';
  }
}
