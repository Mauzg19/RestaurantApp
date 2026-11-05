import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurantapp/core/network/http_client_service.dart';
import 'package:restaurantapp/core/offline/offline_status_notifier.dart';
import 'package:restaurantapp/core/offline/offline_sync_service.dart';

void main() {
  testWidgets(
    'keeps the normal screen clear and shows temporary offline feedback',
    (tester) async {
      var network = <ConnectivityResult>[ConnectivityResult.wifi];
      final service = OfflineSyncService(
        httpClient: _FakeHttpClient(),
        connectivityCheck: () async => network,
        connectivityChanges: const Stream.empty(),
      );
      service.setSyncHandler(() async => false);
      final messengerKey = GlobalKey<ScaffoldMessengerState>();

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: messengerKey,
          builder: (context, child) => OfflineStatusNotifier(
            syncService: service,
            messengerKey: messengerKey,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const Scaffold(body: Text('Inicio')),
        ),
      );
      await service.initialize();
      await tester.pumpAndSettle();

      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Conectado'), findsNothing);
      expect(find.text('Sincronizando cambios guardados…'), findsNothing);
      expect(
        find.text(
          'Sin conexión. Tus cambios se guardarán para sincronizarse después.',
        ),
        findsNothing,
      );

      network = [ConnectivityResult.none];
      await service.checkNow();
      await tester.pump();

      expect(
        find.text(
          'Sin conexión. Tus cambios se guardarán para sincronizarse después.',
        ),
        findsOneWidget,
      );
      expect(find.text('Inicio'), findsOneWidget);

      service.dispose();
    },
  );
}

class _FakeHttpClient extends HttpClientService {
  @override
  Future<dynamic> get(
    String url, {
    bool requiresAuth = true,
    Duration? timeout,
  }) async => const [];
}
