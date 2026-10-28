import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Servicio de feedback sensorial del dispositivo y notificaciones in-app.
class DeviceFeedbackService {
  DeviceFeedbackService._();

  /// Emite una vibración háptica ligera para confirmaciones o selecciones.
  static Future<void> triggerSelection() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Emite una vibración háptica de impacto medio cuando se procesa una acción importante.
  static Future<void> triggerSuccess() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Emite una vibración háptica pesada ante errores o alertas críticas.
  static Future<void> triggerWarning() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Muestra un banner flotante de notificación in-app interactivo.
  static void showInAppNotification(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Icons.notifications_active,
    Color backgroundColor = const Color(0xFF2E7D32),
    VoidCallback? onTap,
  }) {
    triggerSuccess();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 6,
        content: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
