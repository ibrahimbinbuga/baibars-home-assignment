import 'dart:async';

import 'package:fleet_monitor/core/auth/auth_notifier.dart';
import 'package:fleet_monitor/core/auth/auth_state.dart';
import 'package:fleet_monitor/core/clock.dart';
import 'package:fleet_monitor/core/realtime/realtime_connection.dart';
import 'package:fleet_monitor/core/realtime/realtime_controller.dart';
import 'package:fleet_monitor/features/vehicles/data/vehicle.dart';
import 'package:fleet_monitor/features/vehicles/data/vehicles_repository.dart';
import 'package:fleet_monitor/features/vehicles/state/vehicle_list_notifier.dart';
import 'package:fleet_monitor/shared/widgets/connection_banner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';

/// Runs in testWidgets so `tester.pump(duration)` drives the 30 s retry timer in fake time.
void main() {
  final t0 = DateTime.utc(2026, 11, 26, 10);
  late DateTime now;
  late List<String> log;
  late List<FakeRealtimeConnection> connections;
  late Future<void> Function()? Function(int attempt) startBehaviour;
  late FakeVehiclesRepository repo;
  late FakeAuthNotifier auth;
  late ProviderContainer container;
  late List<RealtimeStatus> statuses;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump();
    }
  }

  Future<void> startApp(
    WidgetTester tester, {
    DateTime? expiresAt,
    Future<void> Function()? Function(int attempt)? behaviour,
  }) async {
    now = t0;
    log = [];
    connections = [];
    statuses = [];
    startBehaviour = behaviour ?? (_) => null;
    repo = FakeVehiclesRepository()
      ..listAnswers.add(() {
        log.add('list');
        return [vehicle(id: 'a', updatedAt: t0)];
      });
    container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => now),
        authProvider.overrideWith(
          () => auth = FakeAuthNotifier(
            expiresAt ?? t0.add(const Duration(hours: 1)),
          ),
        ),
        vehiclesRepositoryProvider.overrideWithValue(repo),
        realtimeConnectionFactoryProvider.overrideWithValue(() {
          final c = FakeRealtimeConnection(
            log,
            onStart: startBehaviour(connections.length),
          );
          connections.add(c);
          return c;
        }),
      ],
      retry: (_, _) => null,
    );
    await container.read(authProvider.future);
    await container.read(
      vehicleListProvider.future,
    ); // the app's fast first fetch
    log.clear();
    container.listen(
      realtimeControllerProvider,
      (_, next) => statuses.add(next.status),
      fireImmediately: true,
    );
    await settle(tester);
  }

  RealtimeState stateOf() => container.read(realtimeControllerProvider);

  Future<void> finish(WidgetTester tester) async {
    container.dispose();
    await tester.pump();
  }

  testWidgets('connects the hub FIRST, then fetches the snapshot', (
    tester,
  ) async {
    await startApp(tester);

    expect(log, ['start', 'list']);
    expect(stateOf().status, RealtimeStatus.connected);
    expect(
      statuses.first,
      RealtimeStatus.connecting,
    ); // first attempt: no banner
    expect(
      statuses.map((s) => RealtimeState(s).banner),
      isNot(contains(BannerConnectionState.reconnecting)),
    );
    await finish(tester);
  });

  testWidgets('after an automatic reconnect the snapshot is fetched again', (
    tester,
  ) async {
    await startApp(tester);
    log.clear();

    connections.last.link.add(const LinkReconnecting());
    await settle(tester);
    expect(stateOf().banner, BannerConnectionState.reconnecting);

    connections.last.link.add(const LinkReconnected());
    await settle(tester);

    expect(log, ['list']);
    expect(stateOf().status, RealtimeStatus.connected);
    await finish(tester);
  });

  testWidgets('VehicleUpdated is applied only when newer (updatedAt)', (
    tester,
  ) async {
    await startApp(tester);
    final list = container.read(vehicleListProvider.notifier);

    connections.last.vehicles.add(
      vehicle(
        id: 'a',
        status: 'Fault',
        updatedAt: t0.subtract(const Duration(seconds: 1)),
      ),
    );
    await settle(tester);
    expect(
      container.read(vehicleListProvider).value!.byId('a')!.status,
      VehicleStatus.moving,
    );

    connections.last.vehicles.add(
      vehicle(
        id: 'a',
        status: 'Fault',
        updatedAt: t0.add(const Duration(seconds: 1)),
      ),
    );
    await settle(tester);
    expect(
      container.read(vehicleListProvider).value!.byId('a')!.status,
      VehicleStatus.fault,
    );
    expect(list, isNotNull);
    await finish(tester);
  });

  testWidgets(
    'banner: connected → reconnecting → disconnected → Retry → connected',
    (tester) async {
      await startApp(tester);

      connections.last.link.add(const LinkReconnecting());
      await settle(tester);
      expect(stateOf().banner, BannerConnectionState.reconnecting);

      now = t0.add(const Duration(minutes: 1));
      connections.last.link.add(const LinkClosed());
      await settle(tester);
      expect(stateOf().banner, BannerConnectionState.disconnected);
      expect(
        stateOf().disconnectedSince,
        t0,
        reason: '"paused since" is when updates first stopped',
      );

      container.read(realtimeControllerProvider.notifier).retryNow();
      expect(stateOf().banner, BannerConnectionState.reconnecting);
      await settle(tester);

      expect(stateOf().status, RealtimeStatus.connected);
      expect(
        connections,
        hasLength(2),
        reason: 'a closed connection is replaced by a new one',
      );
      expect(log.last, 'list', reason: 'snapshot after the new connection');
      await finish(tester);
    },
  );

  testWidgets('after close, retries every 30 s until it works', (tester) async {
    await startApp(tester);
    // Attempt 0 was the initial connect. Retry #1 (attempt 1) fails, retry #2 (attempt 2) succeeds.
    startBehaviour = (attempt) =>
        attempt < 2 ? () async => throw Exception('no network') : null;

    connections.last.link.add(const LinkClosed());
    await settle(tester);
    expect(connections, hasLength(1));

    await tester.pump(const Duration(seconds: 30));
    await settle(tester);
    expect(connections, hasLength(2));
    expect(stateOf().status, RealtimeStatus.disconnected);

    await tester.pump(const Duration(seconds: 30));
    await settle(tester);
    expect(connections, hasLength(3));
    expect(
      stateOf().status,
      RealtimeStatus.connected,
      reason:
          'statuses=$statuses starts=${connections.map((c) => c.starts)} log=$log',
    );
    await finish(tester);
  });

  testWidgets(
    'only one connection attempt at a time (Retry + 30 s loop while start() is in flight)',
    (tester) async {
      await startApp(tester);
      final gate = Completer<void>();
      startBehaviour = (_) =>
          () => gate.future;
      connections.last.link.add(const LinkClosed());
      await settle(tester);

      container
          .read(realtimeControllerProvider.notifier)
          .retryNow(); // starts attempt #2, which hangs
      await settle(tester);
      container.read(realtimeControllerProvider.notifier).retryNow();
      await tester.pump(const Duration(seconds: 61));
      await settle(tester);

      expect(connections, hasLength(2));
      expect(connections.last.starts, 1);
      gate.complete();
      await settle(tester);
      expect(stateOf().status, RealtimeStatus.connected);
      await finish(tester);
    },
  );

  testWidgets('the 30 s loop never runs during the automatic reconnect', (
    tester,
  ) async {
    await startApp(tester);

    connections.last.link.add(const LinkReconnecting());
    await settle(tester);
    await tester.pump(const Duration(minutes: 2));
    await settle(tester);

    expect(connections, hasLength(1));
    expect(stateOf().status, RealtimeStatus.reconnecting);
    await finish(tester);
  });

  testWidgets(
    'closed with an expired token → logout as "session expired", no Disconnected',
    (tester) async {
      await startApp(tester, expiresAt: t0.add(const Duration(minutes: 1)));

      now = t0.add(const Duration(minutes: 1)); // server closes the hub at exp
      connections.last.link.add(const LinkClosed());
      await settle(tester);

      expect(auth.logouts, [LogoutReason.sessionExpired]);
      expect(statuses, isNot(contains(RealtimeStatus.disconnected)));
      await tester.pump(const Duration(minutes: 1));
      expect(
        connections,
        hasLength(1),
        reason: 'nothing reconnects after logout',
      );
      await finish(tester);
    },
  );

  testWidgets('401 on the first connect → logout as "unauthorized", no retry', (
    tester,
  ) async {
    await startApp(
      tester,
      behaviour: (_) =>
          () async => throw const RealtimeUnauthorized(),
    );

    expect(auth.logouts, [LogoutReason.unauthorized]);
    expect(statuses, isNot(contains(RealtimeStatus.disconnected)));
    await tester.pump(const Duration(minutes: 2));
    await settle(tester);
    expect(connections, hasLength(1), reason: 'no retry after a 401');
    await finish(tester);
  });

  testWidgets(
    '401 during the automatic reconnect → logout, no Disconnected, no 30 s loop',
    (tester) async {
      await startApp(tester);
      connections.last.link.add(const LinkReconnecting());
      await settle(tester);

      // The adapter closes with RealtimeUnauthorized when the reconnect's negotiate got 401.
      connections.last.link.add(const LinkClosed(RealtimeUnauthorized()));
      await settle(tester);

      expect(auth.logouts, [LogoutReason.unauthorized]);
      expect(statuses, isNot(contains(RealtimeStatus.disconnected)));
      await tester.pump(const Duration(minutes: 2));
      await settle(tester);
      expect(connections, hasLength(1));
      await finish(tester);
    },
  );

  testWidgets('401 on a 30 s retry → logout, and the retry loop stops', (
    tester,
  ) async {
    await startApp(tester);
    startBehaviour = (_) =>
        () async => throw const RealtimeUnauthorized();
    connections.last.link.add(const LinkClosed()); // network drop
    await settle(tester);
    expect(stateOf().status, RealtimeStatus.disconnected);

    await tester.pump(RealtimeController.retryInterval);
    await settle(tester);
    expect(connections, hasLength(2));
    expect(auth.logouts, [LogoutReason.unauthorized]);

    await tester.pump(const Duration(minutes: 2));
    await settle(tester);
    expect(connections, hasLength(2), reason: 'the 30 s timer was cancelled');
    await finish(tester);
  });

  testWidgets(
    '503 / network error on reconnect → Disconnected and retry as before',
    (tester) async {
      await startApp(tester);
      startBehaviour = (attempt) => attempt == 1
          ? () async => throw Exception('503: Service Unavailable')
          : null;
      connections.last.link.add(LinkClosed(Exception('connection lost')));
      await settle(tester);
      expect(stateOf().banner, BannerConnectionState.disconnected);

      await tester.pump(RealtimeController.retryInterval); // attempt 1: 503
      await settle(tester);
      expect(stateOf().status, RealtimeStatus.disconnected);

      await tester.pump(RealtimeController.retryInterval); // attempt 2: ok
      await settle(tester);
      expect(stateOf().status, RealtimeStatus.connected);
      expect(connections, hasLength(3));
      expect(auth.logouts, isEmpty);
      await finish(tester);
    },
  );

  testWidgets(
    'logout during Reconnecting → connection stopped, no further start() or re-fetch',
    (tester) async {
      await startApp(tester);
      final old = connections.last;
      old.link.add(const LinkReconnecting());
      await settle(tester);
      log.clear();

      await container
          .read(authProvider.notifier)
          .logout(LogoutReason.userRequested);
      await settle(tester);
      old.link.add(
        const LinkReconnected(),
      ); // late event from the stopped connection
      old.link.add(const LinkClosed());
      await tester.pump(const Duration(minutes: 2));
      await settle(tester);

      expect(old.stops, 1);
      expect(log, ['stop']);
      expect(connections, hasLength(1));
      expect(stateOf().status, RealtimeStatus.idle);
      await finish(tester);
    },
  );

  testWidgets('late events from a replaced connection are ignored', (
    tester,
  ) async {
    await startApp(tester);
    final first = connections.last;
    first.link.add(const LinkClosed());
    await settle(tester);
    container.read(realtimeControllerProvider.notifier).retryNow();
    await settle(tester);
    expect(connections, hasLength(2));

    first.vehicles.add(
      vehicle(
        id: 'a',
        status: 'Fault',
        updatedAt: t0.add(const Duration(hours: 1)),
      ),
    );
    first.link.add(const LinkClosed());
    await settle(tester);

    expect(
      container.read(vehicleListProvider).value!.byId('a')!.status,
      VehicleStatus.moving,
    );
    expect(stateOf().status, RealtimeStatus.connected);
    await finish(tester);
  });

  testWidgets(
    'pause: stopped on purpose, no banner, no retries; resume: reconnect then re-fetch',
    (tester) async {
      await startApp(tester);
      final controller = container.read(realtimeControllerProvider.notifier);

      controller.pause();
      await settle(tester);
      expect(stateOf().status, RealtimeStatus.paused);
      expect(stateOf().banner, BannerConnectionState.connected); // hidden
      expect(connections.single.stops, 1);
      connections.single.link.add(
        const LinkClosed(),
      ); // the stop's own close event
      await tester.pump(const Duration(minutes: 2));
      await settle(tester);
      expect(connections, hasLength(1));
      log.clear();

      controller.resume();
      await settle(tester);

      expect(log, ['start', 'list']);
      expect(stateOf().status, RealtimeStatus.connected);
      await finish(tester);
    },
  );
}
