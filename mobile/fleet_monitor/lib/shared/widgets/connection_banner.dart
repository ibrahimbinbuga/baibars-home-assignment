import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../../core/time_format.dart';

enum BannerConnectionState { connected, reconnecting, disconnected }

/// ConnectionBanner(state). Sits directly under the app bar and pushes content down. Wired to SignalR in Phase 6.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({
    super.key,
    required this.state,
    this.disconnectedSince,
    this.onRetry,
  });

  final BannerConnectionState state;
  final DateTime? disconnectedSince;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => switch (state) {
    BannerConnectionState.connected => const SizedBox.shrink(),
    BannerConnectionState.reconnecting => Semantics(
      liveRegion: true,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: const BoxDecoration(
          color: AppPalette.warningContainer,
          border: Border(bottom: BorderSide(color: AppPalette.warningBorder)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.sync,
              size: 18,
              color: AppPalette.onWarningContainer,
            ),
            const SizedBox(width: 10),
            Text(
              'Reconnecting…',
              style: AppText.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppPalette.onWarningContainer,
              ),
            ),
            const Spacer(),
            Text(
              'Data may be outdated',
              style: AppText.labelMedium.copyWith(
                fontWeight: FontWeight.w500,
                color: AppPalette.onWarningContainer,
              ),
            ),
          ],
        ),
      ),
    ),
    BannerConnectionState.disconnected => Semantics(
      liveRegion: true,
      child: Container(
        height: 56,
        color: AppPalette.inverseSurface,
        padding: const EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.xxs,
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off, size: 18, color: AppPalette.onPrimary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Disconnected',
                    style: AppText.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppPalette.onPrimary,
                    ),
                  ),
                  Text(
                    disconnectedSince == null
                        ? 'Live updates paused'
                        : 'Live updates paused since ${clockTimeShort(disconnectedSince!)}',
                    style: AppText.labelMedium.copyWith(
                      fontWeight: FontWeight.w400,
                      color: AppPalette.onInverseVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                minimumSize: const Size(AppSpacing.tap, AppSpacing.tap),
                foregroundColor: AppPalette.onPrimary,
                textStyle: AppText.labelLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    ),
  };
}
