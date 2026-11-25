/// Small helpers for hand-written fromJson methods. They throw [FormatException] on a wrong shape,
/// which the ApiClient reports as an invalid response.
library;

Map<String, dynamic> asJsonMap(Object? json) {
  if (json is Map<String, dynamic>) return json;
  throw FormatException('Expected a JSON object, got ${json.runtimeType}');
}

List<Object?> asJsonList(Object? json) {
  if (json is List) return json;
  throw FormatException('Expected a JSON array, got ${json.runtimeType}');
}

String readString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Expected string "$key", got ${value.runtimeType}');
}

String? readStringOrNull(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw FormatException('Expected string or null "$key", got ${value.runtimeType}');
}

double? readDoubleOrNull(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num) return value.toDouble();
  throw FormatException('Expected number or null "$key", got ${value.runtimeType}');
}

double readDouble(Map<String, dynamic> json, String key) =>
    readDoubleOrNull(json, key) ?? (throw FormatException('Missing number "$key"'));

int readInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Expected integer "$key", got ${value.runtimeType}');
}

/// The API always sends UTC ISO 8601 timestamps; the result is always UTC.
DateTime readDate(Map<String, dynamic> json, String key) => DateTime.parse(readString(json, key)).toUtc();

DateTime? readDateOrNull(Map<String, dynamic> json, String key) {
  final value = readStringOrNull(json, key);
  return value == null ? null : DateTime.parse(value).toUtc();
}

/// Maps an API enum string ("Moving", "CameOnline", ...) to a Dart enum by name, case-insensitively.
/// Values this app version doesn't know (e.g. added to the API later) become [unknown] instead of crashing.
T readEnum<T extends Enum>(Map<String, dynamic> json, String key, List<T> values, T unknown) {
  final raw = json[key];
  if (raw is! String) return unknown;
  final lower = raw.toLowerCase();
  for (final value in values) {
    if (value != unknown && value.name.toLowerCase() == lower) return value;
  }
  return unknown;
}

/// The API's spelling of a Dart enum value: moving → "Moving".
String apiEnumName(Enum value) => value.name[0].toUpperCase() + value.name.substring(1);
