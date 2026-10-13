// Runs the real app on a simulator against the running backend (seed data).
// The test also plays the restaurant and the courier through the API.
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/order_status_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_app/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const poll = Duration(seconds: 15); // the app checks every 5 s

  testWidgets('the status updates by itself and the timeline grows until delivered',
      (tester) async {
    app.main();
    final orderId = await placeOrderThroughApp(tester);
    await waitFor(tester, find.text('Waiting for the restaurant to accept your order.'));
    expect(find.text('Cancel order'), findsOneWidget);

    final restaurant = await BackendAs.login('owner1@example.com');
    final courier = await BackendAs.login('courier@example.com');

    await restaurant.setStatus(orderId, 'accepted');
    await waitFor(tester, find.text('The restaurant accepted your order.'), timeout: poll);
    expect(find.text('Cancel order'), findsNothing); // only while pending

    await restaurant.setStatus(orderId, 'preparing');
    await restaurant.setStatus(orderId, 'ready');
    await courier.setStatus(orderId, 'picked_up');
    await courier.setStatus(orderId, 'delivered');
    await waitFor(tester, find.text('Delivered. Enjoy your meal!'), timeout: poll);
    expect(find.text('Updates automatically'), findsNothing); // final: no more polling

    // Timeline: Placed, Accepted, Preparing, Ready for pickup, On the way, Delivered.
    for (final label in ['Placed', 'Preparing', 'Ready for pickup', 'On the way']) {
      expect(find.text(label), findsOneWidget);
    }
    await binding.takeScreenshot('order_delivered');
  });

  testWidgets('a pending order can be cancelled', (tester) async {
    app.main();
    await placeOrderThroughApp(tester);
    await waitFor(tester, find.text('Waiting for the restaurant to accept your order.'));

    // The button is at the bottom of the screen; scroll to it first.
    await tester.ensureVisible(find.text('Cancel order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel order'));
    await waitFor(tester, find.text('Cancel this order?'));
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel order'));
    await waitFor(tester, find.text('This order was cancelled.'));
    expect(find.text('Order cancelled.'), findsOneWidget); // SnackBar
    expect(find.text('Cancel order'), findsNothing);
  });

  testWidgets('cancelling too late (409) shows the real status and a message', (tester) async {
    app.main();
    final orderId = await placeOrderThroughApp(tester);
    await waitFor(tester, find.text('Waiting for the restaurant to accept your order.'));

    // Behind the app's back (before its next check), the restaurant gets the
    // order all the way to "ready". From there, cancelling isn't a valid
    // move, so the backend answers 409.
    final restaurant = await BackendAs.login('owner1@example.com');
    await restaurant.setStatus(orderId, 'accepted');
    await restaurant.setStatus(orderId, 'preparing');
    await restaurant.setStatus(orderId, 'ready');

    // The button is at the bottom of the screen; scroll to it first.
    await tester.ensureVisible(find.text('Cancel order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel order'));
    await waitFor(tester, find.text('Cancel this order?'));
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel order'));
    await waitFor(tester, find.text('Too late to cancel: the order is already ready for pickup.'));
    expect(find.text('Your food is ready and waiting for a courier.'), findsOneWidget);
    await binding.takeScreenshot('order_cancel_409');
  });
}
