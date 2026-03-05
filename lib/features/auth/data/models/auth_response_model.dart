import '../../domain/entities/auth_entity.dart';

class AuthResponseModel extends AuthEntity {
  const AuthResponseModel({required super.accessToken, super.refreshToken});

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    // Some APIs return 'token' while others use 'access_token'. Prefer 'token' if present.
    final token = (json['token'] ?? json['access_token']) as String;
    final refresh = json['refresh_token'] as String?;
    return AuthResponseModel(
      accessToken: token,
      refreshToken: refresh,
    );
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        if (refreshToken != null) 'refresh_token': refreshToken,
      };
}
