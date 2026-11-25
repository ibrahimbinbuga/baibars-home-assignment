// ⚠ TEMPORARY DEBUG UI (Phase 5a). Only for checking data flow against the backend.
// Replaced by the designed list/map/detail screens in Phase 5b.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../state/vehicle_filter.dart';
import '../state/vehicle_list_notifier.dart';

class DebugVehicleListScreen extends ConsumerWidget {
  const DebugVehicleListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider).value;
    final vehicles = ref.watch(filteredVehiclesProvider);
    final userLine = auth is Authenticated ? '${auth.user.displayName} (${auth.user.role.name})' : '';

    return Scaffold(
      appBar: AppBar(
        title: Text('DEBUG vehicles — $userLine'),
        actions: [
          IconButton(
            key: const Key('logoutButton'),
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(LogoutReason.userRequested),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(vehicleListProvider.notifier).refresh().catchError((Object e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.title : '$e')));
          }
        }),
        child: vehicles.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [ListTile(title: Text(e is ApiException ? e.title : '$e'))]),
          data: (list) => ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final v = list[i];
              final battery = v.batteryPct == null ? '—' : '${v.batteryPct!.toStringAsFixed(0)}%';
              return ListTile(
                title: Text(v.name),
                subtitle: Text('${v.fleetName} · ${v.status.name} · battery $battery'),
              );
            },
          ),
        ),
      ),
    );
  }
}
