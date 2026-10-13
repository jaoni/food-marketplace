/// The order statuses from the backend's state machine (orderStateMachine.ts).
/// The JSON uses snake_case names, e.g. "picked_up".
enum OrderStatus {
  pending('pending'),
  accepted('accepted'),
  preparing('preparing'),
  ready('ready'),
  pickedUp('picked_up'),
  delivered('delivered'),
  cancelled('cancelled');

  const OrderStatus(this.json);
  final String json;

  /// Nothing can happen to an order after these.
  bool get isFinal => this == delivered || this == cancelled;

  static OrderStatus fromJson(String value) => values.firstWhere(
        (status) => status.json == value,
        orElse: () => throw FormatException('Unknown order status: $value'),
      );
}

/// An order as listed by `GET /orders` (no items or history).
class Order {
  Order.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        customerId = json['customerId'] as int,
        restaurantId = json['restaurantId'] as int,
        restaurantName = json['restaurantName'] as String,
        status = OrderStatus.fromJson(json['status'] as String),
        deliveryAddress = json['deliveryAddress'] as String,
        totalCents = json['totalCents'] as int,
        createdAt = DateTime.parse(json['createdAt'] as String),
        updatedAt = DateTime.parse(json['updatedAt'] as String);

  final int id;
  final int customerId;
  final int restaurantId;
  final String restaurantName;
  final OrderStatus status;
  final String deliveryAddress;
  final int totalCents; // calculated by the server, in cents
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// One order with its lines and status history, from `POST /orders`,
/// `GET /orders/:id` and `PATCH /orders/:id/status`.
class OrderDetail extends Order {
  OrderDetail.fromJson(super.json)
      : items = (json['items'] as List<dynamic>)
            .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        statusHistory = (json['statusHistory'] as List<dynamic>)
            .map((e) => OrderStatusEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
        super.fromJson();

  final List<OrderItem> items;
  final List<OrderStatusEvent> statusHistory;
}

/// One line of an order. `name` and `unitPriceCents` are the server's copies
/// from when the order was placed.
class OrderItem {
  OrderItem.fromJson(Map<String, dynamic> json)
      : menuItemId = json['menuItemId'] as int?,
        name = json['name'] as String,
        unitPriceCents = json['unitPriceCents'] as int,
        quantity = json['quantity'] as int,
        lineTotalCents = json['lineTotalCents'] as int;

  final int? menuItemId; // null if the menu item was deleted later
  final String name;
  final int unitPriceCents;
  final int quantity;
  final int lineTotalCents;
}

/// One status change. `fromStatus` is null for the event that created the order.
class OrderStatusEvent {
  OrderStatusEvent.fromJson(Map<String, dynamic> json)
      : fromStatus = json['fromStatus'] == null
            ? null
            : OrderStatus.fromJson(json['fromStatus'] as String),
        toStatus = OrderStatus.fromJson(json['toStatus'] as String),
        changedBy = json['changedBy'] as int?,
        createdAt = DateTime.parse(json['createdAt'] as String);

  final OrderStatus? fromStatus;
  final OrderStatus toStatus;
  final int? changedBy;
  final DateTime createdAt;
}

/// One page of `GET /orders`. `nextCursor` is null on the last page.
class OrdersPage {
  OrdersPage.fromJson(Map<String, dynamic> json)
      : orders = (json['orders'] as List<dynamic>)
            .map((o) => Order.fromJson(o as Map<String, dynamic>))
            .toList(),
        nextCursor = json['nextCursor'] as String?;

  final List<Order> orders;
  final String? nextCursor;
}
