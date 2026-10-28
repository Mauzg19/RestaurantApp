import 'package:flutter_test/flutter_test.dart';
import 'package:restaurantapp/features/customer/domain/entities/product.dart';

void main() {
  test('formatea importes COP con puntos de miles y sin decimales', () {
    expect(formatCop(23700), '\$23.700 COP');
  });
}
