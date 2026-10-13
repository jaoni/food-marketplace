// Runs the real app on a simulator against the running backend (seed data):
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/orders_list_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_app/features/orders/state/orders_list_controller.dart';
import 'package:food_app/features/orders/ui/orders_list_screen.dart';
import 'package:food_app/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('my orders: infinite scroll until nextCursor is null, and pull to refresh',
      (tester) async {
    // Make sure Alice has more than two pages of orders.
    final alice = await BackendAs.login('alice@example.com');
    var ids = await alice.allOrderIds();
    while (ids.length < 45) {
      await alice.placeOrder();
      ids = await alice.allOrderIds();
    }

    app.main();
    await waitFor(tester, find.text('Bella Napoli'));
    await tester.tap(find.byTooltip('My orders'));
    await waitFor(tester, find.byType(OrdersListScreen));
    if (find.widgetWithText(FilledButton, 'Log in').evaluate().isNotEmpty) {
      await logIn(tester, 'alice@example.com');
    }
    // The newest order is at the top. (The trailing space stops "#4" matching "#45".)
    await waitFor(tester, find.textContaining('Order #${ids.first} '));
    await binding.takeScreenshot('orders_list_top');

    OrdersListState listState() => ProviderScope.containerOf(tester.element(find.byType(OrdersListScreen)))
        .read(ordersListProvider)
        .requireValue;
    expect(listState().orders, hasLength(OrdersListController.pageSize)); // first page only

    // Keep scrolling down; each time the end comes near, the next page loads.
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (find.text("That's all your orders").evaluate().isEmpty) {
      expect(DateTime.now().isBefore(deadline), isTrue, reason: 'never reached the end of the list');
      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
    }
    await binding.takeScreenshot('orders_list_end');

    // Every order loaded once, newest first, exactly like the API's own list.
    expect(listState().orders.map((order) => order.id).toList(), ids);
    expect(listState().hasMore, isFalse);

    // Pull to refresh: a new order (placed elsewhere) appears at the top.
    final newId = await alice.placeOrder();
    await tester.fling(find.byType(ListView), const Offset(0, 30000), 10000); // back to the top
    await tester.pumpAndSettle();
    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000); // pull down
    await waitFor(tester, find.textContaining('Order #$newId '));
    expect(listState().orders.first.id, newId);
    expect(listState().orders, hasLength(OrdersListController.pageSize)); // starts over at page 1
  });
}
