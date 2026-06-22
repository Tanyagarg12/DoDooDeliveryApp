import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/repositories/firebase_auth_repository_impl.dart';
import '../../domain/entities/rider_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/check_phone_usecase.dart';
import '../../domain/usecases/register_rider_usecase.dart';
import '../../domain/usecases/send_otp_usecase.dart';
import '../../domain/usecases/verify_otp_usecase.dart';
import 'auth_state.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final secureStorageProvider = Provider<SecureStorageService>(
  (_) => const SecureStorageService(),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  // Auth now runs on Firebase (phone OTP + Firestore rider docs).
  return FirebaseAuthRepositoryImpl(
    storage: ref.watch(secureStorageProvider),
  );
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthController(
    checkPhone: CheckPhoneUseCase(repo),
    sendOtp: SendOtpUseCase(repo),
    verifyOtp: VerifyOtpUseCase(repo),
    register: RegisterRiderUseCase(repo),
    repository: repo,
  );
});

// ── Controller ───────────────────────────────────────────────────────────────

class AuthController extends StateNotifier<AuthState> {
  final CheckPhoneUseCase _checkPhone;
  final SendOtpUseCase _sendOtp;
  final VerifyOtpUseCase _verifyOtp;
  final RegisterRiderUseCase _register;
  final AuthRepository _repository;

  AuthController({
    required CheckPhoneUseCase checkPhone,
    required SendOtpUseCase sendOtp,
    required VerifyOtpUseCase verifyOtp,
    required RegisterRiderUseCase register,
    required AuthRepository repository,
  })  : _checkPhone = checkPhone,
        _sendOtp = sendOtp,
        _verifyOtp = verifyOtp,
        _register = register,
        _repository = repository,
        super(const AuthInitial());

  void reset() => state = const AuthInitial();

  /// Step 1 — Always send an OTP (existing or new number). The OTP is verified
  /// FIRST; registration (for new numbers) happens after verification.
  Future<void> checkPhone(String phone) async {
    state = const AuthLoading();
    try {
      final result = await _checkPhone(phone);
      final devOtp = await _sendOtp(phone);
      state = AuthOtpSent(
          phone: phone, isNewRegistration: !result.exists, devOtp: devOtp);
    } on NetworkException catch (e) {
      state = AuthError(e.message);
    } on ServerException catch (e) {
      state = AuthError(e.message);
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  /// Step 2 — Verify OTP. Existing rider → authenticated; new number → goes to
  /// the registration form (OTP already proven).
  Future<void> verifyOtp({required String phone, required String otp}) async {
    state = const AuthLoading();
    try {
      final rider = await _verifyOtp(phone: phone, otp: otp);
      if (rider != null) {
        state = AuthAuthenticated(rider);
      } else {
        state = AuthNeedsRegistration(phone);
      }
    } on NetworkException catch (e) {
      state = AuthError(e.message);
    } on ServerException catch (e) {
      state = AuthError(e.message);
    } on UnauthorizedException {
      state = const AuthError('Invalid OTP. Please try again.');
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  /// Step 3 — New rider submits the registration form (after OTP verification).
  Future<void> registerRider(RegistrationData data) async {
    state = const AuthLoading();
    try {
      final rider = await _register(data);
      state = AuthAuthenticated(rider);
    } on NetworkException catch (e) {
      state = AuthError(e.message);
    } on ServerException catch (e) {
      state = AuthError(e.message);
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  /// Resend OTP — returns the new devOtp so the screen can update the hint.
  Future<String> resendOtp(String phone) async {
    try {
      return await _sendOtp(phone);
    } on NetworkException catch (e) {
      state = AuthError(e.message);
    } on ServerException catch (e) {
      state = AuthError(e.message);
    } catch (_) {}
    return '';
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthInitial();
  }

  /// Poll-based status refresh: calls /api/riders/me/status/ with the stored
  /// JWT (no OTP resend). Only updates state if approved.
  Future<void> refreshStatus(RiderEntity rider) async {
    try {
      final newStatus = await _repository.fetchAccountStatus();
      if (newStatus != rider.accountStatus) {
        if (newStatus == AccountStatus.approved) {
          NotificationService.instance
              .showApproval(
                title: 'Account approved 🎉',
                body: 'Your account is approved. You can start accepting orders!',
              )
              .ignore();
        }
        state = AuthAuthenticated(rider.copyWith(accountStatus: newStatus));
      }
    } on NetworkException {
      // Silently ignore — status refresh is best-effort
    } on ServerException {
      // Silently ignore
    } catch (_) {}
  }
}
