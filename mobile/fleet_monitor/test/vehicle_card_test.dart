import 'package:fleet_monitor/core/theme/app_theme.dart';
import 'package:fleet_monitor/features/vehicles/data/vehicle.dart';
import 'package:fleet_monitor/shared/widgets/dashed_border.dart';
import 'package:fleet_monitor/shared/widgets/vehicle_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';

void main() {
  final now = DateTime.utc(2026, 11, 26, 10);

  Future<void> pump(WidgetTester tester, Vehicle vehicle) => tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: VehicleCard(vehicle: vehicle, now: now))),
      ));

  Vehicle v(Map<String, Object?> overrides) => Vehicle.fromJson({...vehicleJson(), ...overrides});

  testWidgets('normal: status, battery, speed and "updated Xs ago"', (tester) async {
    await pump(tester, v({'lastSeenAt': now.subtract(const Duration(seconds: 4)).toIso8601String(), 'batteryPct': 78}));

    expect(find.text('TR-01'), findsOneWidget);
    expect(find.text('Moving'), findsOneWidget);
    expect(find.text('78%'), findsOneWidget);
    expect(find.text('12.4 km/h'), findsOneWidget);
    expect(find.text('updated 4s ago'), findsOneWidget);
    expect(find.byType(DashedBorder), findsNothing);
  });

  testWidgets('low battery is shown with the alert icon', (tester) async {
    await pump(tester, v({'lastSeenAt': now.toIso8601String(), 'batteryPct': 18}));

    expect(find.byIcon(Icons.battery_alert), findsOneWidget);
    expect(find.text('18%'), findsOneWidget);
  });

  testWidgets('stale: online but silent > 30 s → Stale badge, "last seen", dashed outline', (tester) async {
    await pump(tester, v({'lastSeenAt': now.subtract(const Duration(minutes: 2)).toIso8601String()}));

    expect(find.text('Stale'), findsOneWidget);
    expect(find.text('last seen 2m ago'), findsOneWidget);
    expect(find.byType(DashedBorder), findsOneWidget);
  });

  testWidgets('offline: Offline badge, no speed, "last seen"', (tester) async {
    await pump(tester, v({
      'status': 'Offline',
      'connectivity': 'Offline',
      'lastSeenAt': now.subtract(const Duration(hours: 3)).toIso8601String(),
    }));

    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('— km/h'), findsOneWidget);
    expect(find.text('last seen 3h ago'), findsOneWidget);
  });

  testWidgets('no data yet: never reported', (tester) async {
    await pump(tester, v({
      'status': 'Offline',
      'connectivity': 'Offline',
      'latitude': null,
      'longitude': null,
      'speedKmh': null,
      'headingDeg': null,
      'batteryPct': null,
      'lastTelemetryAt': null,
      'lastSeenAt': null,
    }));

    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('No data yet'), findsOneWidget);
    expect(find.text('Never reported'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('the whole card is one tap target', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: VehicleCard(vehicle: v({'lastSeenAt': now.toIso8601String()}), now: now, onTap: () => taps++)),
    ));

    await tester.tap(find.text('Tarsus Field Ops'));

    expect(taps, 1);
  });
}
