import 'package:flutter/material.dart';

import '../../features/vehicles/domain/display_status.dart';

/// Label and icon per status. Every status is shown as colour + icon + text, never colour alone.
extension DisplayStatusVisuals on DisplayStatus {
  String get label => switch (this) {
    DisplayStatus.moving => 'Moving',
    DisplayStatus.idle => 'Idle',
    DisplayStatus.charging => 'Charging',
    DisplayStatus.fault => 'Fault',
    DisplayStatus.offline => 'Offline',
    DisplayStatus.stale => 'Stale',
  };

  IconData get icon => switch (this) {
    DisplayStatus.moving => Icons.navigation_outlined,
    DisplayStatus.idle => Icons.pause_circle_outline,
    DisplayStatus.charging => Icons.bolt,
    DisplayStatus.fault => Icons.warning_amber_rounded,
    DisplayStatus.offline => Icons.wifi_off,
    DisplayStatus.stale => Icons.schedule,
  };
}
