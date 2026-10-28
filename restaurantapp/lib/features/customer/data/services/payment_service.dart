import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentResult {
  const PaymentResult({required this.paymentIntentId, this.status = 'paid'});

  final String paymentIntentId;
  final String status;
}

abstract interface class PaymentService {
  Future<PaymentResult> pay({
    required int amountInCents,
    required String currency,
    required List<Map<String, dynamic>> items,
  });
}

class StripePaymentService implements PaymentService {
  StripePaymentService(this.client);

  final SupabaseClient client;

  @override
  Future<PaymentResult> pay({
    required int amountInCents,
    required String currency,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await client.functions.invoke(
      'create-payment-intent',
      body: {'amount': amountInCents, 'currency': currency, 'items': items},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final serverAmount = data['amount'] as int?;
    final clientSecret = data['client_secret'] as String?;
    final paymentIntentId = data['payment_intent_id'] as String?;
    if (serverAmount != amountInCents ||
        clientSecret == null ||
        paymentIntentId == null) {
      throw StateError('Stripe devolvió un importe o respuesta inválida.');
    }

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'Restaurant Fast',
      ),
    );
    await Stripe.instance.presentPaymentSheet();
    return PaymentResult(paymentIntentId: paymentIntentId);
  }
}

class StripeCheckoutPaymentService implements PaymentService {
  StripeCheckoutPaymentService(this.client);

  final SupabaseClient client;

  @override
  Future<PaymentResult> pay({
    required int amountInCents,
    required String currency,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await client.functions.invoke(
      'create-payment-intent',
      body: {
        'mode': 'checkout',
        'currency': currency,
        'items': items,
        'origin': Uri.base.origin,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final sessionUrl = data['session_url'] as String?;
    final sessionId = data['session_id'] as String?;
    if (sessionUrl == null || sessionId == null) {
      throw StateError('Stripe no devolvió una sesión de Checkout válida.');
    }

    final opened = await launchUrl(
      Uri.parse(sessionUrl),
      webOnlyWindowName: '_self',
    );
    if (!opened) {
      throw StateError('No se pudo abrir la pasarela de pago.');
    }
    return PaymentResult(paymentIntentId: sessionId, status: 'pending');
  }
}
