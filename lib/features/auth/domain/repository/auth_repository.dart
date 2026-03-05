import '../entities/auth_entity.dart';

abstract class AuthRepository {
  Future<AuthEntity> login({required String email, required String password, required String subDomain, required String captchaToken});
  Future<void> logout();
  Future<bool> refreshToken();
}
