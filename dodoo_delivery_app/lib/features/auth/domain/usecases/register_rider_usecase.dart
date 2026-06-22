import '../entities/rider_entity.dart';
import '../repositories/auth_repository.dart';

class RegisterRiderUseCase {
  final AuthRepository _repository;
  const RegisterRiderUseCase(this._repository);

  Future<RiderEntity> call(RegistrationData data) =>
      _repository.completeRegistration(data);
}
