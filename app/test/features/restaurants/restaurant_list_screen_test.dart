import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_app/core/api/api_client.dart';
import 'package:food_app/core/api/api_providers.dart';
import 'package:food_app/features/restaurants/ui/restaurant_list_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../fixture.dart';

void main() {
  /// The restaurant list screen, with the real ApiClient, repository and
  /// provider, but every HTTP request answered by [answer].
  Future<void> showScreen(
    WidgetTester tester,
    Future<http.Response> Function(http.Request request) answer,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null, // like the app: no automatic retries
        overrides: [
          apiClientProvider.overrideWithValue(
            ApiClient(baseUrl: 'http://api.test', httpClient: MockClient(answer)),
          ),
        ],
        child: const MaterialApp(home: RestaurantListScreen()),
      ),
    );
  }

  http.Response restaurants() => http.Response(fixtureText('restaurants'), 200);

  testWidgets('shows a spinner, then the restaurants from the API', (tester) async {
    final response = Completer<http.Response>();
    await showScreen(tester, (_) => response.future);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    response.complete(restaurants());
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Bella Napoli'), findsOneWidget);
    expect(find.text('Tokyo Bowl'), findsOneWidget);
    expect(find.text('Green Garden'), findsOneWidget);
  });

  testWidgets('greys out closed restaurants', (tester) async {
    await showScreen(tester, (_) async => restaurants());
    await tester.pumpAndSettle();

    Opacity? opacityAround(String name) => tester
        .widgetList<Opacity>(find.ancestor(of: find.text(name), matching: find.byType(Opacity)))
        .firstOrNull;

    expect(opacityAround('Green Garden')?.opacity, 0.4); // closed
    expect(opacityAround('Bella Napoli'), isNull); // open
    expect(find.text('Closed'), findsOneWidget);
    expect(find.text('Open now'), findsNWidgets(2));
  });

  testWidgets('shows a friendly error, and "Try again" loads again', (tester) async {
    var requests = 0;
    await showScreen(tester, (_) async {
      requests++;
      if (requests == 1) throw http.ClientException('Connection refused');
      return restaurants();
    });
    await tester.pumpAndSettle();

    expect(
      find.text("Can't reach the server. Check your internet connection and try again."),
      findsOneWidget,
    );

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Bella Napoli'), findsOneWidget);
    expect(requests, 2);
  });

  testWidgets('shows an empty state when there are no restaurants', (tester) async {
    await showScreen(tester, (_) async => http.Response('[]', 200));
    await tester.pumpAndSettle();

    expect(find.text('No restaurants yet. Check back soon!'), findsOneWidget);
  });
}
