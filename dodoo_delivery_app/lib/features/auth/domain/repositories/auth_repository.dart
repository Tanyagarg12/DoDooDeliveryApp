import '../entities/rider_entity.dart';

abstract class AuthRepository {
  /// Check whether a phone number is already registered.
  Future<CheckPhoneResult> checkPhone(String phone);

  /// Trigger OTP dispatch. Returns the dev_otp for on-screen display.
  Future<String> sendOtp(String phone);

  /// Verify OTP and return authenticated rider.
  Future<RiderEntity> verifyOtp({required String phone, required String otp});

  /// Register a new rider (no password). Sets account_status = pending.
  Future<void> register(RegistrationData data);

  /// Return the locally cached rider, or null if not logged in.
  Future<RiderEntity?> getCachedRider();

  /// Clear tokens and cached rider data (logout).
  Future<void> logout();

  /// Lightweight poll — returns the current account_status without re-sending OTP.
  Future<AccountStatus> fetchAccountStatus();
}
