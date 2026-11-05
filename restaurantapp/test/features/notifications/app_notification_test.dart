import 'package:flutter_test/flutter_test.dart';
import 'package:restaurantapp/features/notifications/domain/entities/app_notification.dart';

void main() {
  test('maps a notification returned by Spring Boot', () {
    final notification = AppNotification.fromJson({
      'id': 27,
      'title': 'Nuevo pedido pagado',
      'message': 'El pedido #43 está listo para ser atendido.',
      'type': 'NEW_ORDER',
      'sentAt': '2026-11-04T18:00:00Z',
      'read': false,
      'orderId': 43,
    });

    expect(notification.id, 27);
    expect(notification.type, 'NEW_ORDER');
    expect(notification.orderId, 43);
    expect(notification.isRead, isFalse);
    expect(notification.sentAt.toUtc(), DateTime.utc(2026, 11, 4, 18));
  });

  test('rejects notifications without a valid id or timestamp', () {
    expect(
      () => AppNotification.fromJson({
        'id': 'invalid',
        'sentAt': '2026-11-04T18:00:00Z',
      }),
      throwsFormatException,
    );
    expect(
      () => AppNotification.fromJson({'id': 1, 'sentAt': 'invalid'}),
      throwsFormatException,
    );
  });
}
