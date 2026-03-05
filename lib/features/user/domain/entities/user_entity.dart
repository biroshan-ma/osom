class FeatureRole {
  final String featureName;
  final String role;
  final int? branch;

  FeatureRole({required this.featureName, required this.role, this.branch});
}

class UserEntity {
  final int id;
  final String fullName;
  final String role;
  final String email;
  final bool isActive;
  final String? phoneNumber;
  final String? notificationToken;
  final List<FeatureRole> featureRoles;

  UserEntity({
    required this.id,
    required this.fullName,
    required this.role,
    required this.email,
    required this.isActive,
    this.phoneNumber,
    this.notificationToken,
    this.featureRoles = const [],
  });
}

