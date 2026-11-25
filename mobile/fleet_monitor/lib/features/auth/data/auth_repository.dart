import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../../../core/json.dart';
import 'auth_models.dart';

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  /// Throws ApiException: 401 = wrong email/password, 429 = too many attempts.
  Future<LoginResponse> login(String email, String password) => _api.post(
        ApiClient.loginPath,
        body: {'email': email, 'password': password},
        parse: (json) => LoginResponse.fromJson(asJsonMap(json)),
      );

  Future<MeResponse> me() => _api.get('/api/auth/me', parse: (json) => MeResponse.fromJson(asJsonMap(json)));
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(apiClientProvider)));
