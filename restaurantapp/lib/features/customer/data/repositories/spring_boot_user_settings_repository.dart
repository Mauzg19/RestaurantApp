import '../../../../core/network/api_config.dart';
import '../../../../core/network/http_client_service.dart';
import '../../../../core/offline/offline_database.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/user_settings_repository.dart';

class SpringBootUserSettingsRepository implements UserSettingsRepository {
  SpringBootUserSettingsRepository({
    required this.httpClient,
    this.offlineDatabase,
  });

  final HttpClientService httpClient;
  final OfflineDatabase? offlineDatabase;

  @override
  Future<Address?> getDeliveryAddress(String email) async {
    final database = offlineDatabase;
    final pending = database == null
        ? const <PendingOperation>[]
        : await database.getPendingOperations(
            email,
            entityType: 'settings',
          );
    for (final operation in pending.reversed) {
      if (operation.entityId == 'delivery-address') {
        return _addressFromBackend(operation.payload);
      }
    }
    try {
      final response = await httpClient.get(ApiConfig.currentUserUrl);
      if (response is! Map) {
        throw const FormatException(
          'Spring Boot devolvió el perfil con formato inválido.',
        );
      }
      final addresses = response['addresses'];
      if (addresses is! List || addresses.isEmpty || addresses.last is! Map) {
        await database?.deleteRecord(
          scope: 'settings',
          ownerEmail: email,
          recordId: 'delivery-address',
        );
        return null;
      }
      final address = _addressFromBackend(
        Map<String, dynamic>.from(addresses.last as Map),
      );
      await _cache(email, 'delivery-address', address.toJson());
      return address;
    } on NetworkUnavailableException {
      if (database == null) rethrow;
      final cached = await _readCached(email, 'delivery-address');
      return cached == null ? null : _addressFromBackend(cached);
    }
  }

  @override
  Future<void> saveDeliveryAddress(String email, Address address) async {
      final operationId = OfflineDatabase.newOperationId();
      final body = {
        'street': address.street,
        'city': address.city,
        'postalCode': address.postalCode,
        'notes': address.notes,
        'clientOperationId': operationId,
      };
    try {
      await httpClient.post(ApiConfig.deliveryAddressUrl, body: body);
      await _cache(email, 'delivery-address', address.toJson());
    } on NetworkUnavailableException {
      final database = offlineDatabase;
      if (database == null) rethrow;
      await _cache(email, 'delivery-address', address.toJson());
      await database.enqueueOperation(
        ownerEmail: email,
        entityType: 'settings',
        entityId: 'delivery-address',
        operationType: 'UPDATE',
        payload: body,
        operationId: operationId,
      );
    }
  }

  @override
  Future<PaymentMethod?> getPaymentMethod(String email) async {
    try {
      final response = await httpClient.get(ApiConfig.userSettingsUrl);
      if (response is! Map) {
        throw const FormatException(
          'Spring Boot devolvió las preferencias con formato inválido.',
        );
      }
      final type = response['paymentType']?.toString() ?? '';
      final details = response['paymentDetails']?.toString() ?? '';
      if (type.isEmpty && details.isEmpty) return null;
      return PaymentMethod(type: type, details: details);
    } on NetworkUnavailableException {
      return null;
    }
  }

  @override
  Future<void> savePaymentMethod(String email, PaymentMethod method) async {
    await httpClient.put(
      ApiConfig.userSettingsUrl,
      body: {
        'paymentType': method.type,
        'paymentDetails': method.details,
      },
    );
  }

  Future<bool> syncPendingOperations(String email) async {
    final database = offlineDatabase;
    if (database == null) return false;
    final operations = await database.getReadyOperations(email);
    var synchronized = false;
    Object? firstError;
    for (final operation in operations.where(
      (operation) => operation.entityType == 'settings',
    )) {
      await database.markOperationInFlight(operation.id);
      try {
        if (operation.entityId == 'delivery-address') {
          await httpClient.post(
            ApiConfig.deliveryAddressUrl,
            body: operation.payload,
          );
        } else {
          throw StateError('Tipo de preferencia offline desconocido.');
        }
        await database.completeOperation(operation.id);
        synchronized = true;
      } catch (error) {
        await database.markOperationFailed(operation.id, error);
        firstError ??= error;
      }
    }
    if (firstError != null) {
      throw StateError('No se pudieron sincronizar las preferencias: $firstError');
    }
    return synchronized;
  }

  Future<void> _cache(
    String email,
    String recordId,
    Map<String, dynamic> payload,
  ) async {
    await offlineDatabase?.cacheRecord(
      scope: 'settings',
      ownerEmail: email,
      recordId: recordId,
      payload: payload,
    );
  }

  Future<Map<String, dynamic>?> _readCached(
    String email,
    String recordId,
  ) async {
    final database = offlineDatabase;
    if (database == null) return null;
    final rows = await database.readRecords(
      scope: 'settings',
      ownerEmail: email,
    );
    for (final row in rows) {
      if (row['recordId'] == recordId) {
        return Map<String, dynamic>.from(row)..remove('recordId');
      }
    }
    return null;
  }

  Address _addressFromBackend(Map<String, dynamic> json) => Address(
        street:
            json['streetAddress']?.toString() ??
            json['street']?.toString() ??
            '',
        city: json['city']?.toString() ?? '',
        postalCode:
            json['postalCode']?.toString() ??
            json['postal_code']?.toString() ??
            '',
        notes: json['notes']?.toString(),
      );
}
