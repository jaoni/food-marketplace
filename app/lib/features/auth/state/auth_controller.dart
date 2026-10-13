import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../data/session_storage.dart';
import '../data/user.dart';

/// Who is logged in. The value is the current [AuthSession], or null when
/// logged out. While the saved session is read at app start, it's loading.
class AuthController extends AsyncNotifier<AuthSession?> {
  /// True after the backend rejected our token (e.g. it expired), until the
  /// next login. The login screen uses it to explain why you're there.
  bool sessionExpired = false;

  @override
  Future<AuthSession?> build() => ref.read(sessionStorageProvider).read();

  Future<void> login({required String email, required String password}) async {
    final session = await ref.read(authRepositoryProvider).login(email: email, password: password);
    await _start(session);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final session = await ref
        .read(authRepositoryProvider)
        .register(name: name, email: email, password: password);
    await _start(session);
  }

  Future<void> logout() => _end(expired: false);

  /// Called by the API client when the backend answers 401 to a request that
  /// carried our token.
  Future<void> onSessionExpired() async {
    if (state.value == null) return; // already logged out
    await _end(expired: true);
  }

  Future<void> _end({required bool expired}) async {
    await ref.read(sessionStorageProvider).clear();
    sessionExpired = expired;
    state = const AsyncData(null);
  }

  Future<void> _start(AuthSession session) async {
    await ref.read(sessionStorageProvider).save(session);
    sessionExpired = false;
    state = AsyncData(session);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

/// The logged-in user as the server sees them right now (`GET /auth/me`).
final currentUserProvider = FutureProvider.autoDispose<User>((ref) {
  // Load again whenever a different session (token) is active.
  ref.watch(authControllerProvider.select((session) => session.value?.token));
  return ref.watch(authRepositoryProvider).me();
});
