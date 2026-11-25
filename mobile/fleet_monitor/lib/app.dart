import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_notifier.dart';
import 'core/auth/auth_state.dart';
import 'features/auth/ui/debug_login_screen.dart';
import 'features/vehicles/ui/debug_vehicle_list_screen.dart';

class FleetApp extends ConsumerWidget {
  const FleetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return MaterialApp(
      title: 'Fleet Monitor',
      theme: ThemeData(colorSchemeSeed: Colors.green),
      // No router: the home screen follows the auth state, so logging out (for any reason) always lands on login.
      home: switch (auth) {
        AsyncData(value: Authenticated()) => const DebugVehicleListScreen(),
        AsyncData(value: Unauthenticated(:final reason)) => DebugLoginScreen(reason: reason),
        AsyncError() => const DebugLoginScreen(),
        _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
      },
    );
  }
}

/// Shown instead of the app when build-time configuration is missing, so the problem is obvious on screen.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.red.shade900,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Configuration error\n\n$message',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ),
      );
}
