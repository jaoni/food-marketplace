// Runs the real app on a simulator against the running backend (seed data):
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/auth_test.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_app/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const storage = FlutterSecureStorage();

  Future<void> fillIn(WidgetTester tester, String label, String text) =>
      tester.enterText(find.widgetWithText(TextFormField, label), text);

  testWidgets('login: wrong password shows an error, then logging in opens the account',
      (tester) async {
    await storage.delete(key: 'session');
    app.main();
    await waitFor(tester, find.text('Bella Napoli'));

    // The account page needs a login, so the app asks for one.
    await tester.tap(find.byTooltip('Account'));
    await waitFor(tester, find.widgetWithText(FilledButton, 'Log in'));

    await fillIn(tester, 'Email', 'alice@example.com');
    await fillIn(tester, 'Password', 'wrong-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await waitFor(tester, find.text('Invalid email or password'));
    await binding.takeScreenshot('auth_wrong_password');

    await fillIn(tester, 'Password', 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await waitFor(tester, find.text('Alice Customer')); // from GET /auth/me
    expect(find.text('alice@example.com'), findsOneWidget);
    await binding.takeScreenshot('auth_account');

    // The token is saved in secure storage, so the login survives a restart.
    final saved = jsonDecode((await storage.read(key: 'session'))!) as Map<String, dynamic>;
    expect(saved['token'], isA<String>());

    await tester.tap(find.text('Log out'));
    await waitFor(tester, find.text('Bella Napoli'));
    expect(await storage.read(key: 'session'), isNull);
  });

  testWidgets('register: a new customer is logged in right away', (tester) async {
    await storage.delete(key: 'session');
    app.main();
    await waitFor(tester, find.text('Bella Napoli'));

    await tester.tap(find.byTooltip('Account'));
    await waitFor(tester, find.text('No account yet? Sign up'));
    await tester.tap(find.text('No account yet? Sign up'));
    await waitFor(tester, find.widgetWithText(FilledButton, 'Create account'));

    final email = 'test-${DateTime.now().millisecondsSinceEpoch}@example.com';
    await fillIn(tester, 'Name', 'Test Customer');
    await fillIn(tester, 'Email', email);
    await fillIn(tester, 'Password', 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await waitFor(tester, find.text(email));
    expect(find.text('Test Customer'), findsOneWidget);
  });

  testWidgets('an expired token logs you out and sends you to the login screen', (tester) async {
    // A saved session whose token the backend no longer accepts, as if the
    // app was reopened after the token expired.
    await storage.write(
      key: 'session',
      value: jsonEncode({
        'token': 'expired-or-invalid-token',
        'user': {
          'id': 4,
          'email': 'alice@example.com',
          'name': 'Alice Customer',
          'role': 'customer',
          'createdAt': '2026-10-11T22:34:11.915Z',
        },
      }),
    );
    app.main();
    await waitFor(tester, find.text('Bella Napoli'));

    await tester.tap(find.byTooltip('Account')); // GET /auth/me answers 401
    await waitFor(tester, find.text('Your session has expired. Please log in again.'));
    expect(find.widgetWithText(FilledButton, 'Log in'), findsOneWidget);
    expect(await storage.read(key: 'session'), isNull);
    await binding.takeScreenshot('auth_session_expired');
  });
}
