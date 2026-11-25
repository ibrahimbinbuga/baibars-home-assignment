import '../../../core/json.dart';

class Fleet {
  const Fleet({required this.id, required this.name, required this.region});

  final String id;
  final String name;
  final String region;

  factory Fleet.fromJson(Map<String, dynamic> json) => Fleet(
        id: readString(json, 'id'),
        name: readString(json, 'name'),
        region: readString(json, 'region'),
      );
}
