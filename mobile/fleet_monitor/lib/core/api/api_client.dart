import 'package:dio/dio.dart';

import '../json.dart';
import 'api_exception.dart';
import 'problem_details.dart';

typedef TokenReader = String? Function();
typedef UnauthorizedHandler = void Function();

/// Thin wrapper over dio: adds the bearer token, parses responses, and turns every failure into an [ApiException].
class ApiClient {
  ApiClient({
    required Uri baseUrl,
    required TokenReader readToken,
    required this._onUnauthorized,
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = baseUrl.toString()
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 15)
      ..responseType = ResponseType.json;
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      final token = readToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    }));
  }

  static const loginPath = '/api/auth/login';

  final Dio _dio;
  final UnauthorizedHandler _onUnauthorized;

  Future<T> get<T>(String path, {Map<String, Object?>? query, required T Function(Object? json) parse}) =>
      _send(path, () => _dio.get<Object?>(path, queryParameters: _withoutNulls(query)), parse);

  Future<T> post<T>(String path, {Object? body, required T Function(Object? json) parse}) =>
      _send(path, () => _dio.post<Object?>(path, data: body), parse);

  Future<T> _send<T>(String path, Future<Response<Object?>> Function() request, T Function(Object?) parse) async {
    final Response<Object?> response;
    try {
      response = await request();
    } on DioException catch (e) {
      throw _toApiException(path, e);
    }

    try {
      return parse(response.data);
    } on Object catch (e) {
      throw ApiException(kind: ApiErrorKind.invalidResponse, title: 'Unexpected response from server', detail: '$e');
    }
  }

  ApiException _toApiException(String path, DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(kind: ApiErrorKind.timeout, title: 'The server took too long to respond');
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        // 401 on login just means wrong credentials. Anywhere else it means our token is no longer accepted
        // (expired, revoked, signing key changed), so the session is over.
        if (status == 401 && path != loginPath) _onUnauthorized();
        final data = e.response?.data;
        return ApiException.fromProblem(status, data is Map<String, dynamic> ? ProblemDetails.fromJson(data) : null);
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return const ApiException(kind: ApiErrorKind.network, title: 'Cannot reach the server');
    }
  }

  static Map<String, Object?>? _withoutNulls(Map<String, Object?>? query) =>
      query == null ? null : {
        for (final entry in query.entries)
          if (entry.value != null) entry.key: entry.value,
      };
}

/// Convenience for repositories: parse a JSON array with an element parser.
List<T> parseList<T>(Object? json, T Function(Map<String, dynamic>) parseItem) =>
    asJsonList(json).map((item) => parseItem(asJsonMap(item))).toList(growable: false);
