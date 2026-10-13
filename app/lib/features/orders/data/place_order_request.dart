/// The body of `POST /orders`. Note there are no prices: the server looks
/// them up itself and never trusts prices from the app.
class PlaceOrderRequest {
  const PlaceOrderRequest({
    required this.restaurantId,
    required this.items,
    required this.deliveryAddress,
  });

  final int restaurantId;
  final List<({int menuItemId, int quantity})> items;
  final String deliveryAddress;

  Map<String, dynamic> toJson() => {
        'restaurantId': restaurantId,
        'items': [
          for (final item in items) {'menuItemId': item.menuItemId, 'quantity': item.quantity},
        ],
        'deliveryAddress': deliveryAddress,
      };
}
