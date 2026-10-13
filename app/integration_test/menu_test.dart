// Runs the real app on a simulator against the running backend (seed data):
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/menu_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:food_app/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('menu: grouped by category, sold-out and closed items cannot be added',
      (tester) async {
    app.main();
    await waitFor(tester, find.text('Bella Napoli'));

    // Open restaurant: categories as headers, sold-out item greyed out and disabled.
    await tester.tap(find.text('Bella Napoli'));
    await waitFor(tester, find.text('Margherita'));
    expect(find.text('Pizza'), findsOneWidget);
    expect(find.text('Drinks'), findsOneWidget);
    expect(find.text(r'$10.50'), findsOneWidget);
    expect(find.textContaining('Sold out'), findsOneWidget);
    expect(iconButtonWithTooltip(tester, 'Add Quattro Formaggi').onPressed, isNull);
    expect(iconButtonWithTooltip(tester, 'Add Margherita').onPressed, isNotNull);
    await binding.takeScreenshot('menu_open_restaurant');

    // Closed restaurant: banner, and nothing can be added.
    await tester.pageBack();
    await waitFor(tester, find.text('Green Garden'));
    await tester.tap(find.text('Green Garden'));
    await waitFor(tester, find.text('Caesar Salad'));
    expect(find.textContaining('is closed right now'), findsOneWidget);
    expect(iconButtonWithTooltip(tester, 'Add Caesar Salad').onPressed, isNull);
    await binding.takeScreenshot('menu_closed_restaurant');
  });
}
