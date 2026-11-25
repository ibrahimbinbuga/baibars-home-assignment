import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/realtime/realtime_controller.dart';
import '../../../core/time_format.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/spacing.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/filter_controls.dart';
import '../../../shared/widgets/status_visuals.dart';
import '../../../shared/widgets/vehicle_card.dart';
import '../domain/display_status.dart';
import '../state/vehicle_filter.dart';
import '../state/vehicle_list_notifier.dart';
import '../state/vehicle_list_view.dart';
import 'vehicle_detail_screen.dart';

/// Vehicles · List tab (Main.dc.html + ListStates.dc.html).
class VehicleListScreen extends ConsumerWidget {
  const VehicleListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(vehicleListViewProvider);

    return switch (view) {
      AsyncData(:final value) => RefreshIndicator(
        onRefresh: () => _refresh(context, ref),
        child: _ListContent(view: value),
      ),
      AsyncError(:final error) => _LoadError(error: error),
      _ => const _ListSkeleton(),
    };
  }

  /// Pull to refresh: re-fetches and merges; on failure keeps the list and says so.
  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(vehicleListProvider.notifier).refresh();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Couldn’t refresh: ${e.title}')));
      }
    }
  }
}

class _ListContent extends ConsumerWidget {
  const _ListContent({required this.view});

  final VehicleListView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.read(vehicleFilterProvider.notifier);

