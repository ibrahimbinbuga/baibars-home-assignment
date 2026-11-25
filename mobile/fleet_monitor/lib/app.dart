import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_notifier.dart';
import 'core/auth/auth_state.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/ui/login_screen.dart';
import 'features/home/home_shell.dart';

class FleetApp extends ConsumerStatefulWidget {
  const FleetApp({super.key});

  @override
  ConsumerState<FleetApp> createState() => _FleetAppState();
}

class _FleetAppState extends ConsumerState<FleetApp> {
  final _navigator = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // On any logout, close pushed screens (detail, account) so the login screen is really on top.
    ref.listen(authProvider, (previous, next) {
      if (previous?.value is Authenticated && next.value is Unauthenticated) {
        _navigator.currentState?.popUntil((route) => route.isFirst);
      }
    });

    final auth = ref.watch(authProvider);
    return MaterialApp(
      title: 'Fleet Monitor',
      navigatorKey: _navigator,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // No router: the home screen follows the auth state, so logging out (for any reason) always lands on login.
      home: switch (auth) {
        AsyncData(value: Authenticated()) => const HomeShell(),
        AsyncData(value: final Unauthenticated state) => LoginScreen(
          sessionEnded: state.sessionEnded,
          initialEmail: state.email,
        ),
        AsyncError() => const LoginScreen(),
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
    debugShowCheckedModeBanner: false,
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
