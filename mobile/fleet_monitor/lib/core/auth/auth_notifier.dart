import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../clock.dart';
import 'auth_state.dart';
import 'token_storage.dart';

/// Owns the session: restore on start, login, logout, and automatic logout when the token expires.
class AuthNotifier extends AsyncNotifier<AuthState> {
  Timer? _expiryTimer;

  TokenStorage get _storage => ref.read(tokenStorageProvider);
  Clock get _now => ref.read(clockProvider);

  @override
  Future<AuthState> build() async {
    ref.onDispose(() => _expiryTimer?.cancel());

    final StoredSession? stored;
    try {
      stored = await _storage.read();
    } on Object {
      return const Unauthenticated(); // storage unavailable: just ask to log in
    }

    if (stored == null) return const Unauthenticated();
    if (!_now().isBefore(stored.expiresAt)) {
      await _storage.clear();
      return Unauthenticated(LogoutReason.sessionExpired, stored.user.email);
    }
    return _startSession(stored);
  }

  /// Throws ApiException on failure (wrong credentials, rate limited, network); the login screen shows it.
  Future<void> login(String email, String password) async {
    final response = await ref
        .read(authRepositoryProvider)
        .login(email.trim(), password);
    final session = StoredSession(
      accessToken: response.accessToken,
      expiresAt: response.expiresAt,
      user: response.user,
    );
    await _storage.write(session);
    state = AsyncData(_startSession(session));
  }

  Future<void> logout(LogoutReason reason) async {
    _expiryTimer?.cancel();
    // Several requests can fail with 401 at once; only the first one logs out (and keeps its reason).
    final current = state.value;
    if (current is! Authenticated) return;
    state = AsyncData(
      Unauthenticated(
        reason,
        reason == LogoutReason.userRequested ? null : current.user.email,
      ),
    );
    await _storage.clear();
  }

  Authenticated _startSession(StoredSession session) {
    _expiryTimer?.cancel();
    // No refresh tokens: when the token expires the user has to log in again (the server would reject it anyway).
    _expiryTimer = Timer(
      session.expiresAt.difference(_now()),
      () => logout(LogoutReason.sessionExpired),
    );
    return Authenticated(
      user: session.user,
      accessToken: session.accessToken,
      expiresAt: session.expiresAt,
    );
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

/// Id of the logged-in user, or null. Data providers watch this so they reset when the user changes or logs out.
final currentUserIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(authProvider).value;
  return auth is Authenticated ? auth.user.id : null;
});
