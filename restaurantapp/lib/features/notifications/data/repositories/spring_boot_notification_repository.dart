import '../../../../core/network/api_config.dart';
import '../../../../core/network/http_client_service.dart';
import '../../domain/entities/app_notification.dart';

class SpringBootNotificationRepository {
  SpringBootNotificationRepository({required this.httpClient});

  final HttpClientService httpClient;

  Future<List<AppNotification>> load() async {
    final response = await httpClient.get(ApiConfig.notificationsUrl);
    if (response is! List) {
      throw const FormatException(
        'Spring Boot devolvió las notificaciones con formato inválido.',
      );
    }

    return response
        .whereType<Map>()
        .map((row) => AppNotification.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<void> markAsRead(int id) async {
    await httpClient.put(ApiConfig.notificationReadUrl(id), body: const {});
  }

  Future<void> markAllAsRead() async {
    await httpClient.put(ApiConfig.notificationsReadAllUrl, body: const {});
  }

  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    await httpClient.post(
      ApiConfig.notificationDeviceTokenUrl,
      body: {'token': token, 'platform': platform},
    );
  }

  Future<void> unregisterDeviceToken(String token) async {
    await httpClient.delete(
      '${ApiConfig.notificationDeviceTokenUrl}?token=${Uri.encodeQueryComponent(token)}',
    );
  }
}
