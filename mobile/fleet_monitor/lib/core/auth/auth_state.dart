import '../../features/auth/data/auth_models.dart';

enum LogoutReason {
  /// The user tapped "Log out".
  userRequested,

  /// The token's expiresAt passed (on app start or while the app was open).
  sessionExpired,

  /// The server rejected our token (401 on a call other than login).
  unauthorized,
}

sealed class AuthState {
  const AuthState();
}

class Authenticated extends AuthState {
  const Authenticated({
    required this.user,
    required this.accessToken,
    required this.expiresAt,
  });

  final UserInfo user;
  final String accessToken;
  final DateTime expiresAt;
}

class Unauthenticated extends AuthState {
  const Unauthenticated([this.reason, this.email]);

  /// Why the user is on the login screen; null on a fresh start.
  final LogoutReason? reason;

  /// Email of the session that just ended, to prefill the login form after an expiry (not after a manual logout).
  final String? email;

  /// The session ended without the user asking for it (expired or rejected by the server).
  bool get sessionEnded =>
      reason == LogoutReason.sessionExpired ||
      reason == LogoutReason.unauthorized;
}
