import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/activity/data/activity_event.dart';
import '../../features/vehicles/state/vehicle_list_notifier.dart';
import '../../shared/widgets/connection_banner.dart';
import '../auth/auth_notifier.dart';
import '../auth/auth_state.dart';
import '../clock.dart';
import 'realtime_connection.dart';

enum RealtimeStatus {
  /// Nobody is logged in.
  idle,

  /// First connection attempt of a session, or after resume. No banner (Q2: the list is loading anyway).
  connecting,
  connected,

  /// The package's automatic reconnect is running, or the user tapped Retry.
  reconnecting,

  /// Automatic reconnect gave up / the first attempt failed. We retry every 30 s ourselves; Retry tries now.
  disconnected,

  /// App in the background: connection stopped on purpose, no banner.
  paused,
}

@immutable
class RealtimeState {
  const RealtimeState(
    this.status, {
    this.disconnectedSince,
    this.lastReceivedAt,
  });

  final RealtimeStatus status;

  /// When live updates stopped (for "paused since 14:31").
  final DateTime? disconnectedSince;

  /// Time of the last message (or snapshot) received, for "Last received 14:32:10 · may be outdated".
  final DateTime? lastReceivedAt;

  BannerConnectionState get banner => switch (status) {
    RealtimeStatus.reconnecting => BannerConnectionState.reconnecting,
    RealtimeStatus.disconnected => BannerConnectionState.disconnected,
    _ => BannerConnectionState.connected, // hidden
  };

  @override
  bool operator ==(Object other) =>
      other is RealtimeState &&
      other.status == status &&
      other.disconnectedSince == disconnectedSince &&
      other.lastReceivedAt == lastReceivedAt;

  @override
  int get hashCode => Object.hash(status, disconnectedSince, lastReceivedAt);
}

/// Owns the real-time connection for the logged-in user.
///
/// Order on every (re)connect: connect the hub FIRST, then fetch the REST snapshot and merge it (updatedAt rule).
/// Fetching first would lose updates that happen between the snapshot and the connection.
///
/// Guards:
/// - one connection attempt at a time (Retry and the 30 s loop don't start a second one);
/// - the 30 s loop starts only after the connection closed, never during the package's automatic reconnect;
/// - logout/pause cancel the retry timer and invalidate the current connection;
/// - every callback checks its connection's generation, so late events from an old/stopped connection are ignored.
class RealtimeController extends Notifier<RealtimeState> {
  static const retryInterval = Duration(seconds: 30);

  RealtimeConnection? _connection;
  final _subscriptions = <StreamSubscription<Object?>>[];

  /// Bumped whenever a connection is replaced or torn down; callbacks of older generations are ignored.
  int _generation = 0;
  bool _attemptInFlight = false;
  bool _paused = false;
  Timer? _retryTimer;
  DateTime? _lastReceivedAt;

  DateTime get _now => ref.read(clockProvider)();

  @override
  RealtimeState build() {
    // Rebuilt when the user logs in or out: teardown of the previous session happens in onDispose.
    final userId = ref.watch(currentUserIdProvider);
    ref.onDispose(_teardown);
    if (userId == null) return const RealtimeState(RealtimeStatus.idle);

    _paused = false;
    final generation = _generation;
    // Start after build returns (a Notifier must not change its own state during build).
    Future.microtask(() {
      if (generation == _generation && ref.mounted) _connect();
    });
    return const RealtimeState(RealtimeStatus.connecting);
  }

  /// "Retry" in the Disconnected banner: try now instead of waiting for the next 30 s tick.
  void retryNow() {
    if (_attemptInFlight ||
        _paused ||
        state.status != RealtimeStatus.disconnected) {
      return;
    }
    state = RealtimeState(
      RealtimeStatus.reconnecting,
      disconnectedSince: state.disconnectedSince,
      lastReceivedAt: state.lastReceivedAt,
    );
    _connect();
  }

  /// App went to the background: stop on purpose (no banner, no retries).
  void pause() {
    if (state.status == RealtimeStatus.idle) return;
    _paused = true;
    _teardown();
    if (ref.mounted) {
      state = RealtimeState(
        RealtimeStatus.paused,
        lastReceivedAt: _lastReceivedAt,
      );
    }
  }

  /// App back in the foreground: reconnect, then re-fetch (in _connect).
  void resume() {
    if (!_paused) return;
    _paused = false;
    if (ref.read(currentUserIdProvider) == null) return;
    state = RealtimeState(
      RealtimeStatus.connecting,
      lastReceivedAt: _lastReceivedAt,
    );
    _connect();
  }

