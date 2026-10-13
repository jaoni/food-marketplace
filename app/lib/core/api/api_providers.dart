import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../features/auth/state/auth_controller.dart';
import '../config.dart';
import 'api_client.dart';

/// The low-level HTTP client. Tests override this with a fake one.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// The one [ApiClient] the whole app shares. It reads the token from the
/// auth controller on every request, and tells it when the token is rejected.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: apiBaseUrl,
    httpClient: ref.watch(httpClientProvider),
    readToken: () => ref.read(authControllerProvider).value?.token,
    onUnauthorized: () => ref.read(authControllerProvider.notifier).onSessionExpired(),
  );
});
