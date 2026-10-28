import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const authorization = request.headers.get('Authorization');
    if (!authorization) return json({ error: 'Sesión requerida.' }, 401);

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authorization } } },
    );
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) return json({ error: 'Sesión inválida.' }, 401);

    const body = await request.json();
    const requestedItems = body.items;
    const currency = body.currency === 'gbp' ? 'gbp' : null;
    const mode = body.mode === 'checkout' ? 'checkout' : 'intent';
    if (!Array.isArray(requestedItems) || requestedItems.length === 0 || !currency) {
      return json({ error: 'Carrito o moneda inválidos.' }, 400);
    }

    const productIds = requestedItems.map((item) => String(item.product_id));
    const { data: products, error: productsError } = await supabase
      .from('products')
      .select('id, name, price, is_available')
      .in('id', productIds);
    if (productsError) throw productsError;

    const productById = new Map((products ?? []).map((product) => [product.id, product]));
    let amount = 0;
    for (const item of requestedItems) {
      const product = productById.get(String(item.product_id));
      const quantity = Number(item.quantity);
      if (!product || !product.is_available || !Number.isInteger(quantity) || quantity < 1 || quantity > 99) {
        return json({ error: 'El carrito contiene un producto no disponible.' }, 400);
      }
      amount += Math.round(Number(product.price) * 100) * quantity;
    }
    if (!Number.isSafeInteger(amount) || amount < 1) return json({ error: 'Importe inválido.' }, 400);

    if (mode === 'checkout') {
      const origin = typeof body.origin === 'string' && /^https?:\/\//.test(body.origin)
        ? body.origin.replace(/\/$/, '')
        : null;
      if (!origin) return json({ error: 'Origen de Checkout inválido.' }, 400);

      const form = new URLSearchParams({
        mode: 'payment',
        success_url: `${origin}/?payment=success`,
        cancel_url: `${origin}/?payment=cancelled`,
        'metadata[user_id]': user.id,
      });
      requestedItems.forEach((item, index) => {
        const product = productById.get(String(item.product_id));
        form.set(`line_items[${index}][price_data][currency]`, currency);
        form.set(`line_items[${index}][price_data][unit_amount]`, String(Math.round(Number(product.price) * 100)));
        form.set(`line_items[${index}][price_data][product_data][name]`, String(product.name));
        form.set(`line_items[${index}][quantity]`, String(item.quantity));
      });

      const checkoutResponse = await fetch('https://api.stripe.com/v1/checkout/sessions', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${Deno.env.get('STRIPE_SECRET_KEY')}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: form,
      });
      const checkoutSession = await checkoutResponse.json();
      if (!checkoutResponse.ok) return json({ error: checkoutSession.error?.message ?? 'Stripe rechazó la sesión.' }, 502);
      return json({
        amount,
        session_id: checkoutSession.id,
        session_url: checkoutSession.url,
      });
    }

    const stripeResponse = await fetch('https://api.stripe.com/v1/payment_intents', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${Deno.env.get('STRIPE_SECRET_KEY')}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        amount: String(amount),
        currency,
        'automatic_payment_methods[enabled]': 'true',
        'metadata[user_id]': user.id,
      }),
    });
    const paymentIntent = await stripeResponse.json();
    if (!stripeResponse.ok) return json({ error: paymentIntent.error?.message ?? 'Stripe rechazó la solicitud.' }, 502);

    return json({
      amount,
      client_secret: paymentIntent.client_secret,
      payment_intent_id: paymentIntent.id,
    });
  } catch (error) {
    console.error(error);
    return json({ error: 'No se pudo crear el pago.' }, 500);
  }
});