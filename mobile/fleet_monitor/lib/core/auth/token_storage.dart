import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/data/auth_models.dart';
import '../json.dart';

/// What is kept between app launches. The user is stored too, so the app can restore without a network call.
class StoredSession {
  const StoredSession({required this.accessToken, required this.expiresAt, required this.user});

  final String accessToken;
  final DateTime expiresAt;
  final UserInfo user;

  Map<String, Object?> toJson() => {
        'accessToken': accessToken,
        'expiresAt': expiresAt.toUtc().toIso8601String(),
        'user': user.toJson(),
      };

  factory StoredSession.fromJson(Map<String, dynamic> json) => StoredSession(
        accessToken: readString(json, 'accessToken'),
        expiresAt: readDate(json, 'expiresAt'),
        user: UserInfo.fromJson(asJsonMap(json['user'])),
      );
}

abstract interface class TokenStorage {
  Future<StoredSession?> read();
  Future<void> write(StoredSession session);
  Future<void> clear();
}

/// Keychain (iOS) / Keystore-backed storage (Android) via flutter_secure_storage.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage(this._storage);

  static const _key = 'session';
  final FlutterSecureStorage _storage;

  @override
  Future<StoredSession?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return StoredSession.fromJson(asJsonMap(jsonDecode(raw)));
    } on Object {
      // Unreadable (e.g. written by an older app version): treat as logged out.
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(StoredSession session) => _storage.write(key: _key, value: jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => SecureTokenStorage(const FlutterSecureStorage()));
