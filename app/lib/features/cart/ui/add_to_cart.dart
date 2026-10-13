import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../menu/data/menu.dart';
import '../../restaurants/data/restaurant.dart';
import '../state/cart_controller.dart';

/// Adds [item] to the cart. If the cart holds another restaurant's items,
/// asks whether to clear it first.
Future<void> addToCart(
  BuildContext context,
  WidgetRef ref,
  Restaurant restaurant,
  MenuItem item,
) async {
  final cart = ref.read(cartProvider.notifier);

  if (cart.isFromOtherRestaurant(restaurant.id)) {
    final otherRestaurant = ref.read(cartProvider).restaurantName;
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a new cart?'),
        content: Text(
          'Your cart has items from $otherRestaurant. You can order from one '
          'restaurant at a time. Clear the cart and add ${item.name}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear cart')),
        ],
      ),
    );
    if (clear != true) return;
    cart.clear();
  }

  cart.add(restaurant, item);
  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Added ${item.name}'), duration: const Duration(seconds: 1)));
  }
}