  Future<void> _connect() async {
    if (_attemptInFlight || _paused || !ref.mounted) return;
    _attemptInFlight = true;
    _retryTimer?.cancel();
    _dropConnection();
    final generation = ++_generation;

    final connection = ref.read(realtimeConnectionFactoryProvider)();
    _connection = connection;
    _subscriptions.addAll([
      connection.vehicleUpdates.listen((v) {
        // Late event from a replaced/stopped connection.
        if (generation != _generation) return;
        _lastReceivedAt = _now;
        ref.read(vehicleListProvider.notifier).applyUpdate(v);
      }),
      connection.activityEvents.listen((e) {
        if (generation != _generation) return;
        _lastReceivedAt = _now;
        ref.read(liveActivityProvider).add(e);
      }),
      connection.linkEvents.listen((event) => _onLinkEvent(generation, event)),
    ]);

    try {
      await connection.start();
      // Logged out / paused while connecting.
      if (generation != _generation || !ref.mounted) return;
      _attemptInFlight = false;
      state = RealtimeState(
        RealtimeStatus.connected,
        lastReceivedAt: _lastReceivedAt,
      );
      await _refreshSnapshot(generation);
    } on Object catch (e) {
      if (generation != _generation || !ref.mounted) return;
      _attemptInFlight = false;
      _onClosed(e);
    }
  }

  void _onLinkEvent(int generation, LinkEvent event) {
    if (generation != _generation || !ref.mounted) return;
    switch (event) {
      case LinkReconnecting():
        // The package is reconnecting on its own: our 30 s loop must not run in parallel.
        _retryTimer?.cancel();
        state = RealtimeState(
          RealtimeStatus.reconnecting,
          disconnectedSince: state.disconnectedSince ?? _now,
          lastReceivedAt: _lastReceivedAt,
        );
      case LinkReconnected():
        state = RealtimeState(
          RealtimeStatus.connected,
          lastReceivedAt: _lastReceivedAt,
        );
        // Updates may have been missed while disconnected.
        _refreshSnapshot(generation);
      case LinkClosed(:final error):
        _onClosed(error);
    }
  }

  void _onClosed(Object? error) {
    // The server closes the hub when the JWT expires (CloseOnAuthenticationExpiration): that's a session end,
    // not a network problem.
    final auth = ref.read(authProvider).value;
    if (auth is Authenticated && !_now.isBefore(auth.expiresAt)) {
      ref.read(authProvider.notifier).logout(LogoutReason.sessionExpired);
      return;
    }
    state = RealtimeState(
      RealtimeStatus.disconnected,
      disconnectedSince: state.disconnectedSince ?? _now,
      lastReceivedAt: _lastReceivedAt,
    );
    _retryTimer?.cancel();
    _retryTimer = Timer(retryInterval, _connect);
  }

  Future<void> _refreshSnapshot(int generation) async {
    // Replaced, logged out or paused meanwhile.
    if (generation != _generation || !ref.mounted) {
      return;
    }
    try {
      await ref.read(vehicleListProvider.notifier).refresh();
      if (generation == _generation) _lastReceivedAt = _now;
    } on Object catch (e) {
      // Live updates still flow; the next reconnect or pull-to-refresh fetches again.
      debugPrint('Snapshot after (re)connect failed: $e');
    }
  }

  /// Detaches and stops the current connection without waiting for it: its events are ignored from now on
  /// (generation check), so a slow or hanging stop() can never delay a reconnect or a logout.
  void _dropConnection() {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _subscriptions.clear();
    final old = _connection;
    _connection = null;
    if (old != null) {
      unawaited(
        old.stop().catchError(
          (Object e) => debugPrint('Stopping old connection failed: $e'),
        ),
      );
    }
  }

  void _teardown() {
    _generation++; // invalidates in-flight attempts and late events
    _retryTimer?.cancel();
    _retryTimer = null;
    _attemptInFlight = false;
    _dropConnection();
  }
}

final realtimeControllerProvider =
    NotifierProvider<RealtimeController, RealtimeState>(RealtimeController.new);

/// Live ActivityRaised events, for whichever activity feeds are open.
final liveActivityProvider = Provider<StreamController<ActivityEvent>>((ref) {
  final controller = StreamController<ActivityEvent>.broadcast();
  ref.onDispose(controller.close);
  return controller;
});
