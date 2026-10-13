// Runs the real app on a simulator against the running backend (seed data):
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/cart_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:food_app/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Finder cartBadge(String count) =>
      find.descendant(of: find.byTooltip('Cart'), matching: find.text(count));

  testWidgets('cart: estimated total, and one restaurant at a time', (tester) async {
    app.main();
    await waitFor(tester, find.text('Bella Napoli'));

    // 2 x Margherita (10.50) + 1 x Lemonade (3.50)
    await tester.tap(find.text('Bella Napoli'));
    await waitFor(tester, find.text('Margherita'));
    await tester.tap(find.byTooltip('Add Margherita'));
    await tester.tap(find.byTooltip('Add Margherita'));
    await tester.tap(find.byTooltip('Add Lemonade'));
    await tester.pumpAndSettle();
    expect(cartBadge('3'), findsOneWidget);

    await tester.tap(find.byTooltip('Cart'));
    await waitFor(tester, find.text('Your cart'));
    expect(find.text(r'$21.00'), findsOneWidget);
    expect(find.text(r'$24.50'), findsOneWidget);
    expect(find.textContaining('final price is calculated by our server'), findsOneWidget);
    await binding.takeScreenshot('cart_estimate');

    // Adding from another restaurant asks first. Cancel keeps the cart.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await waitFor(tester, find.text('Tokyo Bowl'));
    await tester.tap(find.text('Tokyo Bowl'));
    await waitFor(tester, find.text('Salmon Poke'));
    await tester.tap(find.byTooltip('Add Salmon Poke'));
    await waitFor(tester, find.text('Start a new cart?'));
    await binding.takeScreenshot('cart_other_restaurant');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(cartBadge('3'), findsOneWidget);

    // "Clear cart" replaces it with the new restaurant's item.
    await tester.tap(find.byTooltip('Add Salmon Poke'));
    await waitFor(tester, find.text('Clear cart'));
    await tester.tap(find.text('Clear cart'));
    await tester.pumpAndSettle();
    expect(cartBadge('1'), findsOneWidget);

    await tester.tap(find.byTooltip('Cart'));
    await waitFor(tester, find.text('Your cart'));
    expect(find.text('Tokyo Bowl'), findsOneWidget);
    expect(find.text('Margherita'), findsNothing);

    // Quantities: one more, then down to zero empties the cart.
    await tester.tap(find.byTooltip('One more Salmon Poke'));
    await tester.pump();
    expect(find.text(r'$29.00'), findsNWidgets(2)); // line total and estimated total
    await tester.tap(find.byTooltip('One less Salmon Poke'));
    await tester.pump();
    await tester.tap(find.byTooltip('One less Salmon Poke'));
    await tester.pump();
    expect(find.text('Your cart is empty.'), findsOneWidget);
  });
}
