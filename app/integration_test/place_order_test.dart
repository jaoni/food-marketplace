// Runs the real app on a simulator against the running backend (seed data):
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/place_order_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_app/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('place order: log in from the cart, then the server total is shown', (tester) async {
    await const FlutterSecureStorage().delete(key: 'session');
    app.main();
    await waitFor(tester, find.text('Bella Napoli'));

    // Cart: 2 x Margherita (10.50) + 1 x Lemonade (3.50) = 24.50
    await tester.tap(find.text('Bella Napoli'));
    await waitFor(tester, find.text('Margherita'));
    await tester.tap(find.byTooltip('Add Margherita'));
    await tester.tap(find.byTooltip('Add Margherita'));
    await tester.tap(find.byTooltip('Add Lemonade'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cart'));
    await waitFor(tester, find.text('Log in to place your order'));

    // Placing an order needs a login; afterwards the app returns to the cart.
    await tester.tap(find.text('Log in to place your order'));
    await waitFor(tester, find.widgetWithText(FilledButton, 'Log in'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'alice@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await waitFor(tester, find.text('Place order'));
    expect(find.text(r'$24.50'), findsOneWidget); // the cart survived the login

    await tester.enterText(find.widgetWithText(TextFormField, 'Delivery address'), '12 Main St');
    await tester.tap(find.text('Place order'));
    await tester.pump();
    expect(find.text('Placing order…'), findsOneWidget); // button disabled while sending

    // Generous timeout: may include a timed-out first try and a retry.
    await waitFor(tester, find.text('Order placed!'), timeout: const Duration(seconds: 40));
    expect(find.text(r'$24.50'), findsOneWidget); // totalCents from the server
    expect(find.text('Calculated by the server'), findsOneWidget);
    await binding.takeScreenshot('order_placed');

    // The cart was emptied. (Back twice: from the order to My orders, then to the list.)
    await tester.pageBack();
    await waitFor(tester, find.text('My orders'));
    await tester.pageBack();
    await waitFor(tester, find.text('Bella Napoli'));
    expect(find.descendant(of: find.byTooltip('Cart'), matching: find.text('3')), findsNothing);
  });
}
