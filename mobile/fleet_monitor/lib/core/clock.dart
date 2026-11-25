import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current time in UTC. A provider so tests can fix "now" (token expiry, staleness).
typedef Clock = DateTime Function();

final clockProvider = Provider<Clock>(
  (ref) =>
      () => DateTime.now().toUtc(),
);
