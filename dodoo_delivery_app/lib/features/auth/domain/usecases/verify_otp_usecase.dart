import '../entities/rider_entity.dart';
import '../repositories/auth_repository.dart';

class VerifyOtpUseCase {
  final AuthRepository _repository;
  const VerifyOtpUseCase(this._repository);

  Future<RiderEntity?> call({required String phone, required String otp}) =>
      _repository.verifyOtp(phone: phone, otp: otp);
}
