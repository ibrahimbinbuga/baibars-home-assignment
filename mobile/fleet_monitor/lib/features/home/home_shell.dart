import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_notifier.dart';
import '../../core/auth/auth_state.dart';
import '../../core/realtime/realtime_controller.dart';
import '../../core/theme/app_palette.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/connection_banner.dart';
import '../account/ui/account_screen.dart';
import '../vehicles/ui/vehicle_list_screen.dart';
import '../vehicles/ui/vehicle_map_screen.dart';
import 'home_state.dart';

/// "Vehicles" with bottom navigation List | Map. Both tabs stay alive (IndexedStack) so the map keeps its position.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(homeTabProvider);
    // Watching the controller keeps the real-time connection running while the home screen exists.
    final realtime = ref.watch(realtimeControllerProvider);
    final auth = ref.watch(authProvider).value;
    final user = auth is Authenticated ? auth.user : null;

    return Scaffold(
      appBar: FleetAppBar(
        title: 'Vehicles',
        actions: [
          if (user != null)
            IconButton(
              tooltip: 'Account: ${user.displayName}, ${user.role.name}',
              icon: InitialsAvatar(name: user.displayName),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AccountScreen()),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          ConnectionBanner(
            state: realtime.banner,
            disconnectedSince: realtime.disconnectedSince,
            onRetry: ref.read(realtimeControllerProvider.notifier).retryNow,
          ),
          Expanded(
            child: IndexedStack(
              index: tab.index,
              children: const [VehicleListScreen(), VehicleMapScreen()],
            ),
          ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppPalette.outlineVariant)),
        ),
        child: NavigationBar(
          selectedIndex: tab.index,
          onDestinationSelected: (i) =>
              ref.read(homeTabProvider.notifier).select(HomeTab.values[i]),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.format_list_bulleted),
              label: 'List',
            ),
            NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Map'),
          ],
        ),
      ),
    );
  }
}
