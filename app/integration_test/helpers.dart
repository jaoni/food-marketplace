import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_app/core/config.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// Keeps drawing frames until [finder] finds something, then lets running
/// animations (like a page sliding in) finish. Needed because the app talks
/// to the real backend, so data arrives after a short delay.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Timed out waiting for $finder');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 10),
  );
}

/// The IconButton that has this tooltip (e.g. "Add Margherita").
IconButton iconButtonWithTooltip(WidgetTester tester, String tooltip) {
  return tester.widget<IconButton>(
    find.ancestor(of: find.byTooltip(tooltip), matching: find.byType(IconButton)),
  );
}

/// Fills in the login screen (already open) and logs in. Seed users all use password123.
Future<void> logIn(WidgetTester tester, String email) async {
  await waitFor(tester, find.widgetWithText(FilledButton, 'Log in'));
  await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
  await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password123');
  await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
}

/// From the restaurant list: orders one Margherita through the app, logging
/// in as Alice if needed. Ends on the order screen and returns the order id.
Future<int> placeOrderThroughApp(WidgetTester tester) async {
  await waitFor(tester, find.text('Bella Napoli'));
  await tester.tap(find.text('Bella Napoli'));
  await waitFor(tester, find.text('Margherita'));
  await tester.tap(find.byTooltip('Add Margherita'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Cart'));
  await waitFor(tester, find.text('Your cart'));
  if (find.text('Log in to place your order').evaluate().isNotEmpty) {
    await tester.tap(find.text('Log in to place your order'));
    await logIn(tester, 'alice@example.com');
  }
  await waitFor(tester, find.text('Place order'));
  await tester.enterText(find.widgetWithText(TextFormField, 'Delivery address'), '12 Main St');
  await tester.tap(find.text('Place order'));
  await waitFor(tester, find.text('Order placed!'), timeout: const Duration(seconds: 30));
  final title = tester.widget<Text>(find.textContaining('Order #')).data!;
  return int.parse(title.replaceFirst('Order #', ''));
}

/// Talks to the backend directly, playing the restaurant or the courier.
class BackendAs {
  BackendAs._(this._token);

  static Future<BackendAs> login(String email) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': 'password123'}),
    );
    return BackendAs._((jsonDecode(response.body) as Map<String, dynamic>)['token'] as String);
  }

  final String _token;

  Map<String, String> get _headers =>
      {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'};

  /// Places an order (one Miso Soup at Tokyo Bowl) and returns its id.
  Future<int> placeOrder() async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/orders'),
      headers: {..._headers, 'Idempotency-Key': const Uuid().v4()},
      body: jsonEncode({
        'restaurantId': 2,
        'items': [
          {'menuItemId': 9, 'quantity': 1},
        ],
        'deliveryAddress': '1 Test Street',
      }),
    );
    expect(response.statusCode, 201, reason: response.body);
    return (jsonDecode(response.body) as Map<String, dynamic>)['id'] as int;
  }

  /// The ids of all of this user's orders, newest first (all pages of GET /orders).
  Future<List<int>> allOrderIds() async {
    final ids = <int>[];
    String? cursor;
    do {
      final query = {'limit': '100', if (cursor != null) 'cursor': cursor};
      final response = await http.get(
        Uri.parse('$apiBaseUrl/orders').replace(queryParameters: query),
        headers: _headers,
      );
      final page = jsonDecode(response.body) as Map<String, dynamic>;
      ids.addAll([for (final order in page['orders'] as List<dynamic>) (order as Map<String, dynamic>)['id'] as int]);
      cursor = page['nextCursor'] as String?;
    } while (cursor != null);
    return ids;
  }

  Future<void> setStatus(int orderId, String status) async {
    final response = await http.patch(
      Uri.parse('$apiBaseUrl/orders/$orderId/status'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    expect(response.statusCode, 200, reason: response.body);
  }
}
