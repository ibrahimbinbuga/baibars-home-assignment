import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/time_format.dart';
import '../../../shared/widgets/dashed_border.dart';
import '../data/telemetry.dart';
import '../state/telemetry_history.dart';

/// Battery (solid, left axis 0–100 %) and speed (dashed, right axis) over the loaded window, with offline gaps
/// shaded (Detail.dc.html 4.2). Drawn with a CustomPainter: no chart package.
class HistoryChart extends StatelessWidget {
  const HistoryChart({super.key, required this.points});

  /// Newest first.
  final List<TelemetryPoint> points;

  static const speedColor = Color(0xFF0E7490);
  static const speedAxisColor = Color(0xFF0E6276);

  @override
  Widget build(BuildContext context) {
    final oldestFirst = points.reversed.toList();
    final maxSpeed = oldestFirst.fold<double>(
      0,
      (m, p) => math.max(m, p.speedKmh),
    );
    // Round the speed axis up to a multiple of 10 km/h (at least 20) so labels are readable.
    final speedAxisMax = math.max(20, (maxSpeed / 10).ceil() * 10).toDouble();
    final first = oldestFirst.first.recordedAt;
    final last = oldestFirst.last.recordedAt;

    return Container(
      color: AppPalette.surface,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LegendItem(
                label: 'Battery %',
                dashed: false,
                color: AppPalette.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              _LegendItem(label: 'Speed km/h', dashed: true, color: speedColor),
            ],
          ),
          const SizedBox(height: 10),
          Semantics(
            label: _summary(oldestFirst, maxSpeed),
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: CustomPaint(
                painter: _ChartPainter(
                  points: oldestFirst,
                  speedAxisMax: speedAxisMax,
                  labelStyle: AppText.labelSmall.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppPalette.textMuted,
                  ),
                  startLabel: clockTimeShort(first),
                  midLabel: clockTimeShort(
                    first.add(last.difference(first) ~/ 2),
                  ),
                  endLabel: clockTimeShort(last),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _summary(List<TelemetryPoint> oldestFirst, double maxSpeed) =>
      'Battery went from ${oldestFirst.first.batteryPct.round()}% to ${oldestFirst.last.batteryPct.round()}%; '
      'top speed ${maxSpeed.toStringAsFixed(1)} km/h.';
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.label,
    required this.dashed,
    required this.color,
  });

  final String label;
  final bool dashed;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CustomPaint(
        size: const Size(18, 3),
        painter: _LegendLinePainter(color, dashed),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: AppText.labelMedium.copyWith(color: AppPalette.textMuted),
      ),
    ],
  );
}

class _LegendLinePainter extends CustomPainter {
  _LegendLinePainter(this.color, this.dashed);

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width, size.height / 2);
    canvas.drawPath(
      dashed ? dashPath(path, dash: 5, gap: 3) : path,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_LegendLinePainter old) => false;
}

/// One plotted point: the average of the samples in one time bucket.
class ChartPoint {
  const ChartPoint(this.time, this.batteryPct, this.speedKmh);

  final DateTime time;
  final double batteryPct;
  final double speedKmh;
}

