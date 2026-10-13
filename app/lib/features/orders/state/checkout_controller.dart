import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_exception.dart';
import '../../cart/state/cart_controller.dart';
import '../data/order.dart';
import '../data/orders_repository.dart';
import '../data/place_order_request.dart';

class CheckoutState {
  const CheckoutState({this.sending = false, this.error, this.attempt});

  /// A request is on its way. The "Place order" button is disabled meanwhile.
  final bool sending;

  /// Why the last attempt failed, if it did.
  final Object? error;

  /// The attempt that hasn't succeeded yet. Retrying it reuses its key.
  final CheckoutAttempt? attempt;
}

/// One order attempt: the Idempotency-Key, and the exact request it was made for.
class CheckoutAttempt {
  const CheckoutAttempt({required this.idempotencyKey, required this.requestJson});

  final String idempotencyKey;
  final String requestJson;
}

/// How long to wait before automatic retry number n (n = 1, 2, ...). Tests set it to zero.
final checkoutRetryDelayProvider = Provider<Duration>((ref) => const Duration(seconds: 1));

class CheckoutController extends Notifier<CheckoutState> {
  /// Tries per tap: the first one plus 2 automatic retries.
  static const maxTries = 3;

  @override
  CheckoutState build() => const CheckoutState();

  /// Sends the cart as an order. Returns the server's order, or null if it
  /// failed (then [CheckoutState.error] says why).
  Future<OrderDetail?> placeOrder(String deliveryAddress) async {
    if (state.sending) return null; // already sending: ignore extra taps

    final cart = ref.read(cartProvider);
    final request = PlaceOrderRequest(
      restaurantId: cart.restaurantId!,
      items: [for (final line in cart.lines) (menuItemId: line.menuItemId, quantity: line.quantity)],
      deliveryAddress: deliveryAddress,
    );

    // The Idempotency-Key is made once per attempt, when "Place order" is
    // tapped. If the previous attempt failed and the order details are exactly
    // the same, this is a retry of that attempt, so it keeps the same key.
    // (If that attempt actually reached the server, the backend recognizes the
    // key and returns the order it created instead of making a second one.)
    final requestJson = jsonEncode(request.toJson());
    final attempt = state.attempt?.requestJson == requestJson
        ? state.attempt!
        : CheckoutAttempt(idempotencyKey: const Uuid().v4(), requestJson: requestJson);

    state = CheckoutState(sending: true, attempt: attempt);
    try {
      final order = await _sendWithRetries(request, attempt.idempotencyKey);
      ref.read(cartProvider.notifier).clear();
      state = const CheckoutState(); // done: the next order gets a new key
      return order;
    } catch (error) {
      state = CheckoutState(error: error, attempt: attempt); // keep the key for "Try again"
      return null;
    }
  }

  /// Retries automatically when there was no answer (timeout, network error),
  /// always with the same key.
  Future<OrderDetail> _sendWithRetries(PlaceOrderRequest request, String idempotencyKey) async {
    final repository = ref.read(ordersRepositoryProvider);
    for (var tryNumber = 1; ; tryNumber++) {
      try {
        return await repository.placeOrder(request, idempotencyKey: idempotencyKey);
      } on NetworkException {
        if (tryNumber == maxTries) rethrow;
        await Future<void>.delayed(ref.read(checkoutRetryDelayProvider) * tryNumber);
      }
    }
  }
}

final checkoutControllerProvider =
    NotifierProvider<CheckoutController, CheckoutState>(CheckoutController.new);
