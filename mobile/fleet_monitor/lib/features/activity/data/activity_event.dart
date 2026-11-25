import '../../../core/json.dart';

enum ActivityEventType { cameOnline, wentOffline, stateChanged, lowBattery, faultRaised, unknown }

class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.vehicleId,
    required this.type,
    required this.occurredAt,
    required this.details,
  });

  final int id;
  final String vehicleId;
  final ActivityEventType type;

  /// Server time.
  final DateTime occurredAt;
  final String details;

  factory ActivityEvent.fromJson(Map<String, dynamic> json) => ActivityEvent(
        id: readInt(json, 'id'),
        vehicleId: readString(json, 'vehicleId'),
        type: readEnum(json, 'type', ActivityEventType.values, ActivityEventType.unknown),
        occurredAt: readDate(json, 'occurredAt'),
        details: readString(json, 'details'),
      );
}

/// One page of activity, newest first. [nextBefore] is an opaque cursor for the next (older) page, null at the end.
class ActivityPage {
  const ActivityPage({required this.items, this.nextBefore});

  final List<ActivityEvent> items;
  final String? nextBefore;

  bool get hasMore => nextBefore != null;

  factory ActivityPage.fromJson(Map<String, dynamic> json) => ActivityPage(
        items: asJsonList(json['items']).map((e) => ActivityEvent.fromJson(asJsonMap(e))).toList(growable: false),
        nextBefore: readStringOrNull(json, 'nextBefore'),
      );
}
