import '../repositories/auth_repository.dart';

class SendOtpUseCase {
  final AuthRepository _repository;
  const SendOtpUseCase(this._repository);

  Future<String> call(String phone) => _repository.sendOtp(phone);
}
