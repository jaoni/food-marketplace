import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../core/ui/async_value_view.dart';
import '../../cart/ui/add_to_cart.dart';
import '../../cart/ui/cart_button.dart';
import '../data/menu.dart';
import '../state/menu_providers.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key, required this.restaurantId});

  final int restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(restaurantMenuProvider(restaurantId));
    return Scaffold(
      appBar: AppBar(
        title: Text(value.value?.restaurant.name ?? 'Menu'),
        actions: const [CartButton()],
      ),
      body: AsyncValueView(
        value: value,
        onRetry: () => ref.invalidate(restaurantMenuProvider(restaurantId)),
        data: (data) => _MenuList(
          data: data,
          onAdd: (item) => addToCart(context, ref, data.restaurant, item),
        ),
      ),
    );
  }
}

class _MenuList extends StatelessWidget {
  const _MenuList({required this.data, required this.onAdd});

  final RestaurantMenu data;
  final void Function(MenuItem item) onAdd;

  @override
  Widget build(BuildContext context) {
    final restaurant = data.restaurant;
    final categories = data.menu.categories.where((c) => c.items.isNotEmpty).toList();
    if (categories.isEmpty) {
      return const MessageView(icon: Icons.restaurant_menu, message: 'No dishes on the menu yet.');
    }

    return ListView(
      children: [
        if (!restaurant.isOpen)
          _ClosedBanner(message: "${restaurant.name} is closed right now. You can look, but you can't order."),
        for (final category in categories) ...[
          _CategoryHeader(name: category.name),
          for (final item in category.items)
            MenuItemTile(
              item: item,
              // null disables the button: sold out, or the restaurant is closed.
              onAdd: restaurant.isOpen && item.isAvailable ? () => onAdd(item) : null,
            ),
        ],
      ],
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(name, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class _ClosedBanner extends StatelessWidget {
  const _ClosedBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: colors.errorContainer,
      padding: const EdgeInsets.all(16),
      child: Text(message, style: TextStyle(color: colors.onErrorContainer)),
    );
  }
}

class MenuItemTile extends StatelessWidget {
  const MenuItemTile({super.key, required this.item, required this.onAdd});

  final MenuItem item;

  /// Called when "+" is tapped. null means the item can't be added.
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (item.description.isNotEmpty) item.description,
      if (!item.isAvailable) 'Sold out',
    ];

    final tile = ListTile(
      title: Text(item.name),
      subtitle: details.isEmpty ? null : Text(details.join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatCents(item.priceCents)),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: onAdd,
            tooltip: 'Add ${item.name}',
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );

    // Sold-out items are greyed out.
    return item.isAvailable ? tile : Opacity(opacity: 0.4, child: tile);
  }
}
