import 'dart:io';

import 'package:fleet_monitor/core/realtime/signalr_connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalr_netcore/errors.dart';
import 'package:signalr_netcore/iretry_policy.dart';
import 'package:signalr_netcore/signalr_client.dart';

/// Answers every request by throwing [error] (or with 200 when null).
class _FakeHttpClient extends SignalRHttpClient {
  _FakeHttpClient(this.error);

  final Object? error;

  @override
  Future<SignalRHttpResponse> send(SignalRHttpRequest request) async {
    if (error != null) throw error!;
    return SignalRHttpResponse(200, content: '{}');
  }
}

void main() {
  group('UnauthorizedWatchingHttpClient', () {
    Future<int> unauthorizedCalls(Object? error) async {
      var calls = 0;
      final client = UnauthorizedWatchingHttpClient(
        onUnauthorized: () => calls++,
        inner: _FakeHttpClient(error),
      );
      try {
        await client.post(
          'http://api/hubs/fleet/negotiate',
          options: SignalRHttpRequest(),
        );
      } on Object catch (e) {
        expect(e, same(error), reason: 'the original error is rethrown');
      }
      return calls;
    }

    test('reports a 401', () async {
      expect(await unauthorizedCalls(HttpError('Unauthorized', 401)), 1);
    });

    test('does not report 5xx, 403, network errors or success', () async {
      expect(await unauthorizedCalls(HttpError('Service Unavailable', 503)), 0);
      expect(await unauthorizedCalls(HttpError('Forbidden', 403)), 0);
      expect(
        await unauthorizedCalls(const SocketException('Connection refused')),
        0,
      );
      expect(await unauthorizedCalls(null), 0);
    });
  });

  group('StopOnUnauthorizedRetryPolicy', () {
    RetryContext attempt(int n) => RetryContext(0, n, Exception('x'));

    test('uses the delays, then gives up', () {
      final policy = StopOnUnauthorizedRetryPolicy([
        0,
        2000,
      ], isRejected: () => false);

      expect(policy.nextRetryDelayInMilliseconds(attempt(0)), 0);
      expect(policy.nextRetryDelayInMilliseconds(attempt(1)), 2000);
      expect(policy.nextRetryDelayInMilliseconds(attempt(2)), isNull);
    });

    test('stops at once after a 401', () {
      var rejected = false;
      final policy = StopOnUnauthorizedRetryPolicy([
        0,
        2000,
      ], isRejected: () => rejected);

      rejected = true;
      expect(policy.nextRetryDelayInMilliseconds(attempt(0)), isNull);
    });
  });
}
