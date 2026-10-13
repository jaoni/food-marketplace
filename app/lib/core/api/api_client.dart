import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Every request to the backend goes through this class.
///
/// It builds the URL, adds the login token, sends and decodes JSON, applies a
/// timeout, and turns failures into [ApiException] (the server said no) or
/// [NetworkException] (no answer at all). Repositories call it and turn the
/// JSON into models.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required http.Client httpClient,
    this.readToken,
    this.onUnauthorized,
    this.timeout = const Duration(seconds: 10),
  }) : _http = httpClient;

  final String baseUrl;
  final http.Client _http;
  final Duration timeout;

  /// Returns the current JWT, or null when logged out.
  final String? Function()? readToken;

  /// Called when the backend answers 401 to a request that carried a token,
  /// e.g. because the token expired.
  final void Function()? onUnauthorized;

  Future<Object?> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<Object?> post(String path, {Object? body, Map<String, String>? headers}) =>
      _send('POST', path, body: body, headers: headers);

  Future<Object?> patch(String path, {Object? body}) => _send('PATCH', path, body: body);

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    Map<String, String>? headers,
  }) async {
    var uri = Uri.parse('$baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }

    final request = http.Request(method, uri);
    request.headers['Accept'] = 'application/json';
    final token = readToken?.call();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    request.headers.addAll(headers ?? const {});

    final http.Response response;
    try {
      response = await _http.send(request).then(http.Response.fromStream).timeout(timeout);
    } on TimeoutException {
      throw NetworkException.timeout();
    } on http.ClientException catch (e) {
      // package:http reports "connection refused", "no internet" etc. this way.
      throw NetworkException(e.message);
    }

    final json = _decode(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json;
    }
    // Our token was rejected. (A 401 without a token, like a wrong password
    // on the login screen, is just an error for the caller.)
    if (response.statusCode == 401 && token != null) {
      onUnauthorized?.call();
    }
    throw ApiException.fromResponse(response.statusCode, json);
  }

  Object? _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      // Not JSON (e.g. an HTML error page from a proxy).
      if (response.statusCode >= 200 && response.statusCode < 300) {
        throw ApiException(response.statusCode, 'The server sent an unreadable response');
      }
      return null;
    }
  }
}
