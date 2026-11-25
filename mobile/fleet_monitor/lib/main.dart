import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final AppConfig config;
  try {
    config = AppConfig.fromEnvironment();
  } on ConfigException catch (e) {
    debugPrint('CONFIG ERROR: ${e.message}');
    runApp(ConfigErrorApp(message: e.message));
    return;
  }

  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      // Riverpod 3 retries failed providers automatically. Turned off: errors are shown with an explicit retry,
      // and retrying a 401/404 would only repeat the same failure.
      retry: (retryCount, error) => null,
      child: const FleetApp(),
    ),
  );
}
