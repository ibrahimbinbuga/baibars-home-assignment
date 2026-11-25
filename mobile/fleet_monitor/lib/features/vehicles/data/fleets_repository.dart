import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../../../core/auth/auth_notifier.dart';
import 'fleet.dart';

class FleetsRepository {
  FleetsRepository(this._api);

  final ApiClient _api;

  Future<List<Fleet>> list() =>
      _api.get('/api/fleets', parse: (json) => parseList(json, Fleet.fromJson));
}

final fleetsRepositoryProvider = Provider<FleetsRepository>(
  (ref) => FleetsRepository(ref.watch(apiClientProvider)),
);

/// Fleets the current user can see. Reloads when the user changes.
final fleetsProvider = FutureProvider<List<Fleet>>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return const [];
  return ref.watch(fleetsRepositoryProvider).list();
});
