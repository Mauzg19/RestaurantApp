import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:restaurantapp/core/services/cart_service.dart';
import 'package:restaurantapp/core/theme/app_theme.dart';
import 'package:restaurantapp/features/auth/domain/entities/auth_user.dart';
import 'package:restaurantapp/features/customer/data/repositories/product_repository_impl.dart';
import 'package:restaurantapp/features/customer/domain/entities/reward.dart';
import 'package:restaurantapp/features/customer/domain/repositories/rewards_repository.dart';
import 'package:restaurantapp/features/customer/domain/usecases/get_products.dart';
import 'package:restaurantapp/features/customer/presentation/pages/customer_home_page.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CartService().clearCart();
  });

  testWidgets('el cliente se une y selecciona un premio para su pedido', (
    tester,
  ) async {
    final rewardsRepository = _FakeRewardsRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CustomerHomePage(
          user: const AuthUser(
            fullName: 'Ana López',
            email: 'ana@example.com',
            role: AuthRole.customer,
          ),
          getProducts: GetProducts(ProductRepositoryImpl()),
          rewardsRepository: rewardsRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Premios'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Únete gratis y gana 1 punto por cada \$1.000 COP efectivamente pagados.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Unirme gratis'));
    await tester.pumpAndSettle();
    expect(rewardsRepository.joinCalled, isTrue);
    expect(find.text('150 puntos disponibles'), findsOneWidget);

    await tester.tap(find.text('Usar en mi pedido'));
    await tester.pumpAndSettle();
    expect(find.text('Quitar'), findsOneWidget);
  });
}

class _FakeRewardsRepository implements RewardsRepository {
  bool joinCalled = false;

  final _reward = const RewardCatalogItem(
    id: 1,
    code: 'starter-discount',
    name: 'Descuento \$5.000',
    description: 'Canjea puntos por descuento.',
    requiredPoints: 100,
    discountAmount: 5000,
    minimumOrderAmount: 25000,
    active: true,
  );

  @override
  Future<RewardsSnapshot> load() async => RewardsSnapshot(
    joined: joinCalled,
    pointsBalance: joinCalled ? 150 : 0,
    catalog: [_reward],
    history: const [],
  );

  @override
  Future<RewardsSnapshot> join() async {
    joinCalled = true;
    return load();
  }
}
