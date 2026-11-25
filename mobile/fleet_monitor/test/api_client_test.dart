import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fleet_monitor/core/api/api_client.dart';
import 'package:fleet_monitor/core/api/api_exception.dart';
import 'package:fleet_monitor/core/json.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with a fixed status/body (or throws), and remembers the last request.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter({this.status = 200, this.body = const {}, this.error});

  final int status;
  final Object? body;
  final Object? error;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    if (error != null) throw error!;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/problem+json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late int unauthorizedCalls;

  ApiClient client(FakeAdapter adapter, {String? token = 'jwt-token'}) {
    unauthorizedCalls = 0;
    return ApiClient(
      baseUrl: Uri.parse('http://localhost:8080'),
      readToken: () => token,
      onUnauthorized: () => unauthorizedCalls++,
      dio: Dio()..httpClientAdapter = adapter,
    );
  }

  Future<ApiException> failure(Future<Object?> call) async {
    try {
      await call;
    } on ApiException catch (e) {
      return e;
    }
    fail('Expected ApiException');
  }

  test('attaches the bearer token', () async {
    final adapter = FakeAdapter(body: []);

    await client(adapter).get('/api/vehicles', parse: (json) => json);

    expect(adapter.lastRequest!.headers['Authorization'], 'Bearer jwt-token');
  });

  test('sends no Authorization header without a token', () async {
    final adapter = FakeAdapter(body: []);

    await client(
      adapter,
      token: null,
    ).get('/api/vehicles', parse: (json) => json);

    expect(adapter.lastRequest!.headers.containsKey('Authorization'), isFalse);
  });

  test('401 on a normal endpoint logs out', () async {
    final api = client(
      FakeAdapter(status: 401, body: {'status': 401, 'title': 'Unauthorized'}),
    );

    final e = await failure(api.get('/api/vehicles', parse: (json) => json));

    expect(e.isUnauthorized, isTrue);
    expect(unauthorizedCalls, 1);
  });

  test('401 on login is "wrong credentials", not a logout', () async {
    final api = client(
      FakeAdapter(
        status: 401,
        body: {'status': 401, 'title': 'Invalid email or password.'},
      ),
    );

    final e = await failure(
      api.post(ApiClient.loginPath, body: {}, parse: (json) => json),
    );

    expect(e.isUnauthorized, isTrue);
    expect(e.title, 'Invalid email or password.');
    expect(unauthorizedCalls, 0);
  });

  test('429 on login is "rate limited", not a logout', () async {
    final api = client(
      FakeAdapter(
        status: 429,
        body: {'status': 429, 'title': 'Too Many Requests'},
      ),
    );

    final e = await failure(
      api.post(ApiClient.loginPath, body: {}, parse: (json) => json),
    );

    expect(e.isRateLimited, isTrue);
    expect(unauthorizedCalls, 0);
  });

  test('ProblemDetails is mapped into the exception', () async {
    final api = client(
      FakeAdapter(
        status: 400,
        body: {
          'status': 400,
          'title': 'One or more validation errors occurred.',
          'errors': {
            'limit': ["'limit' must be at least 1."],
          },
        },
      ),
    );

    final e = await failure(
      api.get('/api/vehicles/x/telemetry', parse: (json) => json),
    );

    expect(e.kind, ApiErrorKind.http);
    expect(e.statusCode, 400);
    expect(e.title, 'One or more validation errors occurred.');
    expect(e.fieldErrors['limit'], ["'limit' must be at least 1."]);
    expect(unauthorizedCalls, 0);
  });

  test('404 is not a logout', () async {
    final api = client(
      FakeAdapter(
        status: 404,
        body: {'status': 404, 'title': 'Vehicle not found.'},
      ),
    );

    final e = await failure(api.get('/api/vehicles/x', parse: (json) => json));

    expect(e.isNotFound, isTrue);
    expect(unauthorizedCalls, 0);
  });

  test('connection failure becomes a network error', () async {
    final api = client(
      FakeAdapter(error: const SocketException('Connection refused')),
    );

    final e = await failure(api.get('/api/vehicles', parse: (json) => json));

    expect(e.kind, ApiErrorKind.network);
  });

  test('unexpected body shape becomes invalidResponse', () async {
    final api = client(FakeAdapter(body: {'not': 'a list'}));

    final e = await failure(
      api.get('/api/vehicles', parse: (json) => asJsonList(json)),
    );

    expect(e.kind, ApiErrorKind.invalidResponse);
  });

  test('null query parameters are not sent', () async {
    final adapter = FakeAdapter(body: []);

    await client(adapter).get(
      '/api/vehicles',
      query: {'fleetId': null, 'status': 'Moving'},
      parse: (json) => json,
    );

    expect(adapter.lastRequest!.queryParameters, {'status': 'Moving'});
  });
}
