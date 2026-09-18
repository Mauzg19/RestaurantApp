import '../entities/product.dart';
import '../repositories/product_repository.dart';

class GetProducts {
  const GetProducts(this.repository);

  final ProductRepository repository;

  List<Product> call() => repository.getProducts();
}
