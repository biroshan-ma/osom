import '../entities/auth_entity.dart';
import '../repository/auth_repository.dart';

class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  Future<AuthEntity> execute({required String email, required String password, required String subDomain, required String captchaToken}) {
    return repository.login(email: email, password: password, subDomain: subDomain, captchaToken: captchaToken);
  }
}
