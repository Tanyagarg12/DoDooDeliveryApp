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

  /// Step 1 — Check if the phone is registered and decide the next step.
  Future<void> checkPhone(String phone) async {
    state = const AuthLoading();
    try {
      final result = await _checkPhone(phone);
      if (result.exists) {
        final devOtp = await _sendOtp(phone);
        state = AuthOtpSent(phone: phone, isNewRegistration: false, devOtp: devOtp);
      } else {
        state = AuthNeedsRegistration(phone);
      }
    } on NetworkException catch (e) {
      state = AuthError(e.message);
    } on ServerException catch (e) {
      state = AuthError(e.message);
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  /// Step 2a — New user submits registration form with documents.
  Future<void> registerRider(RegistrationData data) async {
    state = const AuthLoading();
    try {
      await _register(data);
      final devOtp = await _sendOtp(data.phone);
      state = AuthOtpSent(phone: data.phone, isNewRegistration: true, devOtp: devOtp);
    } on NetworkException catch (e) {
      state = AuthError(e.message);
    } on ServerException catch (e) {
      state = AuthError(e.message);
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  /// Step 2b — Verify OTP (both login and post-registration).
  Future<void> verifyOtp({required String phone, required String otp}) async {
    state = const AuthLoading();
    try {
      final rider = await _verifyOtp(phone: phone, otp: otp);
      state = AuthAuthenticated(rider);
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
