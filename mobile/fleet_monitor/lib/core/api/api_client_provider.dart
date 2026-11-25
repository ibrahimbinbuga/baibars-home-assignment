import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_notifier.dart';
import '../auth/auth_state.dart';
import '../config.dart';
import 'api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  // Token and logout are looked up when a request runs (not when the client is built), so the client doesn't depend
  // on the auth state it helps to produce.
  return ApiClient(
    baseUrl: config.apiBaseUrl,
    readToken: () => switch (ref.read(authProvider).value) {
      Authenticated(:final accessToken) => accessToken,
      _ => null,
    },
    onUnauthorized: () => ref.read(authProvider.notifier).logout(LogoutReason.unauthorized),
  );
});
