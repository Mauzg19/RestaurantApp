import 'package:flutter/material.dart';

import 'offline_sync_service.dart';

class OfflineStatusNotifier extends StatefulWidget {
  const OfflineStatusNotifier({
    super.key,
    required this.syncService,
    required this.messengerKey,
    required this.child,
  });

  final OfflineSyncService syncService;
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  final Widget child;

  @override
  State<OfflineStatusNotifier> createState() => _OfflineStatusNotifierState();
}

class _OfflineStatusNotifierState extends State<OfflineStatusNotifier> {
  late OfflineSyncState _previousState;

  @override
  void initState() {
    super.initState();
    _previousState = widget.syncService.state;
    widget.syncService.addListener(_onStatusChanged);
  }

  @override
  void didUpdateWidget(covariant OfflineStatusNotifier oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.syncService == widget.syncService) return;
    oldWidget.syncService.removeListener(_onStatusChanged);
    _previousState = widget.syncService.state;
    widget.syncService.addListener(_onStatusChanged);
  }

  void _onStatusChanged() {
    final state = widget.syncService.state;
    final previousState = _previousState;
    _previousState = state;
    if (state == previousState) return;

    final (message, icon, color, duration) = switch (state) {
      OfflineSyncState.offline => (
        'Sin conexión. Tus cambios se guardarán para sincronizarse después.',
        Icons.cloud_off_outlined,
        const Color(0xFF8A5A00),
        const Duration(seconds: 4),
      ),
      OfflineSyncState.syncing => (null, null, null, Duration.zero),
      OfflineSyncState.synchronized => (
        'Cambios sincronizados',
        Icons.cloud_done_outlined,
        const Color(0xFF2E6B45),
        const Duration(seconds: 2),
      ),
      OfflineSyncState.syncError => (
        'No se pudieron sincronizar algunos cambios. Se reintentará.',
        Icons.cloud_off_outlined,
        const Color(0xFFB3261E),
        const Duration(seconds: 4),
      ),
      OfflineSyncState.connected when previousState == OfflineSyncState.offline =>
        (
          'Conexión restablecida.',
          Icons.wifi,
          const Color(0xFF2E6B45),
          const Duration(seconds: 2),
        ),
      OfflineSyncState.checking ||
      OfflineSyncState.connected => (null, null, null, Duration.zero),
    };
    if (message == null || icon == null || color == null) return;

    widget.messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          backgroundColor: color,
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  semanticsLabel: message,
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  void dispose() {
    widget.syncService.removeListener(_onStatusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
