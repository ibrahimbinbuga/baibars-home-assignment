import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/vehicles/domain/display_status.dart';
import '../../features/vehicles/state/vehicle_list_notifier.dart';
import '../clock.dart';

/// "Now", updated every second while the app is in the foreground. Drives "Xs ago" texts and stale detection.
/// Only small widgets (TimeAgoText) watch it directly; screens watch [staleVehicleIdsProvider], which changes rarely.
class TickerNotifier extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    ref.onDispose(() => _timer?.cancel());
    _start();
    return ref.read(clockProvider)();
  }

  void tick() => state = ref.read(clockProvider)();

  /// App backgrounded: no reason to wake up every second.
  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  void resume() {
    tick();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }
}

final tickerProvider = NotifierProvider<TickerNotifier, DateTime>(
  TickerNotifier.new,
);

/// The ids of vehicles that are stale right now. Value-equal sets compare equal, so dependents only rebuild when a
/// vehicle actually crosses the 30 s line (or the list changes), not on every tick.
@immutable
class StaleSet {
  const StaleSet(this.ids);

  final Set<String> ids;

  @override
  bool operator ==(Object other) =>
      other is StaleSet && setEquals(other.ids, ids);

  @override
  int get hashCode => Object.hashAllUnordered(ids);
}

final staleVehicleIdsProvider = Provider<StaleSet>((ref) {
  final now = ref.watch(tickerProvider);
  final vehicles = ref.watch(vehicleListProvider).value?.vehicles ?? const [];
  return StaleSet({
    for (final v in vehicles)
      if (displayStatusOf(v, now) == DisplayStatus.stale) v.id,
  });
});
