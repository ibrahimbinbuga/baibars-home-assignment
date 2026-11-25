/// Formatting for times and directions shown in the UI.
library;

/// "4s ago", "2m ago", "3h ago", "2d ago". A time slightly in the future (clock drift) reads "0s ago".
String timeAgo(DateTime time, DateTime now) {
  final diff = now.difference(time);
  if (diff.inSeconds < 60) {
    return '${diff.inSeconds < 0 ? 0 : diff.inSeconds}s ago';
  }
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Local wall-clock time, "14:32:08".
String clockTime(DateTime time) {
  final t = time.toLocal();
  return '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
}

/// Local wall-clock time, "14:32".
String clockTimeShort(DateTime time) {
  final t = time.toLocal();
  return '${_two(t.hour)}:${_two(t.minute)}';
}

/// 0° = N, 45° = NE, ... 312° = NW.
String cardinal(double headingDeg) {
  const names = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  return names[((headingDeg % 360) / 45).round() % 8];
}

/// "36.9182° N" / "34.8927° E".
String latitudeText(double lat) =>
    '${lat.abs().toStringAsFixed(4)}° ${lat >= 0 ? 'N' : 'S'}';
String longitudeText(double lon) =>
    '${lon.abs().toStringAsFixed(4)}° ${lon >= 0 ? 'E' : 'W'}';
