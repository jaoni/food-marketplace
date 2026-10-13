import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'user.dart';

/// Keeps the logged-in session (JWT + user) on the device, encrypted:
/// in the Keychain on iOS and in encrypted storage on Android.
class SessionStorage {
  SessionStorage(this._storage);

  static const _key = 'session';
  final FlutterSecureStorage _storage;

  Future<AuthSession?> read() async {
    final saved = await _storage.read(key: _key);
    if (saved == null) return null;
    try {
      return AuthSession.fromJson(jsonDecode(saved) as Map<String, dynamic>);
    } catch (_) {
      await clear(); // unreadable (e.g. saved by an older app version)
      return null;
    }
  }

  Future<void> save(AuthSession session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  Future<void> clear() => _storage.delete(key: _key);
}

final sessionStorageProvider = Provider<SessionStorage>((ref) {
  return SessionStorage(const FlutterSecureStorage());
});
