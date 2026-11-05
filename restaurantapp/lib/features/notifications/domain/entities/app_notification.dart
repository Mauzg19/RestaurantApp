class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.sentAt,
    required this.isRead,
    this.orderId,
    this.restaurantId,
  });

  final int id;
  final String title;
  final String message;
  final String type;
  final DateTime sentAt;
  final bool isRead;
  final int? orderId;
  final int? restaurantId;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final id = int.tryParse(json['id']?.toString() ?? '');
    if (id == null) {
      throw const FormatException(
        'El aviso recibido no contiene un id válido.',
      );
    }

    final sentAtValue = json['sentAt'];
    final sentAt = sentAtValue is num
        ? DateTime.fromMillisecondsSinceEpoch(sentAtValue.toInt())
        : DateTime.tryParse(sentAtValue?.toString() ?? '');
    if (sentAt == null) {
      throw const FormatException(
        'El aviso recibido no contiene una fecha válida.',
      );
    }

    return AppNotification(
      id: id,
      title: json['title']?.toString() ?? 'Notificación',
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? 'GENERAL',
      sentAt: sentAt.toLocal(),
      isRead: json['read'] == true,
      orderId: int.tryParse(json['orderId']?.toString() ?? ''),
      restaurantId: int.tryParse(json['restaurantId']?.toString() ?? ''),
    );
  }
}
