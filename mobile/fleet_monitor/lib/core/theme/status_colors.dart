import 'package:flutter/material.dart';

import '../../features/vehicles/domain/display_status.dart';

/// Foreground (text/icon, ≥ 4.5:1 on white and on its tint) and tint (container) for one status.
@immutable
class StatusColorPair {
  const StatusColorPair(this.foreground, this.tint);

  final Color foreground;
  final Color tint;
}

/// Status colours as a ThemeExtension (Tokens.dc.html). Never used alone: always with an icon and a label.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.moving,
    required this.idle,
    required this.charging,
    required this.fault,
    required this.offline,
    required this.stale,
  });

  static const light = StatusColors(
    moving: StatusColorPair(Color(0xFF137333), Color(0xFFE7F6EC)),
    idle: StatusColorPair(Color(0xFF975400), Color(0xFFFDF3DC)),
    charging: StatusColorPair(Color(0xFF1D4ED8), Color(0xFFE3ECFD)),
    fault: StatusColorPair(Color(0xFFB91C1C), Color(0xFFFDE7E7)),
    offline: StatusColorPair(Color(0xFF4B5563), Color(0xFFECEEF1)),
    stale: StatusColorPair(Color(0xFF6D28D9), Color(0xFFEFEAFC)),
  );

  final StatusColorPair moving;
  final StatusColorPair idle;
  final StatusColorPair charging;
  final StatusColorPair fault;
  final StatusColorPair offline;
  final StatusColorPair stale;

  StatusColorPair of(DisplayStatus status) => switch (status) {
    DisplayStatus.moving => moving,
    DisplayStatus.idle => idle,
    DisplayStatus.charging => charging,
    DisplayStatus.fault => fault,
    DisplayStatus.offline => offline,
    DisplayStatus.stale => stale,
  };

  @override
  StatusColors copyWith({
    StatusColorPair? moving,
    StatusColorPair? idle,
    StatusColorPair? charging,
    StatusColorPair? fault,
    StatusColorPair? offline,
    StatusColorPair? stale,
  }) => StatusColors(
    moving: moving ?? this.moving,
    idle: idle ?? this.idle,
    charging: charging ?? this.charging,
    fault: fault ?? this.fault,
    offline: offline ?? this.offline,
    stale: stale ?? this.stale,
  );

  // Only one (light) theme exists, so there is nothing to animate between.
  @override
  StatusColors lerp(StatusColors? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

extension StatusColorsContext on BuildContext {
  StatusColors get statusColors => Theme.of(this).extension<StatusColors>()!;
}