/// Averages oldest-first samples into [bucket]-long buckets (one sample every ~2 s is too noisy to plot), and splits
/// the result into segments wherever there is an offline gap, so no line is drawn across it.
List<List<ChartPoint>> chartSegments(
  List<TelemetryPoint> oldestFirst, {
  Duration bucket = const Duration(minutes: 1),
  Duration gap = historyGapThreshold,
}) {
  final segments = <List<ChartPoint>>[];
  var current = <TelemetryPoint>[];
  var segment = <ChartPoint>[];

  void flushBucket() {
    if (current.isEmpty) return;
    final n = current.length;
    final midMs =
        (current.first.recordedAt.millisecondsSinceEpoch +
            current.last.recordedAt.millisecondsSinceEpoch) ~/
        2;
    segment.add(
      ChartPoint(
        DateTime.fromMillisecondsSinceEpoch(midMs, isUtc: true),
        current.fold<double>(0, (sum, p) => sum + p.batteryPct) / n,
        current.fold<double>(0, (sum, p) => sum + p.speedKmh) / n,
      ),
    );
    current = [];
  }

  for (var i = 0; i < oldestFirst.length; i++) {
    final point = oldestFirst[i];
    if (i > 0 &&
        point.recordedAt.difference(oldestFirst[i - 1].recordedAt) > gap) {
      flushBucket();
      segments.add(segment);
      segment = [];
    } else if (current.isNotEmpty &&
        point.recordedAt.difference(current.first.recordedAt) >= bucket) {
      flushBucket();
    }
    current.add(point);
  }
  flushBucket();
  if (segment.isNotEmpty) segments.add(segment);
  return segments;
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.points,
    required this.speedAxisMax,
    required this.labelStyle,
    required this.startLabel,
    required this.midLabel,
    required this.endLabel,
  });

  final List<TelemetryPoint> points; // oldest first
  final double speedAxisMax;
  final TextStyle labelStyle;
  final String startLabel;
  final String midLabel;
  final String endLabel;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0, rightPad = 34.0, top = 10.0, bottomAxis = 110.0;
    final right = size.width - rightPad;
    final plotHeight = bottomAxis - top;
    final t0 = points.first.recordedAt;
    final span = math.max(
      1,
      points.last.recordedAt.difference(t0).inMilliseconds,
    );
    double x(DateTime t) =>
        left + (t.difference(t0).inMilliseconds / span) * (right - left);
    double yBattery(double b) =>
        bottomAxis - (b.clamp(0, 100) / 100) * plotHeight;
    double ySpeed(double s) =>
        bottomAxis - (s.clamp(0, speedAxisMax) / speedAxisMax) * plotHeight;

    // Grid: 100 / 50 / 0.
    final grid = Paint()..color = AppPalette.divider;
    canvas.drawLine(Offset(left, top), Offset(right, top), grid);
    canvas.drawLine(
      Offset(left, top + plotHeight / 2),
      Offset(right, top + plotHeight / 2),
      grid,
    );
    canvas.drawLine(
      Offset(left, bottomAxis),
      Offset(right, bottomAxis),
      Paint()..color = AppPalette.hint,
    );

    // Offline gaps shaded from the raw samples.
    for (var i = 1; i < points.length; i++) {
      if (points[i].recordedAt.difference(points[i - 1].recordedAt) >
          historyGapThreshold) {
        final gapLeft = x(points[i - 1].recordedAt),
            gapRight = x(points[i].recordedAt);
        canvas.drawRect(
          Rect.fromLTRB(gapLeft, top, gapRight, bottomAxis),
          Paint()..color = AppPalette.fleetIconBackground,
        );
        if (gapRight - gapLeft > 40) {
          _text(
            canvas,
            'offline',
            Offset((gapLeft + gapRight) / 2, top + plotHeight / 2),
            center: true,
          );
        }
      }
    }

    final battery = Paint()
      ..color = AppPalette.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final speed = Paint()
      ..color = HistoryChart.speedColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    // Lines: per-minute averages, broken at gaps.
    for (final segment in chartSegments(points)) {
      final b = Path(), sp = Path();
      for (var k = 0; k < segment.length; k++) {
        final p = segment[k];
        final px = x(p.time);
        if (k == 0) {
          b.moveTo(px, yBattery(p.batteryPct));
          sp.moveTo(px, ySpeed(p.speedKmh));
        } else {
          b.lineTo(px, yBattery(p.batteryPct));
          sp.lineTo(px, ySpeed(p.speedKmh));
        }
      }
      canvas.drawPath(dashPath(sp, dash: 5, gap: 3), speed);
      canvas.drawPath(b, battery);
    }

    // Axis labels.
    _text(canvas, '100', Offset(left - 6, top), alignRight: true);
    _text(
      canvas,
      '50',
      Offset(left - 6, top + plotHeight / 2),
      alignRight: true,
    );
    _text(canvas, '0', Offset(left - 6, bottomAxis), alignRight: true);
    final speedLabel = labelStyle.copyWith(color: HistoryChart.speedAxisColor);
    _text(
      canvas,
      speedAxisMax.round().toString(),
      Offset(right + 6, top),
      style: speedLabel,
    );
    _text(
      canvas,
      (speedAxisMax / 2).round().toString(),
      Offset(right + 6, top + plotHeight / 2),
      style: speedLabel,
    );
    _text(canvas, startLabel, Offset(left, bottomAxis + 14));
    _text(
      canvas,
      midLabel,
      Offset((left + right) / 2, bottomAxis + 14),
      center: true,
    );
    _text(canvas, endLabel, Offset(right, bottomAxis + 14), alignRight: true);
  }

  /// Draws [text] vertically centred on [at.dy].
  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    bool alignRight = false,
    bool center = false,
    TextStyle? style,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style ?? labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignRight
        ? at.dx - painter.width
        : (center ? at.dx - painter.width / 2 : at.dx);
    painter.paint(canvas, Offset(dx, at.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.points != points || old.speedAxisMax != speedAxisMax;
}
