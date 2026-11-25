import 'package:fleet_monitor/features/activity/data/telemetry.dart';
import 'package:fleet_monitor/features/activity/state/telemetry_history.dart';
import 'package:fleet_monitor/features/activity/ui/history_chart.dart';
import 'package:flutter_test/flutter_test.dart';

TelemetryPoint p(DateTime t, {double battery = 50, double speed = 10}) =>
    TelemetryPoint(
      sequence: t.millisecondsSinceEpoch,
      recordedAt: t,
      receivedAt: t,
      latitude: 36.9,
      longitude: 34.9,
      speedKmh: speed,
      headingDeg: 0,
      batteryPct: battery,
      state: VehicleState.moving,
    );

void main() {
  final t = DateTime.utc(2026, 11, 26, 14);

  test(
    'a pause longer than 30 s becomes a gap row between the two samples',
    () {
      final newestFirst = [
        p(t.add(const Duration(seconds: 64))),
        p(t.add(const Duration(seconds: 2))),
        p(t),
      ];

      final rows = buildHistoryRows(newestFirst);

      expect(rows, hasLength(4));
      expect(rows[0], isA<SampleRow>());
      final gap = rows[1] as GapRow;
      expect(gap.from, t.add(const Duration(seconds: 2)));
      expect(gap.to, t.add(const Duration(seconds: 64)));
      expect(rows[2], isA<SampleRow>());
      expect(rows[3], isA<SampleRow>());
    },
  );

  test('regular 2 s samples produce no gap rows', () {
    final newestFirst = [
      for (var i = 10; i >= 0; i--) p(t.add(Duration(seconds: i * 2))),
    ];

    expect(buildHistoryRows(newestFirst).whereType<GapRow>(), isEmpty);
  });

  test('chart: samples are averaged per minute and lines break at gaps', () {
    final oldestFirst = [
      p(t, battery: 80, speed: 10),
      p(
        t.add(const Duration(seconds: 30)),
        battery: 70,
        speed: 20,
      ), // same minute → averaged
      p(
        t.add(const Duration(seconds: 60)),
        battery: 60,
        speed: 0,
      ), // next minute
      p(
        t.add(const Duration(minutes: 5)),
        battery: 50,
        speed: 5,
      ), // after an offline gap
    ];

    final segments = chartSegments(oldestFirst);

    expect(segments, hasLength(2));
    expect(segments[0].map((c) => c.batteryPct), [75, 60]);
    expect(segments[0].first.speedKmh, 15);
    expect(segments[1].single.batteryPct, 50);
  });
}
