import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/state/auth_controller.dart';
import '../data/order.dart';
import '../data/orders_repository.dart';

class OrdersListState {
  const OrdersListState({
    required this.orders,
    required this.nextCursor,
    this.loadingMore = false,
    this.loadMoreError,
  });

  /// All pages loaded so far, newest first.
  final List<Order> orders;

  /// Where the next page starts. null: this was the last page.
  final String? nextCursor;

  final bool loadingMore;
  final Object? loadMoreError;

  bool get hasMore => nextCursor != null;
}

/// My orders, loaded one page at a time as the list is scrolled.
class OrdersListController extends AsyncNotifier<OrdersListState> {
  static const pageSize = 20;

  OrdersRepository get _repository => ref.read(ordersRepositoryProvider);

  /// The first page. Pull to refresh runs this again (`ref.refresh`).
  @override
  Future<OrdersListState> build() async {
    // Someone else logged in: their list.
    ref.watch(authControllerProvider.select((session) => session.value?.token));
    final page = await _repository.getOrders(limit: pageSize);
    return OrdersListState(orders: page.orders, nextCursor: page.nextCursor);
  }

  /// Loads the next page. Does nothing if there is none, or one is already loading.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncData(OrdersListState(orders: current.orders, nextCursor: current.nextCursor, loadingMore: true));
    try {
      final page = await _repository.getOrders(cursor: current.nextCursor, limit: pageSize);
      if (!ref.mounted) return;
      state = AsyncData(OrdersListState(
        orders: [...current.orders, ...page.orders],
        nextCursor: page.nextCursor,
      ));
    } catch (error) {
      if (!ref.mounted) return;
      // Keep the pages we have; the list shows a "Try again" row at the end.
      state = AsyncData(OrdersListState(
        orders: current.orders,
        nextCursor: current.nextCursor,
        loadMoreError: error,
      ));
    }
  }
}

final ordersListProvider =
    AsyncNotifierProvider.autoDispose<OrdersListController, OrdersListState>(OrdersListController.new);
