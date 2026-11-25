import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thrown at startup when required build-time configuration is missing or invalid.
class ConfigException implements Exception {
  const ConfigException(this.message);
  final String message;

  @override
  String toString() => 'ConfigException: $message';
}

/// Build-time configuration, passed with --dart-define (see README).
class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  /// e.g. http://localhost:8080 (iOS simulator) or http://10.0.2.2:8080 (Android emulator).
  final Uri apiBaseUrl;

  static const _apiBaseUrlDefine = String.fromEnvironment('API_BASE_URL');

  /// Reads --dart-define=API_BASE_URL. Throws [ConfigException] if it is missing or not an http(s) URL.
  factory AppConfig.fromEnvironment() => AppConfig.parse(_apiBaseUrlDefine);

  factory AppConfig.parse(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      throw const ConfigException(
        'API_BASE_URL is not set.\n'
        'Run with --dart-define=API_BASE_URL=http://localhost:8080 (iOS simulator) '
        'or --dart-define=API_BASE_URL=http://10.0.2.2:8080 (Android emulator).',
      );
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
      throw ConfigException('API_BASE_URL "$value" is not a valid http(s) URL.');
    }
    return AppConfig(apiBaseUrl: uri);
  }
}

/// Overridden in main() with the parsed configuration.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider must be overridden in main()'),
);
