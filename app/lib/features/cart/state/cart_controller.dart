import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../menu/data/menu.dart';
import '../../restaurants/data/restaurant.dart';
import '../data/cart.dart';

class CartController extends Notifier<Cart> {
  /// The backend accepts a quantity of 1 to 99 per item.
  static const maxQuantity = 99;

  @override
  Cart build() => const Cart();

  /// True if the cart holds items from another restaurant. Adding this item
  /// would then need the cart to be cleared first (one restaurant at a time).
  bool isFromOtherRestaurant(int restaurantId) =>
      !state.isEmpty && state.restaurantId != restaurantId;

  /// Adds one of [item]. If the cart holds another restaurant's items, call
  /// [clear] first (after asking the user).
  void add(Restaurant restaurant, MenuItem item) {
    if (isFromOtherRestaurant(restaurant.id)) {
      throw StateError('The cart holds items from another restaurant');
    }
    final lines = [...state.lines];
    final index = lines.indexWhere((line) => line.menuItemId == item.id);
    if (index == -1) {
      lines.add(CartLine(menuItemId: item.id, name: item.name, priceCents: item.priceCents, quantity: 1));
    } else if (lines[index].quantity < maxQuantity) {
      lines[index] = lines[index].withQuantity(lines[index].quantity + 1);
    }
    state = Cart(restaurantId: restaurant.id, restaurantName: restaurant.name, lines: lines);
  }

  /// Sets a line's quantity. 0 removes the line.
  void setQuantity(int menuItemId, int quantity) {
    final lines = [
      for (final line in state.lines)
        if (line.menuItemId != menuItemId)
          line
        else if (quantity > 0)
          line.withQuantity(quantity.clamp(1, maxQuantity)),
    ];
    state = lines.isEmpty
        ? const Cart()
        : Cart(restaurantId: state.restaurantId, restaurantName: state.restaurantName, lines: lines);
  }

  void clear() => state = const Cart();
}

final cartProvider = NotifierProvider<CartController, Cart>(CartController.new);
