import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../data/order.dart';
import '../data/orders_repository.dart';

/// How long to wait between fetches of an order that's still in progress.
final orderPollIntervalProvider = Provider<Duration>((ref) => const Duration(seconds: 5));

enum CancelResult {
  cancelled,

  /// The order had already moved on (e.g. the restaurant accepted it).
  tooLate,
}

/// One order, kept up to date. While it isn't delivered or cancelled, it's
/// fetched again every 5 seconds. Polling stops when the order is finished,
/// or when the screen closes: the provider is autoDispose, so it's disposed
/// once nothing watches it, and that cancels the timer.
class OrderDetailController extends AsyncNotifier<OrderDetail> {
  OrderDetailController(this.orderId);

  final int orderId;
  Timer? _nextFetch;

  OrdersRepository get _repository => ref.read(ordersRepositoryProvider);

  @override
  Future<OrderDetail> build() async {
    ref.onDispose(() => _nextFetch?.cancel());
    final order = await _repository.getOrder(orderId);
    _scheduleNextFetch(order);
    return order;
  }

  void _scheduleNextFetch(OrderDetail order) {
    _nextFetch?.cancel();
    if (order.status.isFinal) return; // nothing will change anymore
    _nextFetch = Timer(ref.read(orderPollIntervalProvider), _refresh);
  }

  Future<void> _refresh() async {
    try {
      final order = await _repository.getOrder(orderId);
      if (!ref.mounted) return; // the screen closed meanwhile
      state = AsyncData(order);
      _scheduleNextFetch(order);
    } catch (_) {
      // Keep showing what we have and try again later. (A 401 is handled by
      // the API client: it logs out, and the login screen replaces this one.)
      if (ref.mounted) _scheduleNextFetch(state.requireValue);
    }
  }

  /// Cancels the order. Customers may only cancel while it's pending.
  Future<CancelResult> cancel() async {
    try {
      final order = await _repository.cancelOrder(orderId);
      if (ref.mounted) {
        state = AsyncData(order);
        _scheduleNextFetch(order); // cancelled is final, so this stops polling
      }
      return CancelResult.cancelled;
    } on ApiException catch (e) {
      // 409: the order is past the point where it can be cancelled. A
      // customer can also get 403 when the restaurant accepted it first.
      // Either way, load the order to show its real status.
      if (e.statusCode == 409 || e.statusCode == 403) {
        await _refresh();
        return CancelResult.tooLate;
      }
      rethrow;
    }
  }
}

final orderDetailProvider =
    AsyncNotifierProvider.autoDispose.family<OrderDetailController, OrderDetail, int>(
  OrderDetailController.new,
);