    return CustomScrollView(
      // Always scrollable, so pull-to-refresh works even with few cards.
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xxs,
          ),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: AppSpacing.xs,
              crossAxisSpacing: AppSpacing.xs,
              mainAxisExtent: 52,
            ),
            delegate: SliverChildListDelegate([
              for (final status in summaryOrder)
                SummaryCountButton(
                  status: status,
                  count: view.counts[status] ?? 0,
                  selected: view.filter.status == status,
                  onTap: () => filter.toggleStatus(status),
                ),
            ]),
          ),
        ),
        SliverToBoxAdapter(child: _FilterRow(view: view)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xxs,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(child: _CountLine(view: view)),
                Text(
                  'Sorted by status',
                  style: AppText.labelMedium.copyWith(
                    fontWeight: FontWeight.w400,
                    color: AppPalette.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (view.shown.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyList(view: view),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            sliver: SliverList.separated(
              itemCount: view.shown.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, i) {
                final vehicle = view.shown[i];
                return VehicleCard(
                  key: ValueKey(vehicle.id),
                  vehicle: vehicle,
                  now: view.now,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          VehicleDetailScreen(vehicleId: vehicle.id),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _FilterRow extends ConsumerWidget {
  const _FilterRow({required this.view});

  final VehicleListView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.read(vehicleFilterProvider.notifier);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          if (view.showFleetFilter) ...[
            AppFilterChip(
              label: view.selectedFleet?.name ?? 'All fleets',
              selected: view.selectedFleet != null,
              dropdown: true,
              onTap: () => _pickFleet(context, ref),
            ),
            Container(
              width: 1,
              height: 32,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              color: AppPalette.mutedBorder,
            ),
          ],
          AppFilterChip(
            label: 'All',
            selected: view.filter.status == null,
            onTap: () => filter.setStatus(null),
          ),
          for (final status in summaryOrder) ...[
            const SizedBox(width: AppSpacing.xs),
            AppFilterChip(
              label: status.label,
              selected: view.filter.status == status,
              onTap: () => filter.setStatus(status),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickFleet(BuildContext context, WidgetRef ref) async {
    final selected = await showModalBottomSheet<_FleetChoice>(
      context: context,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppPalette.hint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Fleet', style: AppText.titleMedium),
              ),
            ),
            for (final choice in [
              const _FleetChoice(null, 'All fleets'),
              for (final f in view.fleets) _FleetChoice(f.id, f.name),
            ])
              ListTile(
                minTileHeight: AppSpacing.tap,
                title: Text(choice.name, style: AppText.bodyLarge),
                trailing: choice.id == view.filter.fleetId
                    ? const Icon(Icons.check, color: AppPalette.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(choice),
              ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ),
      ),
    );
    if (selected != null) {
      ref.read(vehicleFilterProvider.notifier).setFleet(selected.id);
    }
  }
}

class _FleetChoice {
  const _FleetChoice(this.id, this.name);

  final String? id;
  final String name;
}

class _EmptyList extends ConsumerWidget {
  const _EmptyList({required this.view});

  final VehicleListView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!view.filter.isActive) {
      // Nothing to show at all: the user has no fleets (or the fleets have no vehicles).
      return const CenteredMessage(
        icon: Icons.inbox_outlined,
        iconColor: AppPalette.onSurfaceVariant,
        iconBackground: AppPalette.emptyIconBackground,
        title: 'No vehicles yet',
        message:
            'No vehicles are visible to your account. Ask an administrator to assign a fleet.',
      );
    }
    return CenteredMessage(
      icon: Icons.filter_alt_outlined,
      iconColor: AppPalette.onSurfaceVariant,
      iconBackground: AppPalette.emptyIconBackground,
      title: 'No vehicles match this filter',
      message: view.emptyMessage((s) => s.label),
      action: OutlineAppButton(
        label: 'Clear filters',
        onPressed: ref.read(vehicleFilterProvider.notifier).clear,
      ),
    );
  }
}

class _LoadError extends ConsumerWidget {
  const _LoadError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = switch (error) {
      ApiException(kind: ApiErrorKind.network || ApiErrorKind.timeout) =>
        'The server didn’t respond. Check your connection and try again.',
      ApiException(:final title) => title,
      _ => 'Something went wrong. Try again.',
    };
    return CenteredMessage(
      icon: Icons.warning_amber_rounded,
      iconColor: AppPalette.error,
      iconBackground: AppPalette.errorContainer,
      title: 'Couldn’t load vehicles',
      message: message,
      action: PrimaryAppButton(
        key: const Key('retryButton'),
        label: 'Retry',
        icon: Icons.refresh,
        onPressed: () => ref.invalidate(vehicleListProvider),
      ),
    );
  }
}

/// First load: the skeleton mirrors the final layout.
class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading vehicles',
    child: ListView(
      key: const Key('listSkeleton'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      children: [
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          mainAxisSpacing: AppSpacing.xs,
          crossAxisSpacing: AppSpacing.xs,
          childAspectRatio: 110 / 52,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(
            6,
            (_) => const SkeletonBox(height: 52, radius: AppRadius.input),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              SkeletonBox(width: 120, height: 48, radius: AppRadius.chip),
              SizedBox(width: 8),
              SkeletonBox(width: 64, height: 48, radius: AppRadius.chip),
              SizedBox(width: 8),
              SkeletonBox(width: 96, height: 48, radius: AppRadius.chip),
            ],
          ),
        ),
        for (var i = 0; i < 5; i++)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: AppPalette.surface,
              border: Border.all(color: AppPalette.skeleton),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: const Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 72, height: 18),
                        SizedBox(height: 6),
                        SkeletonBox(width: 128, height: 14),
                      ],
                    ),
                    Spacer(),
                    SkeletonBox(width: 88, height: 30),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    SkeletonBox(width: 56, height: 16),
                    SizedBox(width: 16),
                    SkeletonBox(width: 80, height: 16),
                    Spacer(),
                    SkeletonBox(width: 96, height: 16),
                  ],
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// "8 of 8 vehicles · 2 fleets" while live. While reconnecting/disconnected (ListStates 2.1/2.2) it says how old the
/// data is instead, in amber: "Last received 14:32:10 · may be outdated" / "· not live".
class _CountLine extends ConsumerWidget {
  const _CountLine({required this.view});

  final VehicleListView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final realtime = ref.watch(realtimeControllerProvider);
    final last = realtime.lastReceivedAt;
    final suffix = switch (realtime.status) {
      RealtimeStatus.reconnecting => 'may be outdated',
      RealtimeStatus.disconnected => 'not live',
      _ => null,
    };
    if (suffix != null && last != null) {
      return Text(
        'Last received ${clockTime(last)} · $suffix',
        key: const Key('countLine'),
        style: AppText.tabular(
          AppText.labelMedium.copyWith(color: AppPalette.onWarningContainer),
        ),
      );
    }
    return Text(
      view.countLine,
      key: const Key('countLine'),
      style: AppText.tabular(
        AppText.labelMedium.copyWith(
          fontWeight: FontWeight.w400,
          color: AppPalette.onSurfaceVariant,
        ),
      ),
    );
  }
}
