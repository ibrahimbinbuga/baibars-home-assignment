import 'dart:async';

import 'package:flutter/foundation.dart';
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
          ),
        )
        // Automatic reconnect after a drop: 0, 2, 5, 10, 30 s. After that the connection closes and the
        // RealtimeController takes over with its own retry every 30 s.
        .withAutomaticReconnect(retryDelays: reconnectDelaysMs)
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
    _hub.onclose(({error}) => _addLink(LinkClosed(error)));
  }

  static const reconnectDelaysMs = [0, 2000, 5000, 10000, 30000];

  late final HubConnection _hub;
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
  Future<void> start() async => await _hub.start();

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
