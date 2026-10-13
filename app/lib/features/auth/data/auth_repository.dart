import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import 'user.dart';

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<AuthSession> login({required String email, required String password}) async {
    final json = await _api.post('/auth/login', body: {'email': email, 'password': password});
    return AuthSession.fromJson(json as Map<String, dynamic>);
  }

  /// Signs up a customer (the backend's default role).
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final json = await _api.post(
      '/auth/register',
      body: {'name': name, 'email': email, 'password': password},
    );
    return AuthSession.fromJson(json as Map<String, dynamic>);
  }

  /// The logged-in user, fresh from the server. Needs a valid token.
  Future<User> me() async {
    final json = await _api.get('/auth/me');
    return User.fromJson(json as Map<String, dynamic>);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});
