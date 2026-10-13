import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import 'order.dart';
import 'place_order_request.dart';

class OrdersRepository {
  OrdersRepository(this._api);

  final ApiClient _api;

  /// `POST /orders`. Sending the same [idempotencyKey] again returns the order
  /// that was already created instead of making a second one.
  Future<OrderDetail> placeOrder(PlaceOrderRequest request, {required String idempotencyKey}) async {
    final json = await _api.post(
      '/orders',
      body: request.toJson(),
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return OrderDetail.fromJson(json as Map<String, dynamic>);
  }

  /// `GET /orders`: one page of my orders, newest first. Pass the previous
  /// page's `nextCursor` to get the page after it.
  Future<OrdersPage> getOrders({String? cursor, required int limit}) async {
    final json = await _api.get('/orders', query: {
      'limit': '$limit',
      if (cursor != null) 'cursor': cursor,
    });
    return OrdersPage.fromJson(json as Map<String, dynamic>);
  }

  /// `GET /orders/:id`: one order with its items and status history.
  Future<OrderDetail> getOrder(int id) async {
    final json = await _api.get('/orders/$id');
    return OrderDetail.fromJson(json as Map<String, dynamic>);
  }

  /// `PATCH /orders/:id/status`. A customer may only cancel a pending order.
  Future<OrderDetail> cancelOrder(int id) async {
    final json = await _api.patch('/orders/$id/status', body: {'status': OrderStatus.cancelled.json});
    return OrderDetail.fromJson(json as Map<String, dynamic>);
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(ref.watch(apiClientProvider));
});
