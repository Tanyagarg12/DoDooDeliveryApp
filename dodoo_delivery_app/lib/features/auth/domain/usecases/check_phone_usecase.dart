import '../entities/rider_entity.dart';
import '../repositories/auth_repository.dart';

class CheckPhoneUseCase {
  final AuthRepository _repository;
  const CheckPhoneUseCase(this._repository);

  Future<CheckPhoneResult> call(String phone) => _repository.checkPhone(phone);
}
