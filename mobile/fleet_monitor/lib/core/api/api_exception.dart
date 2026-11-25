import 'problem_details.dart';

enum ApiErrorKind {
  /// The server answered with an error status (details from ProblemDetails when present).
  http,

  /// No connection / connection refused / DNS failure.
  network,
  timeout,

  /// The server answered 2xx but the body didn't have the expected shape.
  invalidResponse,
}

/// The only error type repositories throw. UI code shows [title] (and [detail] if present).
class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.title,
    this.statusCode,
    this.detail,
    this.fieldErrors = const {},
  });

  factory ApiException.fromProblem(int statusCode, ProblemDetails? problem) => ApiException(
        kind: ApiErrorKind.http,
        statusCode: statusCode,
        title: problem?.title ?? 'Request failed ($statusCode)',
        detail: problem?.detail,
        fieldErrors: problem?.errors ?? const {},
      );

  final ApiErrorKind kind;
  final int? statusCode;
  final String title;
  final String? detail;
  final Map<String, List<String>> fieldErrors;

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => 'ApiException($kind, $statusCode, $title${detail == null ? '' : ': $detail'})';
}
