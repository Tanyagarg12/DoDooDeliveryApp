import '../entities/rider_entity.dart';
import '../repositories/auth_repository.dart';

class RegisterRiderUseCase {
  final AuthRepository _repository;
  const RegisterRiderUseCase(this._repository);

  Future<void> call(RegistrationData data) => _repository.register(data);
}
