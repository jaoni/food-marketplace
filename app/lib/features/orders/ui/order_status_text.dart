import '../data/order.dart';

/// Short label for a status, e.g. in the timeline and the orders list.
String statusLabel(OrderStatus status) => switch (status) {
      OrderStatus.pending => 'Placed',
      OrderStatus.accepted => 'Accepted',
      OrderStatus.preparing => 'Preparing',
      OrderStatus.ready => 'Ready for pickup',
      OrderStatus.pickedUp => 'On the way',
      OrderStatus.delivered => 'Delivered',
      OrderStatus.cancelled => 'Cancelled',
    };

/// One sentence explaining a status to the customer.
String statusDescription(OrderStatus status) => switch (status) {
      OrderStatus.pending => 'Waiting for the restaurant to accept your order.',
      OrderStatus.accepted => 'The restaurant accepted your order.',
      OrderStatus.preparing => 'Your food is being prepared.',
      OrderStatus.ready => 'Your food is ready and waiting for a courier.',
      OrderStatus.pickedUp => 'A courier is on the way with your order.',
      OrderStatus.delivered => 'Delivered. Enjoy your meal!',
      OrderStatus.cancelled => 'This order was cancelled.',
    };
