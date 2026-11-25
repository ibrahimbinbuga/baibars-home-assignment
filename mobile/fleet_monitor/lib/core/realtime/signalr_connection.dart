import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/errors.dart';
import 'package:signalr_netcore/iretry_policy.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../../features/activity/data/activity_event.dart';
import '../../features/vehicles/data/vehicle.dart';
import '../json.dart';
import 'realtime_connection.dart';

/// RealtimeConnection over SignalR (/hubs/fleet). Server → client messages only.
class SignalRRealtimeConnection implements RealtimeConnection {
  SignalRRealtimeConnection({
    required Uri baseUrl,
    required String? Function() readToken,
  }) {
    _hub = HubConnectionBuilder()
        .withUrl(
          baseUrl.resolve('/hubs/fleet').toString(),
          options: HttpConnectionOptions(
            transport: HttpTransportType.WebSockets,
            // The mobile client sends it as ?access_token=, which the server accepts only on /hubs/fleet.
            accessTokenFactory: () async => readToken() ?? '',
            httpClient: UnauthorizedWatchingHttpClient(
              onUnauthorized: () => _rejected = true,
            ),
          ),
        )
        // Automatic reconnect after a drop: 0, 2, 5, 10, 30 s. After that the connection closes and the
        // RealtimeController takes over with its own retry every 30 s. A 401 stops it at once.
        .withAutomaticReconnect(
          reconnectPolicy: StopOnUnauthorizedRetryPolicy(
            reconnectDelaysMs,
            isRejected: () => _rejected,
          ),
        )
        .build();

    _hub.on(
      'VehicleUpdated',
      (args) => _emit(args, Vehicle.fromJson, _vehicles),
    );
    _hub.on(
      'ActivityRaised',
      (args) => _emit(args, ActivityEvent.fromJson, _activity),
    );
    _hub.onreconnecting(({error}) => _addLink(const LinkReconnecting()));
    _hub.onreconnected(({connectionId}) => _addLink(const LinkReconnected()));
    // After a 401 during the automatic reconnect the package closes without an error, so we say why.
    _hub.onclose(
      ({error}) => _addLink(
        LinkClosed(_rejected ? const RealtimeUnauthorized() : error),
      ),
    );
  }

  static const reconnectDelaysMs = [0, 2000, 5000, 10000, 30000];

  late final HubConnection _hub;

  /// Set when the server answered the negotiate request with 401.
  bool _rejected = false;
  final _vehicles = StreamController<Vehicle>.broadcast();
  final _activity = StreamController<ActivityEvent>.broadcast();
  final _link = StreamController<LinkEvent>.broadcast();

  @override
  Stream<Vehicle> get vehicleUpdates => _vehicles.stream;

  @override
  Stream<ActivityEvent> get activityEvents => _activity.stream;

  @override
  Stream<LinkEvent> get linkEvents => _link.stream;

  @override
  Future<void> start() async {
    try {
      await _hub.start();
    } on HttpError catch (e) {
      if (e.statusCode == 401) throw const RealtimeUnauthorized();
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    await _hub.stop();
    await Future.wait([_vehicles.close(), _activity.close(), _link.close()]);
  }

  // stop() fires onclose after the streams may already be closed.
  void _addLink(LinkEvent event) {
    if (!_link.isClosed) _link.add(event);
  }

  /// A malformed message is dropped (and logged); it must never break the connection.
  void _emit<T>(
    List<Object?>? args,
    T Function(Map<String, dynamic>) parse,
    StreamController<T> sink,
  ) {
    if (sink.isClosed || args == null || args.isEmpty) return;
    try {
      sink.add(parse(asJsonMap(args.first)));
    } on Object catch (e) {
      debugPrint('Ignoring malformed real-time message: $e');
    }
  }
}

/// The package's own HTTP client (used for the negotiate request), but it reports a 401 to [onUnauthorized].
///
/// Why: on the first connect a 401 reaches us as an [HttpError] with its status code, but during the automatic
/// reconnect the package wraps every error in a plain `Exception`, so the status code is lost. Watching the
/// HTTP response itself is the one place that sees the status code in both cases.
class UnauthorizedWatchingHttpClient extends SignalRHttpClient {
  UnauthorizedWatchingHttpClient({
    required this.onUnauthorized,
    SignalRHttpClient? inner,
  }) : _inner = inner ?? WebSupportingHttpClient(null);

  final void Function() onUnauthorized;
  final SignalRHttpClient _inner;

  @override
  Future<SignalRHttpResponse> send(SignalRHttpRequest request) async {
    try {
      return await _inner.send(request);
    } on HttpError catch (e) {
      if (e.statusCode == 401) onUnauthorized();
      rethrow;
    }
  }
}

/// The automatic reconnect delays, except that it stops (returns null) once the token was rejected:
/// retrying with a token the server refuses can't succeed. Network errors and 5xx keep retrying.
class StopOnUnauthorizedRetryPolicy implements IRetryPolicy {
  StopOnUnauthorizedRetryPolicy(this.delaysMs, {required this.isRejected});

  final List<int> delaysMs;
  final bool Function() isRejected;

  @override
  int? nextRetryDelayInMilliseconds(RetryContext retryContext) {
    if (isRejected()) return null;
    final attempt = retryContext.previousRetryCount;
    return attempt < delaysMs.length ? delaysMs[attempt] : null;
  }
}
