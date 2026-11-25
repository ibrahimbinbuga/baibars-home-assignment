import 'dart:async';

import 'package:fleet_monitor/core/api/api_exception.dart';
import 'package:fleet_monitor/core/auth/auth_notifier.dart';
import 'package:fleet_monitor/core/clock.dart';
import 'package:fleet_monitor/core/theme/app_theme.dart';
import 'package:fleet_monitor/features/vehicles/data/fleet.dart';
import 'package:fleet_monitor/features/vehicles/data/fleets_repository.dart';
import 'package:fleet_monitor/features/vehicles/data/vehicle.dart';
import 'package:fleet_monitor/features/vehicles/data/vehicles_repository.dart';
import 'package:fleet_monitor/features/vehicles/ui/vehicle_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';

void main() {
  final now = DateTime.utc(2026, 11, 26, 10);
  late FakeVehiclesRepository repo;

  Vehicle v(String id, String name, String status) => Vehicle.fromJson({
        ...vehicleJson(id: id, status: status),
        'name': name,
        'lastSeenAt': now.subtract(const Duration(seconds: 3)).toIso8601String(),
      });

  final vehicles = [v('1', 'TR-01', 'Moving'), v('2', 'TR-02', 'Idle')];

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        vehiclesRepositoryProvider.overrideWithValue(repo),
        fleetsRepositoryProvider.overrideWithValue(
            FakeFleetsRepository(const [Fleet(id: 'f-1', name: 'Tarsus Field Ops', region: 'Tarsus')])),
        currentUserIdProvider.overrideWithValue('u-1'),
        clockProvider.overrideWithValue(() => now),
      ],
      retry: (_, _) => null,
      child: MaterialApp(theme: AppTheme.light(), home: const Scaffold(body: VehicleListScreen())),
    ));
  }

  setUp(() => repo = FakeVehiclesRepository());

  testWidgets('loading shows the skeleton, then the vehicles', (tester) async {
    final response = Completer<List<Vehicle>>();
    repo.listAnswers.add(() => response.future);

    await pumpScreen(tester);
    expect(find.byKey(const Key('listSkeleton')), findsOneWidget);

    response.complete(vehicles);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('listSkeleton')), findsNothing);
    expect(find.text('TR-01'), findsOneWidget);
    expect(find.text('TR-02'), findsOneWidget);
    expect(find.text('2 of 2 vehicles · Tarsus Field Ops'), findsOneWidget);
  });

  testWidgets('one fleet → no fleet filter chip', (tester) async {
    repo.listAnswers.add(() => vehicles);

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('All fleets'), findsNothing);
  });

  testWidgets('a filter with no matches shows the empty state; Clear filters brings the list back', (tester) async {
    repo.listAnswers.add(() => vehicles);
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(InkWell, 'Fault').last); // the "Fault" filter chip
    await tester.pumpAndSettle();

    expect(find.text('No vehicles match this filter'), findsOneWidget);
    expect(find.text('No Fault vehicles right now.'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    expect(find.text('TR-01'), findsOneWidget);
  });

  testWidgets('a failed first load shows the error; Retry loads again', (tester) async {
    repo.listAnswers
      ..add(() => throw const ApiException(kind: ApiErrorKind.network, title: 'Cannot reach the server'))
      ..add(() => vehicles);

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('Couldn’t load vehicles'), findsOneWidget);
    expect(find.text('The server didn’t respond. Check your connection and try again.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('retryButton')));
    await tester.pumpAndSettle();

    expect(find.text('TR-01'), findsOneWidget);
    expect(repo.listCalls, 2);
  });

  testWidgets('a user with no vehicles sees a plain empty message, not a filter message', (tester) async {
    repo.listAnswers.add(() => <Vehicle>[]);

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('No vehicles yet'), findsOneWidget);
    expect(find.text('Clear filters'), findsNothing);
  });
}
