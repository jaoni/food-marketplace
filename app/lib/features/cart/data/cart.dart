/// One line in the cart. The price is a copy from the menu, used only for the
/// estimated total. The server sets the real price when the order is placed.
class CartLine {
  const CartLine({
    required this.menuItemId,
    required this.name,
    required this.priceCents,
    required this.quantity,
  });

  final int menuItemId;
  final String name;
  final int priceCents;
  final int quantity;

  int get lineTotalCents => priceCents * quantity;

  CartLine withQuantity(int quantity) =>
      CartLine(menuItemId: menuItemId, name: name, priceCents: priceCents, quantity: quantity);
}

/// The cart: items from one restaurant at a time. It only lives on the
/// device (in memory) until the order is placed.
class Cart {
  const Cart({this.restaurantId, this.restaurantName, this.lines = const []});

  final int? restaurantId;
  final String? restaurantName;
  final List<CartLine> lines;

  bool get isEmpty => lines.isEmpty;

  int get itemCount => lines.fold(0, (count, line) => count + line.quantity);

  /// Only an estimate: prices can change before the order reaches the server.
  int get estimatedTotalCents => lines.fold(0, (sum, line) => sum + line.lineTotalCents);
}
