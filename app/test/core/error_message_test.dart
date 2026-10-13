import 'package:flutter_test/flutter_test.dart';
import 'package:food_app/core/api/api_exception.dart';
import 'package:food_app/core/errors/error_message.dart';

import '../fixture.dart';

void main() {
  /// An ApiException built from a real error response saved in test/fixtures.
  ApiException fromFixture(String name, int statusCode) =>
      ApiException.fromResponse(statusCode, fixture(name));

  test('network failures: no connection, or too slow', () {
    expect(errorMessage(NetworkException('Connection refused')),
        "Can't reach the server. Check your internet connection and try again.");
    expect(errorMessage(NetworkException.timeout()),
        'The server is taking too long to answer. Please try again.');
  });

  test('400 with details lists the fields in plain words', () {
    // Real response: {"error":"Invalid request","details":[{"path":"email",...},...]}
    expect(errorMessage(fromFixture('error_400', 400)), 'Please check: email, password, name.');

    final nested = ApiException(400, 'Invalid request', details: const [
      ApiErrorDetail(path: 'items.0.quantity', message: 'Too small'),
      ApiErrorDetail(path: 'deliveryAddress', message: 'Too small'),
    ]);
    expect(errorMessage(nested), 'Please check: quantity, delivery address.');
  });

  test("business errors show the backend's own message", () {
    expect(errorMessage(fromFixture('error_422', 422)), 'Green Garden is closed');
    expect(errorMessage(fromFixture('error_409', 409)), "Can't change an order from delivered to cancelled");
    expect(errorMessage(ApiException(401, 'Invalid email or password')), 'Invalid email or password');
  });

  test('403 and server errors get a friendly message instead of the raw one', () {
    expect(errorMessage(ApiException(403, 'Your role is not allowed to do this')),
        "Your account isn't allowed to do this.");
    expect(errorMessage(ApiException(500, 'Internal server error')),
        'Something went wrong on our side. Please try again in a moment.');
    expect(errorMessage(ApiException(502, 'Request failed with status 502')),
        'Something went wrong on our side. Please try again in a moment.');
  });

  test('unexpected JSON, and anything else', () {
    expect(errorMessage(const FormatException('Unexpected character')),
        'The server sent an unexpected answer. Please try again later.');
    expect(errorMessage(StateError('oops')), 'Something went wrong. Please try again.');
  });
}
