// Runs the real app on a simulator against the running backend (seed data):
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/errors_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_app/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("an account that can't order sees a friendly message, not the raw 403",
      (tester) async {
    await const FlutterSecureStorage().delete(key: 'session');
    app.main();
    await waitFor(tester, find.text('Bella Napoli'));
    await tester.tap(find.text('Bella Napoli'));
    await waitFor(tester, find.text('Margherita'));
    await tester.tap(find.byTooltip('Add Margherita'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cart'));
    await waitFor(tester, find.text('Log in to place your order'));
    await tester.tap(find.text('Log in to place your order'));
    await logIn(tester, 'owner1@example.com'); // a restaurant owner, not a customer

    await waitFor(tester, find.text('Place order'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Delivery address'), '12 Main St');
    await tester.tap(find.text('Place order'));

    // The backend answers 403 "Your role is not allowed to do this".
    await waitFor(tester, find.text("Your account isn't allowed to do this."));
    expect(find.text('Try again'), findsOneWidget);
    await binding.takeScreenshot('error_403');
    await const FlutterSecureStorage().delete(key: 'session');
  });
}
