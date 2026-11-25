import '../../../core/json.dart';
import '../../vehicles/data/fleet.dart';

enum Role { admin, operator, unknown }

class UserInfo {
  const UserInfo({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
  });

  final String id;
  final String email;
  final String displayName;
  final Role role;

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
    id: readString(json, 'id'),
    email: readString(json, 'email'),
    displayName: readString(json, 'displayName'),
    role: readEnum(json, 'role', Role.values, Role.unknown),
  );

  /// For secure storage (restore without a network call).
  Map<String, Object?> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'role': apiEnumName(role),
  };
}

class LoginResponse {
  const LoginResponse({
    required this.accessToken,
    required this.expiresAt,
    required this.user,
  });

  final String accessToken;
  final DateTime expiresAt;
  final UserInfo user;

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
    accessToken: readString(json, 'accessToken'),
    expiresAt: readDate(json, 'expiresAt'),
    user: UserInfo.fromJson(asJsonMap(json['user'])),
  );
}

class MeResponse {
  const MeResponse({required this.user, required this.fleets});

  final UserInfo user;
  final List<Fleet> fleets;

  factory MeResponse.fromJson(Map<String, dynamic> json) => MeResponse(
    user: UserInfo.fromJson(asJsonMap(json['user'])),
    fleets: asJsonList(
      json['fleets'],
    ).map((f) => Fleet.fromJson(asJsonMap(f))).toList(growable: false),
  );
}
