import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  UserModel({
    required int id,
    required String fullName,
    required String role,
    required String email,
    required bool isActive,
    String? phoneNumber,
    String? notificationToken,
    List<FeatureRole> featureRoles = const [],
  }) : super(
          id: id,
          fullName: fullName,
          role: role,
          email: email,
          isActive: isActive,
          phoneNumber: phoneNumber,
          notificationToken: notificationToken,
          featureRoles: featureRoles,
        );

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final roles = <FeatureRole>[];
    if (json['feature_roles'] is List) {
      for (final r in json['feature_roles']) {
        try {
          roles.add(FeatureRole(
            featureName: r['feature_name']?.toString() ?? '',
            role: r['role']?.toString() ?? '',
            branch: r['branch'] is int ? r['branch'] as int : int.tryParse(r['branch']?.toString() ?? ''),
          ));
        } catch (_) {}
      }
    }

    return UserModel(
      id: json['user_id'] is int ? json['user_id'] as int : int.tryParse(json['user_id']?.toString() ?? '') ?? 0,
      fullName: (json['user_full_name'] ?? json['fullName'] ?? json['name'] ?? '') as String,
      role: (json['role'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      isActive: (json['is_active'] ?? true) as bool,
      phoneNumber: json['phone_number']?.toString(),
      notificationToken: json['notification_token']?.toString(),
      featureRoles: roles,
    );
  }
}

