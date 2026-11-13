import 'package:flutter_test/flutter_test.dart';
import 'package:restaurantapp/core/network/api_config.dart';

void main() {
  final originalBaseUrl = ApiConfig.baseUrl;

  setUp(() {
    ApiConfig.setBaseUrl('http://10.0.2.2:5454');
  });

  tearDown(() {
    ApiConfig.setBaseUrl(originalBaseUrl);
  });

  test('resolves relative image paths against the configured backend', () {
    expect(
      ApiConfig.resolveImageUrl('/uploads/product-images/item.jpg'),
      'http://10.0.2.2:5454/uploads/product-images/item.jpg',
    );
  });

  test('rewrites loopback image URLs for the Android emulator', () {
    expect(
      ApiConfig.resolveImageUrl(
        'http://localhost:5454/uploads/product-images/item.jpg',
      ),
      'http://10.0.2.2:5454/uploads/product-images/item.jpg',
    );
  });

  test('keeps the backend image path platform independent when saving', () {
    expect(
      ApiConfig.imageUrlForStorage(
        'http://10.0.2.2:5454/uploads/product-images/item.jpg',
      ),
      '/uploads/product-images/item.jpg',
    );
  });

  test('keeps external image URLs unchanged', () {
    const externalUrl = 'https://images.example.com/product.jpg';
    expect(ApiConfig.resolveImageUrl(externalUrl), externalUrl);
    expect(ApiConfig.imageUrlForStorage(externalUrl), externalUrl);
  });
}
