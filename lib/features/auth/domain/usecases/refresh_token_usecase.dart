import '../repository/auth_repository.dart';

class RefreshTokenUseCase {
  final AuthRepository repository;

  RefreshTokenUseCase(this.repository);

  Future<bool> execute() {
    return repository.refreshToken();
  }
}
