import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_app/core/api/api_client.dart';
import 'package:food_app/core/api/api_exception.dart';
import 'package:food_app/core/api/api_providers.dart';
import 'package:food_app/features/cart/state/cart_controller.dart';
import 'package:food_app/features/menu/data/menu.dart';
import 'package:food_app/features/orders/state/checkout_controller.dart';
import 'package:food_app/features/restaurants/data/restaurant.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../fixture.dart';

void main() {
  // The real answer of POST /orders, saved in test/fixtures/.
  http.Response created() =>
      http.Response(fixtureText('order_created'), 201, headers: {'content-type': 'application/json'});

  const restaurant = Restaurant(id: 1, name: 'Bella Napoli', isOpen: true);
  const margherita = MenuItem(
    id: 1,
    categoryId: 1,
    name: 'Margherita',
    description: '',
    priceCents: 1050,
    isAvailable: true,
  );

  /// The app's providers, but every HTTP request goes to [handler] instead of
  /// the network. The cart already holds one Margherita.
  ProviderContainer appWith(MockClientHandler handler) {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(ApiClient(
          baseUrl: 'http://api.test',
          httpClient: MockClient(handler),
          timeout: const Duration(milliseconds: 100),
        )),
        checkoutRetryDelayProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(container.dispose);
    container.read(cartProvider.notifier).add(restaurant, margherita);
    return container;
  }

  test('a retry after a timeout sends the same Idempotency-Key', () async {
    final keys = <String?>[];
    final container = appWith((request) async {
      keys.add(request.headers['Idempotency-Key']);
      if (keys.length == 1) {
        // First try: the server answers too slowly, so the app stops waiting.
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      return created();
    });

    final order = await container.read(checkoutControllerProvider.notifier).placeOrder('12 Main St');

    expect(order, isNotNull);
    expect(keys, hasLength(2));
    expect(keys[0], isNotNull);
    expect(keys[1], keys[0]);
  });

  test('a retry after a network error sends the same Idempotency-Key', () async {
    final keys = <String?>[];
    final container = appWith((request) async {
      keys.add(request.headers['Idempotency-Key']);
      if (keys.length == 1) throw http.ClientException('Connection reset by peer');
      return created();
    });

    final order = await container.read(checkoutControllerProvider.notifier).placeOrder('12 Main St');

    expect(order, isNotNull);
    expect(keys, [keys.first, keys.first]);
  });

  test('"Try again" after all retries failed reuses the key; the next order gets a new one',
      () async {
    final keys = <String?>[];
    var serverDown = true;
    final container = appWith((request) async {
      keys.add(request.headers['Idempotency-Key']);
      if (serverDown) throw http.ClientException('Connection refused');
      return created();
    });
    final checkout = container.read(checkoutControllerProvider.notifier);

    // Three tries, all fail: the screen shows the error and "Try again".
    expect(await checkout.placeOrder('12 Main St'), isNull);
    expect(container.read(checkoutControllerProvider).error, isA<NetworkException>());
    expect(keys, hasLength(CheckoutController.maxTries));

    // The user taps "Try again" once the connection is back.
    serverDown = false;
    expect(await checkout.placeOrder('12 Main St'), isNotNull);
    expect(keys, hasLength(CheckoutController.maxTries + 1));
    expect(keys.toSet(), hasLength(1)); // one attempt, one key

    // Success empties the cart. The next order is a new attempt with a new key.
    expect(container.read(cartProvider).isEmpty, isTrue);
    container.read(cartProvider.notifier).add(restaurant, margherita);
    await checkout.placeOrder('12 Main St');
    expect(keys.last, isNot(keys.first));
  });

  test('changing the order details after a failure makes a new attempt with a new key', () async {
    final keys = <String?>[];
    final container = appWith((request) async {
      keys.add(request.headers['Idempotency-Key']);
      return http.Response('{"error":"Something broke"}', 500);
    });
    final checkout = container.read(checkoutControllerProvider.notifier);

    await checkout.placeOrder('12 Main St'); // 500: not retried automatically
    await checkout.placeOrder('12 Main St'); // "Try again": same order, same key
    await checkout.placeOrder('99 Other Road'); // different address: a different order

    expect(keys, hasLength(3));
    expect(keys[1], keys[0]);
    expect(keys[2], isNot(keys[0]));
  });
}
