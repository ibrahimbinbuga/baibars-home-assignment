import 'package:flutter/material.dart';

/// Draws a dashed rounded-rectangle outline around [child] (used for the stale vehicle card).
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.child,
    required this.color,
    required this.radius,
  });

  final Widget child;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _DashedRRectPainter(color, radius),
    child: child,
  );
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter(this.color, this.radius);

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.5),
          Radius.circular(radius),
        ),
      );
    canvas.drawPath(dashPath(path, dash: 5, gap: 4), paint);
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}

/// Returns [source] as dashes of [dash] length separated by [gap].
Path dashPath(Path source, {required double dash, required double gap}) {
  final result = Path();
  for (final metric in source.computeMetrics()) {
    for (var d = 0.0; d < metric.length; d += dash + gap) {
      result.addPath(metric.extractPath(d, d + dash), Offset.zero);
    }
  }
  return result;
}
