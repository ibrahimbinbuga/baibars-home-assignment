import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/activity/data/activity_event.dart';
import '../../features/vehicles/data/vehicle.dart';
import '../api/api_client_provider.dart';
import '../auth/auth_notifier.dart';
import '../auth/auth_state.dart';
import '../config.dart';
import 'signalr_connection.dart';

/// What happens to the link itself (not the data).
sealed class LinkEvent {
  const LinkEvent();
}

/// The automatic reconnect started (the connection dropped after being up).
class LinkReconnecting extends LinkEvent {
  const LinkReconnecting();
}

/// The automatic reconnect succeeded.
class LinkReconnected extends LinkEvent {
  const LinkReconnected();
}

/// The connection is gone for good: automatic reconnect gave up, or the server closed it (e.g. token expired).
class LinkClosed extends LinkEvent {
  const LinkClosed([this.error]);

  /// [RealtimeUnauthorized] when the server rejected our token while reconnecting.
  final Object? error;
}

/// The server answered a (re)connect with 401: the token is no longer accepted (e.g. the user was deleted).
/// Unlike a network error or a 5xx, retrying can't help, so the controller logs out.
class RealtimeUnauthorized implements Exception {
  const RealtimeUnauthorized();

  @override
  String toString() => 'RealtimeUnauthorized: the hub rejected the token (401)';
}

/// One real-time connection to the hub. An interface so the controller can be tested with a fake.
/// A connection is used once: after it closes, the controller creates a new one.
abstract interface class RealtimeConnection {
  Stream<Vehicle> get vehicleUpdates;
  Stream<ActivityEvent> get activityEvents;
  Stream<LinkEvent> get linkEvents;

  /// Throws if the connection can't be established: [RealtimeUnauthorized] on 401, anything else for network
  /// errors, 5xx, ...
  Future<void> start();
  Future<void> stop();
}

typedef RealtimeConnectionFactory = RealtimeConnection Function();

final realtimeConnectionFactoryProvider = Provider<RealtimeConnectionFactory>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  // Keeps the API client (and with it the auth wiring) alive alongside the hub.
  ref.watch(apiClientProvider);
  return () => SignalRRealtimeConnection(
    baseUrl: config.apiBaseUrl,
    // Read at every (re)connect, so a reconnect uses the current token.
    readToken: () => switch (ref.read(authProvider).value) {
      Authenticated(:final accessToken) => accessToken,
      _ => null,
    },
  );
});
