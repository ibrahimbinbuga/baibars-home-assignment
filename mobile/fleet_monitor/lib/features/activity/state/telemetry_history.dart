import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../vehicles/data/vehicles_repository.dart';
import '../data/telemetry.dart';

/// One row of the History tab: a sample, or a gap where no samples arrived.
sealed class HistoryRow {
  const HistoryRow();
}

class SampleRow extends HistoryRow {
  const SampleRow(this.point);

  final TelemetryPoint point;
}

/// No samples between [from] and [to] (longer than the offline threshold): the vehicle was offline.
class GapRow extends HistoryRow {
  const GapRow({required this.from, required this.to});

  final DateTime from;
  final DateTime to;
}

/// A pause longer than the server's offline threshold means the vehicle was offline in between.
const historyGapThreshold = Duration(seconds: 30);

/// Turns newest-first points into rows, inserting a [GapRow] wherever two neighbours are further apart than [gap].
List<HistoryRow> buildHistoryRows(
  List<TelemetryPoint> newestFirst, {
  Duration gap = historyGapThreshold,
}) {
  final rows = <HistoryRow>[];
  for (var i = 0; i < newestFirst.length; i++) {
    final point = newestFirst[i];
    if (i > 0) {
      final newer = newestFirst[i - 1];
      if (newer.recordedAt.difference(point.recordedAt) > gap) {
        rows.add(GapRow(from: point.recordedAt, to: newer.recordedAt));
      }
    }
    rows.add(SampleRow(point));
  }
  return rows;
}

class TelemetryHistory {
  const TelemetryHistory({required this.points, required this.rows});

  /// Newest first, as returned by the API.
  final List<TelemetryPoint> points;
  final List<HistoryRow> rows;
}

/// Last hour of telemetry. One sample every ~2 s is ~1800 points, so ask for up to 2000 (the server's maximum).
final telemetryHistoryProvider = FutureProvider.autoDispose
    .family<TelemetryHistory, String>((ref, vehicleId) async {
      final response = await ref
          .read(vehiclesRepositoryProvider)
          .telemetry(vehicleId, limit: 2000);
      return TelemetryHistory(
        points: response.items,
        rows: buildHistoryRows(response.items),
      );
    });
