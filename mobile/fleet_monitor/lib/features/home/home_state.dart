import 'package:flutter_riverpod/flutter_riverpod.dart';

enum HomeTab { list, map }

class HomeTabNotifier extends Notifier<HomeTab> {
  @override
  HomeTab build() => HomeTab.list;

  void select(HomeTab tab) => state = tab;
}

final homeTabProvider = NotifierProvider<HomeTabNotifier, HomeTab>(
  HomeTabNotifier.new,
);

/// Vehicle selected on the map (preview panel open), or null.
class MapSelectionNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? vehicleId) => state = vehicleId;
}

final mapSelectionProvider = NotifierProvider<MapSelectionNotifier, String?>(
  MapSelectionNotifier.new,
);

/// "Open in map" from the detail screen: switch to the app's own Map tab with that vehicle selected.
void showVehicleOnMap(WidgetRef ref, String vehicleId) {
  ref.read(mapSelectionProvider.notifier).select(vehicleId);
  ref.read(homeTabProvider.notifier).select(HomeTab.map);
}
