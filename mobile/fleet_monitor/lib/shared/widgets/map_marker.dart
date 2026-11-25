import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/status_colors.dart';
import '../../features/vehicles/domain/display_status.dart';
import 'dashed_border.dart';

enum MarkerShape { circle, roundedSquare, diamond, triangle }

/// MapMarker: the shape encodes the status, so markers read without colour (Components.dc.html):
/// Moving = circle + arrow rotated to heading, Idle = rounded square + pause, Charging = diamond + bolt,
/// Fault = triangle + "!", Offline = hollow circle + wifi-off, Stale = the last shape, hollow with a dashed outline.
/// Drawn 36 px; selected = larger with a ring. The caller gives it a ≥ 48 px hit area.
class MapMarker extends StatelessWidget {
  const MapMarker({
    super.key,
    required this.status,
    this.lastReportedStatus,
    this.headingDeg,
    this.selected = false,
  });

  final DisplayStatus status;

  /// For stale markers: the status the vehicle last reported, which decides the shape and icon.
  final DisplayStatus? lastReportedStatus;
  final double? headingDeg;
  final bool selected;

  static const size = 36.0;
  static const selectedSize = 52.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.statusColors;
    final stale = status == DisplayStatus.stale;
    final shapeStatus = stale
        ? (lastReportedStatus ?? DisplayStatus.moving)
        : status;
    final hollow = stale || status == DisplayStatus.offline;
    final color = colors.of(status).foreground;
    final shape = shapeOf(shapeStatus);
    final (icon, rotates) = switch (shapeStatus) {
      DisplayStatus.moving || DisplayStatus.stale => (Icons.navigation, true),
      DisplayStatus.idle => (Icons.pause, false),
      DisplayStatus.charging => (Icons.bolt, false),
      DisplayStatus.fault => (Icons.priority_high, false),
      DisplayStatus.offline => (Icons.wifi_off, false),
    };
    final boxSize = selected ? selectedSize : size;

    return SizedBox.square(
      dimension: boxSize,
      child: CustomPaint(
        painter: _MarkerPainter(
          shape: shape,
          fill: hollow ? AppPalette.surface : color,
          stroke: hollow ? color : AppPalette.surface,
          dashed: stale,
          selected: selected,
        ),
        child: Padding(
          // The triangle's visual centre is lower than the box centre.
          padding: EdgeInsets.only(
            top: shape == MarkerShape.triangle ? boxSize * 0.18 : 0,
          ),
          child: Center(
            child: Transform.rotate(
              angle: rotates ? (headingDeg ?? 0) * math.pi / 180 : 0,
              child: Icon(
                icon,
                size: (selected ? 36 : size) * 0.45,
                color: hollow ? color : AppPalette.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static MarkerShape shapeOf(DisplayStatus status) => switch (status) {
    DisplayStatus.idle => MarkerShape.roundedSquare,
    DisplayStatus.charging => MarkerShape.diamond,
    DisplayStatus.fault => MarkerShape.triangle,
    DisplayStatus.moving ||
    DisplayStatus.offline ||
    DisplayStatus.stale => MarkerShape.circle,
  };
}

class _MarkerPainter extends CustomPainter {
  _MarkerPainter({
    required this.shape,
    required this.fill,
    required this.stroke,
    required this.dashed,
    required this.selected,
  });

  final MarkerShape shape;
  final Color fill;
  final Color stroke;
  final bool dashed;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    if (selected) {
      final center = size.center(Offset.zero);
      final radius = size.width / 2 - 1.5;
      canvas.drawCircle(center, radius, Paint()..color = AppPalette.surface);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = AppPalette.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    // The shape is defined in a 40×40 box (as in the design) and scaled into a 36 px area.
    final shapeSize = MapMarker.size;
    final scale = shapeSize / 40;
    final offset = Offset(
      (size.width - shapeSize) / 2,
      (size.height - shapeSize) / 2,
    );
    final path = _shapePath().transform(
      (Matrix4.identity()
            ..translateByDouble(offset.dx, offset.dy, 0, 1)
            ..scaleByDouble(scale, scale, 1, 1))
          .storage,
    );

    canvas.drawShadow(path, const Color(0x59000000), 2, false);
    canvas.drawPath(path, Paint()..color = fill);
    final strokePaint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      dashed ? dashPath(path, dash: 4, gap: 3) : path,
      strokePaint,
    );
  }

  Path _shapePath() => switch (shape) {
    MarkerShape.circle =>
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(20, 20), radius: 18)),
    MarkerShape.roundedSquare =>
      Path()..addRRect(RRect.fromLTRBR(3, 3, 37, 37, const Radius.circular(4))),
    MarkerShape.diamond =>
      Path()
        ..moveTo(20, 0)
        ..lineTo(40, 20)
        ..lineTo(20, 40)
        ..lineTo(0, 20)
        ..close(),
    MarkerShape.triangle =>
      Path()
        ..moveTo(20, 2)
        ..lineTo(39, 36)
        ..lineTo(1, 36)
        ..close(),
  };

  @override
  bool shouldRepaint(_MarkerPainter old) =>
      old.shape != shape ||
      old.fill != fill ||
      old.stroke != stroke ||
      old.dashed != dashed ||
      old.selected != selected;
}
