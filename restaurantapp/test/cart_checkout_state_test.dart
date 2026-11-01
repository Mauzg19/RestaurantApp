import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:restaurantapp/core/services/cart_service.dart';
import 'package:restaurantapp/features/customer/domain/entities/product.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CartService().clearCart();
    await CartService().clearCheckoutRequestId();
  });

  test('keeps checkout idempotency key until the matching payment is resolved', () async {
    final cart = CartService();
    final firstRequestId = await cart.getOrCreateCheckoutRequestId();

    expect(await cart.getOrCreateCheckoutRequestId(), firstRequestId);
    await cart.clearCheckoutRequestId(expectedRequestId: 'another-order');
    expect(await cart.getCheckoutRequestId(), firstRequestId);

    await cart.clearCheckoutRequestId(expectedRequestId: firstRequestId);
    expect(await cart.getCheckoutRequestId(), isNull);
  });

  test('removes only purchased quantities after confirmed payment', () async {
    final cart = CartService();
    const product = Product(
      id: '13',
      name: 'Arepa',
      category: ProductCategory.bowls,
      price: 15000,
      icon: Icons.rice_bowl,
      accentColor: Color(0xFFC95D32),
    );
    cart.addToCart(product, notes: 'Sin salsa');
    cart.addToCart(product, notes: 'Sin salsa');
    cart.addToCart(product);

    await cart.removePurchasedItems([
      CartItem(productId: '13', quantity: 2, notes: 'Sin salsa'),
    ]);

    expect(cart.totalCount, 1);
    expect(cart.items.values.single.notes, isNull);
  });
}
