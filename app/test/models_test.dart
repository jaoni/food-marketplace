// Each model is parsed from a real response saved from the backend, so these
// tests fail if the Dart models and the API's JSON ever drift apart.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_app/features/auth/data/user.dart';
import 'package:food_app/features/menu/data/menu.dart';
import 'package:food_app/features/orders/data/order.dart';
import 'package:food_app/features/orders/data/place_order_request.dart';
import 'package:food_app/features/restaurants/data/restaurant.dart';

import 'fixture.dart';

void main() {
  group('Restaurant', () {
    test('parses GET /restaurants', () {
      final restaurants = (fixture('restaurants') as List<dynamic>)
          .map((json) => Restaurant.fromJson(json as Map<String, dynamic>))
          .toList();

      expect(restaurants.map((r) => r.id), [1, 2, 3]);
      expect(restaurants.map((r) => r.name), ['Bella Napoli', 'Tokyo Bowl', 'Green Garden']);
      expect(restaurants.map((r) => r.isOpen), [true, true, false]);
    });

    test('parses GET /restaurants/:id', () {
      final restaurant = Restaurant.fromJson(fixture('restaurant') as Map<String, dynamic>);
      expect((restaurant.id, restaurant.name, restaurant.isOpen), (1, 'Bella Napoli', true));
    });
  });

  group('Menu', () {
    test('parses GET /restaurants/:id/menu, keeping prices as int cents', () {
      final menu = Menu.fromJson(fixture('menu') as Map<String, dynamic>);

      expect(menu.restaurantId, 1);
      expect(menu.categories.map((c) => c.name), ['Pizza', 'Drinks']);

      final margherita = menu.categories.first.items.first;
      expect(margherita.id, 1);
      expect(margherita.categoryId, 1);
      expect(margherita.name, 'Margherita');
      expect(margherita.description, 'Tomato, mozzarella, basil');
      expect(margherita.priceCents, 1050);
      expect(margherita.isAvailable, isTrue);

      final quattroFormaggi = menu.categories.first.items[2];
      expect(quattroFormaggi.name, 'Quattro Formaggi');
      expect(quattroFormaggi.isAvailable, isFalse);
    });
  });

  group('User and AuthSession', () {
    test('parses the login response', () {
      final session = AuthSession.fromJson(fixture('auth_response') as Map<String, dynamic>);

      expect(session.token, 'test-token-from-a-real-login');
      expect(session.user.id, 4);
      expect(session.user.email, 'alice@example.com');
      expect(session.user.role, UserRole.customer);
      expect(session.user.createdAt, DateTime.utc(2026, 10, 11, 22, 34, 11, 915));
    });

    test('parses GET /auth/me', () {
      final user = User.fromJson(fixture('user') as Map<String, dynamic>);
      expect((user.name, user.role), ('Alice Customer', UserRole.customer));
    });

    test('survives being saved and read back (toJson, then fromJson)', () {
      final session = AuthSession.fromJson(fixture('auth_response') as Map<String, dynamic>);
      final restored = AuthSession.fromJson(
        jsonDecode(jsonEncode(session.toJson())) as Map<String, dynamic>,
      );

      expect(restored.token, session.token);
      expect(restored.user.email, session.user.email);
      expect(restored.user.createdAt, session.user.createdAt);
    });

    test('reads snake_case roles', () {
      expect(UserRole.fromJson('restaurant_owner'), UserRole.restaurantOwner);
      expect(() => UserRole.fromJson('chef'), throwsFormatException);
    });
  });

  group('Orders', () {
    test('parses the answer to POST /orders', () {
      final order = OrderDetail.fromJson(fixture('order_created') as Map<String, dynamic>);

      expect(order.id, 24);
      expect(order.customerId, 4);
      expect(order.restaurantName, 'Bella Napoli');
      expect(order.status, OrderStatus.pending);
      expect(order.totalCents, 2450);
      expect(
        order.items.map((i) => (i.menuItemId, i.name, i.quantity, i.unitPriceCents, i.lineTotalCents)),
        [(1, 'Margherita', 2, 1050, 2100), (4, 'Lemonade', 1, 350, 350)],
      );

      final created = order.statusHistory.single;
      expect(created.fromStatus, isNull); // the event that created the order
      expect(created.toStatus, OrderStatus.pending);
      expect(created.changedBy, 4);
      expect(created.createdAt.isUtc, isTrue);
    });

    test('parses a delivered order with its whole history, including "picked_up"', () {
      final order = OrderDetail.fromJson(fixture('order_delivered') as Map<String, dynamic>);

      expect(order.statusHistory.map((e) => e.toStatus), [
        OrderStatus.pending,
        OrderStatus.accepted,
        OrderStatus.preparing,
        OrderStatus.ready,
        OrderStatus.pickedUp,
        OrderStatus.delivered,
      ]);
      expect(order.status, OrderStatus.delivered);
      expect(order.status.isFinal, isTrue);
    });

    test('parses GET /orders pages; the last page has no cursor', () {
      final page = OrdersPage.fromJson(fixture('orders_page') as Map<String, dynamic>);
      expect(page.orders.map((o) => o.id), [24, 23]);
      expect(page.orders[1].status, OrderStatus.cancelled);
      expect(page.nextCursor, 'MjM');

      final lastPage = OrdersPage.fromJson(fixture('orders_page_last') as Map<String, dynamic>);
      expect(lastPage.orders.single.id, 1);
      expect(lastPage.nextCursor, isNull);
    });

    test('accepts null where the backend can send null', () {
      final json = fixture('order_created') as Map<String, dynamic>;
      ((json['items'] as List<dynamic>).first as Map<String, dynamic>)['menuItemId'] = null; // item deleted later
      ((json['statusHistory'] as List<dynamic>).first as Map<String, dynamic>)['changedBy'] = null;

      final order = OrderDetail.fromJson(json);
      expect(order.items.first.menuItemId, isNull);
      expect(order.statusHistory.first.changedBy, isNull);
    });

    test('refuses an unknown status instead of guessing', () {
      final json = fixture('order_created') as Map<String, dynamic>;
      json['status'] = 'teleported';
      expect(() => OrderDetail.fromJson(json), throwsFormatException);
    });

    test('the POST /orders body has no prices', () {
      const request = PlaceOrderRequest(
        restaurantId: 1,
        items: [(menuItemId: 1, quantity: 2)],
        deliveryAddress: '12 Main St',
      );
      expect(request.toJson(), {
        'restaurantId': 1,
        'items': [
          {'menuItemId': 1, 'quantity': 2},
        ],
        'deliveryAddress': '12 Main St',
      });
    });
  });
}
