import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_app/core/api/api_client.dart';
import 'package:food_app/core/api/api_exception.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../fixture.dart';

void main() {
  /// Requests the ApiClient sent, captured by the fake HTTP client.
  late List<http.Request> sent;

  /// An ApiClient whose requests go to [answer] instead of the network.
  ApiClient apiClient(
    Future<http.Response> Function(http.Request request) answer, {
    String? token,
    VoidCallback? onUnauthorized,
    Duration timeout = const Duration(seconds: 10),
  }) {
    sent = [];
    return ApiClient(
      baseUrl: 'http://api.test',
      httpClient: MockClient((request) {
        sent.add(request);
        return answer(request);
      }),
      readToken: () => token,
      onUnauthorized: onUnauthorized,
      timeout: timeout,
    );
  }

  http.Response jsonResponse(String body, int status) =>
      http.Response(body, status, headers: {'content-type': 'application/json; charset=utf-8'});

  test('GET: base URL, path and query, and decodes the JSON', () async {
    final api = apiClient((_) async => jsonResponse(fixtureText('orders_page'), 200));

    final json = await api.get('/orders', query: {'limit': '20', 'cursor': 'MjM'});

    expect(sent.single.method, 'GET');
    expect(sent.single.url.toString(), 'http://api.test/orders?limit=20&cursor=MjM');
    expect(sent.single.headers['Accept'], 'application/json');
    expect((json as Map<String, dynamic>)['nextCursor'], 'MjM');
  });

  test('POST: sends JSON and extra headers', () async {
    final api = apiClient((_) async => jsonResponse(fixtureText('order_created'), 201));

    await api.post('/orders', body: {'restaurantId': 1}, headers: {'Idempotency-Key': 'key-1'});

    final request = sent.single;
    expect(request.method, 'POST');
    expect(request.headers['Content-Type'], startsWith('application/json'));
    expect(request.headers['Idempotency-Key'], 'key-1');
    expect(jsonDecode(request.body), {'restaurantId': 1});
  });

  test('adds "Authorization: Bearer <token>" only when logged in', () async {
    final loggedIn = apiClient((_) async => jsonResponse('{}', 200), token: 'abc');
    await loggedIn.get('/auth/me');
    expect(sent.single.headers['Authorization'], 'Bearer abc');

    final loggedOut = apiClient((_) async => jsonResponse('[]', 200));
    await loggedOut.get('/restaurants');
    expect(sent.single.headers.containsKey('Authorization'), isFalse);
  });

  test("turns the backend's error body into an ApiException", () async {
    final api = apiClient((_) async => jsonResponse(fixtureText('error_400'), 400));

    final error = await api.post('/auth/register', body: {}).then<ApiException?>(
      (_) => null,
      onError: (Object e) => e as ApiException,
    );

    expect(error!.statusCode, 400);
    expect(error.message, 'Invalid request');
    expect(error.details.map((d) => d.path), ['email', 'password', 'name']);
  });

  test('an error page that is not JSON still becomes an ApiException', () async {
    final api = apiClient((_) async => http.Response('<html>Bad Gateway</html>', 502));

    await expectLater(
      api.get('/restaurants'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 502)),
    );
  });

  test('a 401 to a request that carried a token reports the expired session', () async {
    var expired = 0;
    final api = apiClient(
      (_) async => jsonResponse(fixtureText('error_401'), 401),
      token: 'old-token',
      onUnauthorized: () => expired++,
    );

    await expectLater(api.get('/orders'), throwsA(isA<ApiException>()));
    expect(expired, 1);
  });

  test('a 401 without a token (like a wrong password) is only an error', () async {
    var expired = 0;
    final api = apiClient(
      (_) async => jsonResponse('{"error":"Invalid email or password"}', 401),
      onUnauthorized: () => expired++,
    );

    await expectLater(api.post('/auth/login', body: {}), throwsA(isA<ApiException>()));
    expect(expired, 0);
  });

  test('no connection becomes a NetworkException', () async {
    final api = apiClient((_) async => throw http.ClientException('Connection refused'));

    await expectLater(
      api.get('/restaurants'),
      throwsA(isA<NetworkException>().having((e) => e.isTimeout, 'isTimeout', isFalse)),
    );
  });

  test('a slow answer becomes a NetworkException with isTimeout', () async {
    final api = apiClient(
      (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return jsonResponse('[]', 200);
      },
      timeout: const Duration(milliseconds: 50),
    );

    await expectLater(
      api.get('/restaurants'),
      throwsA(isA<NetworkException>().having((e) => e.isTimeout, 'isTimeout', isTrue)),
    );
  });

  test('reads text as UTF-8 even when the header names no charset', () async {
    final api = apiClient((_) async => http.Response.bytes(
          utf8.encode('{"name":"Crème brûlée"}'),
          200,
          headers: {'content-type': 'application/json'},
        ));

    final json = await api.get('/restaurants/9') as Map<String, dynamic>;
    expect(json['name'], 'Crème brûlée');
  });
}
