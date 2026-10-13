import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money.dart';
import '../../../core/ui/async_value_view.dart';
import '../../orders/ui/checkout_section.dart';
import '../data/cart.dart';
import '../state/cart_controller.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final controller = ref.read(cartProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your cart'),
        actions: [
          if (!cart.isEmpty) TextButton(onPressed: controller.clear, child: const Text('Clear')),
        ],
      ),
      body: cart.isEmpty
          ? MessageView(
              icon: Icons.shopping_cart_outlined,
              message: 'Your cart is empty.',
              actionLabel: 'Browse restaurants',
              onAction: () => context.go('/'),
            )
          : ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(cart.restaurantName!),
                ),
                const Divider(height: 1),
                for (final line in cart.lines)
                  _CartLineTile(
                    line: line,
                    onQuantityChanged: (quantity) => controller.setQuantity(line.menuItemId, quantity),
                  ),
                const Divider(height: 1),
                _EstimatedTotal(cents: cart.estimatedTotalCents),
                const CheckoutSection(),
              ],
            ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({required this.line, required this.onQuantityChanged});

  final CartLine line;
  final ValueChanged<int> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(line.name),
      subtitle: Text('${formatCents(line.priceCents)} each'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'One less ${line.name}',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => onQuantityChanged(line.quantity - 1), // 0 removes it
          ),
          Text('${line.quantity}', style: Theme.of(context).textTheme.titleMedium),
          IconButton(
            tooltip: 'One more ${line.name}',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: line.quantity < CartController.maxQuantity
                ? () => onQuantityChanged(line.quantity + 1)
                : null,
          ),
          SizedBox(
            width: 72,
            child: Text(formatCents(line.lineTotalCents), textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

class _EstimatedTotal extends StatelessWidget {
  const _EstimatedTotal({required this.cents});

  final int cents;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Estimated total', style: text.titleMedium),
              const Spacer(),
              Text(formatCents(cents), style: text.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'The final price is calculated by our server when you place the order.',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}
