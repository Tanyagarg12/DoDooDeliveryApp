import '../entities/rider_entity.dart';

abstract class AuthRepository {
  /// Check whether a phone number is already registered.
  Future<CheckPhoneResult> checkPhone(String phone);

  /// Trigger OTP dispatch. Returns the dev_otp for on-screen display.
  Future<String> sendOtp(String phone);

  /// Verify OTP. Returns the rider if they already exist, or **null** if the
  /// OTP is valid but this is a new number that still needs to register.
  Future<RiderEntity?> verifyOtp({required String phone, required String otp});

  /// Create a new rider after OTP has been verified (account_status = pending).
  Future<RiderEntity> completeRegistration(RegistrationData data);

  /// Return the locally cached rider, or null if not logged in.
  Future<RiderEntity?> getCachedRider();

  /// Restore a previously logged-in rider on app launch: reads the saved
  /// session, re-establishes [RiderSession] + the anonymous Firebase session,
  /// and refreshes the rider from Firestore. Returns null if nobody is logged
  /// in (so the app shows the login screen).
  Future<RiderEntity?> restoreSession();

  /// Clear tokens and cached rider data (logout).
  Future<void> logout();

  /// Lightweight poll — returns the current account_status without re-sending OTP.
  Future<AccountStatus> fetchAccountStatus();
}
