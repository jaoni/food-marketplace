import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/date_format.dart';
import '../../../core/errors/error_message.dart';
import '../../../core/money.dart';
import '../../../core/ui/async_value_view.dart';
import '../data/order.dart';
import '../state/orders_list_controller.dart';
import 'order_status_text.dart';

class OrdersListScreen extends ConsumerWidget {
  const OrdersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
      body: AsyncValueView(
        value: ref.watch(ordersListProvider),
        onRetry: () => ref.invalidate(ordersListProvider),
        data: (list) => RefreshIndicator(
          // Pull to refresh: load the first page again.
          onRefresh: () => ref.refresh(ordersListProvider.future),
          child: list.orders.isEmpty
              ? ListView(
                  // Scrollable even when empty, so pull to refresh still works.
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    MessageView(
                      icon: Icons.receipt_long_outlined,
                      message: 'No orders yet.',
                      actionLabel: 'Browse restaurants',
                      onAction: () => context.go('/'),
                    ),
                  ],
                )
              : _OrdersList(list: list),
        ),
      ),
    );
  }
}

class _OrdersList extends ConsumerWidget {
  const _OrdersList({required this.list});

  final OrdersListState list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(ordersListProvider.notifier);
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      // One extra row at the end: "loading more", an error, or "that's all".
      itemCount: list.orders.length + 1,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index < list.orders.length) {
          return OrderTile(order: list.orders[index]);
        }
        if (list.loadMoreError != null) {
          return ListTile(
            title: Text(errorMessage(list.loadMoreError!)),
            trailing: TextButton(onPressed: controller.loadMore, child: const Text('Try again')),
          );
        }
        if (list.hasMore) {
          // This row is about to scroll into view: fetch the next page.
          // (After this frame, because state can't change while building.)
          WidgetsBinding.instance.addPostFrameCallback((_) => controller.loadMore());
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text("That's all your orders")),
        );
      },
    );
  }
}

class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text('Order #${order.id} · ${order.restaurantName}'),
      subtitle: Text('${formatDateTime(context, order.createdAt)} · ${statusLabel(order.status)}'),
      trailing: Text(formatCents(order.totalCents)),
      onTap: () => context.go('/orders/${order.id}'),
    );
  }
}
