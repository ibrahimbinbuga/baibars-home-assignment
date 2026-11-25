/// RFC 7807 error body returned by the API (application/problem+json).
class ProblemDetails {
  const ProblemDetails({this.status, this.title, this.detail, this.errors = const {}});

  final int? status;
  final String? title;
  final String? detail;

  /// Validation errors per field (400 responses), e.g. {"from": ["'from' must not be later than 'to'."]}.
  final Map<String, List<String>> errors;

  /// Lenient on purpose: an error body should never cause a second error.
  factory ProblemDetails.fromJson(Map<String, dynamic> json) {
    final errors = <String, List<String>>{};
    final rawErrors = json['errors'];
    if (rawErrors is Map) {
      rawErrors.forEach((key, value) {
        if (value is List) errors['$key'] = value.map((e) => '$e').toList();
      });
    }
    final status = json['status'];
    final title = json['title'];
    final detail = json['detail'];
    return ProblemDetails(
      status: status is int ? status : null,
      title: title is String ? title : null,
      detail: detail is String ? detail : null,
      errors: errors,
    );
  }
}
