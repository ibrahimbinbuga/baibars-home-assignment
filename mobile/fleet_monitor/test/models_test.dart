import 'package:fleet_monitor/core/api/problem_details.dart';
import 'package:fleet_monitor/features/activity/data/activity_event.dart';
import 'package:fleet_monitor/features/activity/data/telemetry.dart';
import 'package:fleet_monitor/features/auth/data/auth_models.dart';
import 'package:fleet_monitor/features/vehicles/data/fleet.dart';
import 'package:fleet_monitor/features/vehicles/data/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';

void main() {
  group('Vehicle', () {
    test('parses a full VehicleDto', () {
      final v = Vehicle.fromJson(vehicleJson());

      expect(v.id, 'v-1');
      expect(v.fleetName, 'Tarsus Field Ops');
      expect(v.status, VehicleStatus.moving);
      expect(v.connectivity, Connectivity.online);
      expect(v.latitude, 36.92);
      expect(v.headingDeg, 270.0); // integer in JSON → double
      expect(v.batteryPct, 76.0);
      expect(v.lastTelemetryAt, DateTime.utc(2026, 11, 26, 10));
      expect(v.updatedAt, DateTime.utc(2026, 11, 26, 10, 0, 1, 0, 1));
      expect(v.hasLocation, isTrue);
    });

    test(
      'vehicle without telemetry: location, metrics and timestamps are null',
      () {
        final v = Vehicle.fromJson({
          ...vehicleJson(status: 'Offline'),
          'latitude': null,
          'longitude': null,
          'speedKmh': null,
          'headingDeg': null,
          'batteryPct': null,
          'lastTelemetryAt': null,
          'lastSeenAt': null,
        });

        expect(v.status, VehicleStatus.offline);
        expect(v.connectivity, Connectivity.offline);
        expect([
          v.latitude,
          v.longitude,
          v.speedKmh,
          v.headingDeg,
          v.batteryPct,
        ], everyElement(isNull));
        expect(v.lastTelemetryAt, isNull);
        expect(v.lastSeenAt, isNull);
        expect(v.hasLocation, isFalse);
      },
    );

    test(
      'unknown status and connectivity become "unknown" instead of crashing',
      () {
        final v = Vehicle.fromJson({
          ...vehicleJson(),
          'status': 'Hovering',
          'connectivity': 'Satellite',
        });

        expect(v.status, VehicleStatus.unknown);
        expect(v.connectivity, Connectivity.unknown);
      },
    );

    test('timestamps with +00:00 offset are parsed as UTC', () {
      final v = Vehicle.fromJson({
        ...vehicleJson(),
        'updatedAt': '2026-11-25T11:50:18.872497+00:00',
      });

      expect(v.updatedAt.isUtc, isTrue);
      expect(v.updatedAt, DateTime.utc(2026, 11, 25, 11, 50, 18, 872, 497));
    });

    test('missing required field throws FormatException', () {
      final json = vehicleJson()..remove('name');

      expect(() => Vehicle.fromJson(json), throwsFormatException);
    });
  });

  group('Activity', () {
    test('parses a page with a cursor', () {
      final page = ActivityPage.fromJson({
        'items': [
          {
            'id': 981,
            'vehicleId': 'v-1',
            'type': 'StateChanged',
            'occurredAt': '2026-11-26T10:00:00Z',
            'details': 'Idle → Moving',
          },
        ],
        'nextBefore': 'NjM5XzEw',
      });

      expect(page.items.single.type, ActivityEventType.stateChanged);
      expect(page.items.single.details, 'Idle → Moving');
      expect(page.nextBefore, 'NjM5XzEw');
      expect(page.hasMore, isTrue);
    });

    test('last page has null nextBefore', () {
      final page = ActivityPage.fromJson({
        'items': <Object>[],
        'nextBefore': null,
      });

      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('unknown event type becomes "unknown"', () {
      final e = ActivityEvent.fromJson({
        'id': 1,
        'vehicleId': 'v-1',
        'type': 'Teleported',
        'occurredAt': '2026-11-26T10:00:00Z',
        'details': '',
      });

      expect(e.type, ActivityEventType.unknown);
    });

    test('all known event types parse', () {
      for (final (raw, expected) in [
        ('CameOnline', ActivityEventType.cameOnline),
        ('WentOffline', ActivityEventType.wentOffline),
        ('StateChanged', ActivityEventType.stateChanged),
        ('LowBattery', ActivityEventType.lowBattery),
        ('FaultRaised', ActivityEventType.faultRaised),
      ]) {
        final e = ActivityEvent.fromJson({
          'id': 1,
          'vehicleId': 'v',
          'type': raw,
          'occurredAt': '2026-11-26T10:00:00Z',
          'details': '',
        });
        expect(e.type, expected, reason: raw);
      }
    });
  });

  group('Telemetry', () {
    test('parses window and points; unknown state tolerated', () {
      final response = TelemetryResponse.fromJson({
        'from': '2026-11-26T09:00:00Z',
        'to': '2026-11-26T10:00:00Z',
        'items': [
          {
            'sequence':
                1763456789012, // Unix-ms based sequence from the simulator: needs 64-bit int
            'recordedAt': '2026-11-26T09:59:58Z',
            'receivedAt': '2026-11-26T09:59:59Z',
            'latitude': 36.9,
            'longitude': 34.9,
            'speedKmh': 0,
            'headingDeg': 0,
            'batteryPct': 50,
            'state': 'Docked',
          },
        ],
      });

      expect(response.to.difference(response.from), const Duration(hours: 1));
      expect(response.items.single.sequence, 1763456789012);
      expect(response.items.single.speedKmh, 0.0);
      expect(response.items.single.state, VehicleState.unknown);
    });
  });

  group('Auth', () {
    final userJson = {
      'id': 'u-1',
      'email': 'admin@demo.local',
      'displayName': 'Demo Admin',
      'role': 'Admin',
    };

    test('parses LoginResponse', () {
      final r = LoginResponse.fromJson({
        'accessToken': 'jwt',
        'expiresAt': '2026-11-26T11:00:00Z',
        'user': userJson,
      });

      expect(r.accessToken, 'jwt');
      expect(r.expiresAt, DateTime.utc(2026, 11, 26, 11));
      expect(r.user.role, Role.admin);
    });

    test('parses MeResponse with fleets; unknown role tolerated', () {
      final me = MeResponse.fromJson({
        'user': {...userJson, 'role': 'Auditor'},
        'fleets': [
          {'id': 'f-1', 'name': 'Tarsus Field Ops', 'region': 'Tarsus'},
        ],
      });

      expect(me.user.role, Role.unknown);
      expect(me.fleets.single.name, 'Tarsus Field Ops');
    });

    test('Fleet parses', () {
      expect(
        Fleet.fromJson({'id': 'f', 'name': 'N', 'region': 'R'}).region,
        'R',
      );
    });

    test('UserInfo survives a toJson/fromJson round trip (secure storage)', () {
      final user = UserInfo.fromJson(userJson);

      final restored = UserInfo.fromJson(user.toJson());

      expect(restored.role, Role.admin);
      expect(restored.email, user.email);
    });
  });

  group('ProblemDetails', () {
    test('parses status/title/detail and validation errors', () {
      final p = ProblemDetails.fromJson({
        'status': 400,
        'title': 'One or more validation errors occurred.',
        'errors': {
          'from': ["'from' must not be later than 'to'."],
        },
      });

      expect(p.status, 400);
      expect(p.title, 'One or more validation errors occurred.');
      expect(p.detail, isNull);
      expect(p.errors['from'], ["'from' must not be later than 'to'."]);
    });

    test('is lenient with unexpected shapes', () {
      final p = ProblemDetails.fromJson({
        'status': 'oops',
        'title': 3,
        'errors': 'none',
      });

      expect(p.status, isNull);
      expect(p.title, isNull);
      expect(p.errors, isEmpty);
    });
  });
}
