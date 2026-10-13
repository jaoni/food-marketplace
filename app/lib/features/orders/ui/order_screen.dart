import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_format.dart';
import '../../../core/errors/error_message.dart';
import '../../../core/money.dart';
import '../../../core/ui/async_value_view.dart';
import '../../auth/state/auth_controller.dart';
import '../data/order.dart';
import '../state/order_detail_controller.dart';
import 'order_status_text.dart';

/// One order's live status. Watching [orderDetailProvider] starts the polling;
/// leaving the screen stops it.
class OrderScreen extends ConsumerWidget {
  const OrderScreen({super.key, required this.orderId, this.placedOrder});

  final int orderId;

  /// The server's answer to `POST /orders`, passed along right after checkout.
  final OrderDetail? placedOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(orderDetailProvider(orderId));
    final justPlaced = placedOrder != null;

    return Scaffold(
      appBar: AppBar(title: Text('Order #$orderId')),
      // While the first fetch runs after checkout, show what POST /orders returned.
      body: !value.hasValue && placedOrder != null
          ? _OrderDetails(order: placedOrder!, justPlaced: justPlaced)
          : AsyncValueView(
              value: value,
              onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
              data: (order) => _OrderDetails(order: order, justPlaced: justPlaced),
            ),
    );
  }
}

class _OrderDetails extends ConsumerWidget {
  const _OrderDetails({required this.order, required this.justPlaced});

  final OrderDetail order;
  final bool justPlaced;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final userId = ref.watch(authControllerProvider.select((session) => session.value?.user.id));
    final canCancel = order.status == OrderStatus.pending && order.customerId == userId;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (justPlaced) ...[
          const _Banner(icon: Icons.check_circle, text: 'Order placed!'),
          const SizedBox(height: 16),
        ],
        Text(order.restaurantName, style: text.titleMedium),
        const SizedBox(height: 4),
        Text(statusLabel(order.status), style: text.headlineMedium),
        Text(statusDescription(order.status)),
        if (!order.status.isFinal) ...[
          const SizedBox(height: 4),
          Text('Updates automatically', style: text.bodySmall),
        ],
        const SizedBox(height: 24),
        Text('Timeline', style: text.titleMedium),
        const SizedBox(height: 8),
        for (final (index, event) in order.statusHistory.indexed)
          _TimelineEntry(event: event, isLast: index == order.statusHistory.length - 1),
        const SizedBox(height: 16),
        Text('Items', style: text.titleMedium),
        for (final item in order.items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${item.quantity} × ${item.name}'),
            trailing: Text(formatCents(item.lineTotalCents)),
          ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Total', style: text.titleMedium),
          subtitle: const Text('Calculated by the server'),
          trailing: Text(formatCents(order.totalCents), style: text.titleMedium),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.place_outlined),
          title: Text(order.deliveryAddress),
        ),
        if (canCancel) ...[
          const SizedBox(height: 8),
          _CancelButton(orderId: order.id),
        ],
      ],
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({required this.event, required this.isLast});

  final OrderStatusEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cancelled = event.toStatus == OrderStatus.cancelled;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A dot per event, joined by a line.
          Column(
            children: [
              Icon(
                cancelled ? Icons.cancel : Icons.check_circle,
                size: 20,
                color: cancelled ? colors.error : colors.primary,
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: colors.outlineVariant)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(statusLabel(event.toStatus), style: Theme.of(context).textTheme.bodyLarge),
                  Text(formatDateTime(context, event.createdAt), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelButton extends ConsumerStatefulWidget {
  const _CancelButton({required this.orderId});

  final int orderId;

  @override
  ConsumerState<_CancelButton> createState() => _CancelButtonState();
}

class _CancelButtonState extends ConsumerState<_CancelButton> {
  bool _busy = false;

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text("The restaurant hasn't accepted it yet, so you can still cancel."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep order')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel order')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final controller = ref.read(orderDetailProvider(widget.orderId).notifier);
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      final result = await controller.cancel();
      final status = ref.read(orderDetailProvider(widget.orderId)).value?.status;
      message = switch (result) {
        CancelResult.cancelled => 'Order cancelled.',
        CancelResult.tooLate => status == null
            ? 'Too late to cancel this order.'
            : 'Too late to cancel: the order is already ${statusLabel(status).toLowerCase()}.',
      };
    } catch (e) {
      message = errorMessage(e);
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.cancel_outlined),
      label: const Text('Cancel order'),
      onPressed: _busy ? null : _cancel,
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, color: colors.onPrimaryContainer),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: colors.onPrimaryContainer)),
        ],
      ),
    );
  }
}
