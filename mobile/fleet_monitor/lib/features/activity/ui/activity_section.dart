import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/spacing.dart';
import '../../../shared/widgets/activity_row.dart';
import '../../../shared/widgets/common.dart';
import '../state/activity_feed.dart';

/// Activity tab content (a sliver): events newest first, "Load more" at the end.
class ActivitySection extends ConsumerWidget {
  const ActivitySection({
    super.key,
    required this.vehicleId,
    required this.now,
  });

  final String vehicleId;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(activityFeedProvider(vehicleId));
    return switch (feed) {
      AsyncData(:final value) when value.items.isEmpty =>
        const SliverToBoxAdapter(child: _NoActivity()),
      AsyncData(:final value) => SliverList.list(
        children: [
          for (var i = 0; i < value.items.length; i++)
            ActivityRow(event: value.items[i], showTopBorder: i > 0),
          if (value.hasMore || value.loadMoreError != null)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                color: AppPalette.surface,
                border: Border(top: BorderSide(color: AppPalette.divider)),
              ),
              child: Column(
                children: [
                  if (value.loadMoreError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Text(
                        'Couldn’t load more: ${value.loadMoreError!.title}',
                        style: AppText.bodyMedium.copyWith(
                          color: AppPalette.error,
                        ),
                      ),
                    ),
                  OutlineAppButton(
                    key: const Key('loadMoreButton'),
                    label: 'Load more',
                    expand: true,
                    busy: value.loadingMore,
                    onPressed: ref
                        .read(activityFeedProvider(vehicleId).notifier)
                        .loadMore,
                  ),
                ],
              ),
            ),
        ],
      ),
      AsyncError(:final error) => SliverToBoxAdapter(
        child: SectionError(
          message: error is ApiException
              ? error.title
              : 'Couldn’t load activity.',
          onRetry: () => ref.invalidate(activityFeedProvider(vehicleId)),
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
}

class _NoActivity extends StatelessWidget {
  const _NoActivity();

  @override
  Widget build(BuildContext context) => Container(
    color: AppPalette.surface,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.xl,
      vertical: 40,
    ),
    child: Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppPalette.fleetIconBackground,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.notes,
            size: 26,
            color: AppPalette.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('No activity yet', style: AppText.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Events like state changes and faults will appear here, newest first.',
          textAlign: TextAlign.center,
          style: AppText.bodyMedium.copyWith(
            color: AppPalette.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

/// Error with Retry inside a detail tab.
class SectionError extends StatelessWidget {
  const SectionError({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    color: AppPalette.surface,
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppText.bodyMedium.copyWith(color: AppPalette.error),
        ),
        const SizedBox(height: AppSpacing.sm),
        PrimaryAppButton(
          label: 'Retry',
          icon: Icons.refresh,
          onPressed: onRetry,
        ),
      ],
    ),
  );
}
