import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/status_colors.dart';
import '../../../core/time_format.dart';
import '../../vehicles/domain/display_status.dart';
import '../../../shared/widgets/status_visuals.dart';
import '../data/telemetry.dart';
import '../state/telemetry_history.dart';
import 'activity_section.dart';
import 'history_chart.dart';

/// History tab content (a sliver): last hour as a chart, then the samples, newest first, with offline gaps.
class HistorySection extends ConsumerWidget {
  const HistorySection({super.key, required this.vehicleId});

  final String vehicleId;

  // time, state (flex), km/h, battery. Time is wider than the design's 78 px so the position fits on one line.
  static const _columns = [112.0, 0.0, 56.0, 52.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(telemetryHistoryProvider(vehicleId));
    return switch (history) {
      AsyncData(:final value) when value.points.isEmpty => SliverToBoxAdapter(
        child: Container(
          color: AppPalette.surface,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'No samples in the last hour.',
            textAlign: TextAlign.center,
            style: AppText.bodyMedium.copyWith(
              color: AppPalette.onSurfaceVariant,
            ),
          ),
        ),
      ),
      AsyncData(:final value) => SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(child: HistoryChart(points: value.points)),
          const SliverToBoxAdapter(child: _HeaderRow()),
          SliverList.builder(
            itemCount: value.rows.length,
            itemBuilder: (context, i) => switch (value.rows[i]) {
              SampleRow(:final point) => _SampleRowView(point),
              GapRow(:final from, :final to) => _GapRowView(from: from, to: to),
            },
          ),
        ],
      ),
      AsyncError(:final error) => SliverToBoxAdapter(
        child: SectionError(
          message: error is ApiException
              ? error.title
              : 'Couldn’t load history.',
          onRetry: () => ref.invalidate(telemetryHistoryProvider(vehicleId)),
        ),
      ),
      _ => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    };
  }

  static Widget row(
    List<Widget> cells, {
    double minHeight = 48,
    Color color = AppPalette.surface,
  }) => Container(
    constraints: BoxConstraints(minHeight: minHeight),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    decoration: BoxDecoration(
      color: color,
      border: const Border(top: BorderSide(color: AppPalette.divider)),
    ),
    child: Row(
      children: [
        SizedBox(width: _columns[0], child: cells[0]),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: cells[1]),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: _columns[2],
          child: Align(alignment: Alignment.centerRight, child: cells[2]),
        ),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: _columns[3],
          child: Align(alignment: Alignment.centerRight, child: cells[3]),
        ),
      ],
    ),
  );
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final style = AppText.labelSmall.copyWith(
      letterSpacing: 0.5,
      color: AppPalette.onSurfaceVariant,
    );
    return HistorySection.row(
      [
        Text('TIME', style: style),
        Text('STATE', style: style),
        Text('KM/H', style: style),
        Text('BATT.', style: style),
      ],
      minHeight: 36,
      color: AppPalette.background,
    );
  }
}

class _SampleRowView extends StatelessWidget {
  const _SampleRowView(this.point);

  final TelemetryPoint point;

  @override
  Widget build(BuildContext context) {
    final status = switch (point.state) {
      VehicleState.moving => DisplayStatus.moving,
      VehicleState.idle => DisplayStatus.idle,
      VehicleState.charging => DisplayStatus.charging,
      VehicleState.fault => DisplayStatus.fault,
      VehicleState.unknown => null,
    };
    final color = status == null
        ? AppPalette.onSurfaceVariant
        : context.statusColors.of(status).foreground;
    final value = AppText.tabular(AppText.bodyMedium);
    return HistorySection.row([
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            clockTime(point.recordedAt),
            style: value.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
            style: AppText.tabular(
              AppText.labelSmall.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: AppPalette.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      Row(
        children: [
          Icon(status?.icon ?? Icons.help_outline, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              status?.label ?? 'Unknown',
              style: value.copyWith(fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
      Text(point.speedKmh.toStringAsFixed(1), style: value),
      Text('${point.batteryPct.round()}%', style: value),
    ]);
  }
}

class _GapRowView extends StatelessWidget {
  const _GapRowView({required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 40),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    decoration: const BoxDecoration(
      color: AppPalette.fleetIconBackground,
      border: Border(top: BorderSide(color: AppPalette.divider)),
    ),
    child: Row(
      children: [
        const Icon(Icons.wifi_off, size: 16, color: AppPalette.textMuted),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            'No samples ${clockTimeShort(from)}–${clockTimeShort(to)} · offline',
            style: AppText.labelMedium.copyWith(color: AppPalette.textMuted),
          ),
        ),
      ],
    ),
  );
}
