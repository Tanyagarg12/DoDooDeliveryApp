import '../../../../core/storage/secure_storage.dart';
import '../../domain/entities/rider_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/rider_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _datasource;
  final SecureStorageService _storage;

  const AuthRepositoryImpl({
    required AuthRemoteDataSource datasource,
    required SecureStorageService storage,
  })  : _datasource = datasource,
        _storage = storage;

  @override
  Future<CheckPhoneResult> checkPhone(String phone) =>
      _datasource.checkPhone(phone);

  @override
  Future<String> sendOtp(String phone) => _datasource.sendOtp(phone);

  @override
  Future<RiderEntity> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final result = await _datasource.verifyOtp(phone: phone, otp: otp);

    if (result.accessToken.isNotEmpty) {
      await _storage.saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
    }
    await _storage.saveRiderJson(result.rider.toJsonString());
    return result.rider;
  }

  @override
  Future<void> register(RegistrationData data) =>
      _datasource.register(data);

  @override
  Future<RiderEntity?> getCachedRider() async {
    try {
      final json = await _storage.getRiderJson();
      if (json == null) return null;
      return RiderModel.fromJsonString(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> logout() => _storage.clearAll();

  @override
  Future<AccountStatus> fetchAccountStatus() =>
      _datasource.fetchAccountStatus();
}
