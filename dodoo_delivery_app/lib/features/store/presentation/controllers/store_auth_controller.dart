import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/repositories/store_auth_repository_impl.dart';
import '../../domain/entities/store_entity.dart';
import 'store_auth_state.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final storeSecureStorageProvider =
    Provider<SecureStorageService>((_) => const SecureStorageService());

final storeAuthRepositoryProvider = Provider<StoreAuthRepository>(
  (ref) => StoreAuthRepository(storage: ref.watch(storeSecureStorageProvider)),
);

final storeAuthControllerProvider =
    StateNotifierProvider<StoreAuthController, StoreAuthState>(
  (ref) => StoreAuthController(ref.watch(storeAuthRepositoryProvider)),
);

// ── Controller ────────────────────────────────────────────────────────────────

class StoreAuthController extends StateNotifier<StoreAuthState> {
  StoreAuthController(this._repo) : super(const StoreAuthInitial());

  final StoreAuthRepository _repo;

  /// Checks the phone (for the hint) and always sends an OTP.
  Future<void> checkPhone(String phone) async {
    state = const StoreAuthLoading();
    try {
      final res = await _repo.checkPhone(phone);
      await _repo.sendOtp(phone);
      state = StoreAuthOtpSent(phone: phone, isNewRegistration: !res.exists);
    } catch (e) {
      state = StoreAuthError(_msg(e));
    }
  }

  Future<void> verifyOtp({required String phone, required String otp}) async {
    state = const StoreAuthLoading();
    try {
      final store = await _repo.verifyOtp(phone: phone, otp: otp);
      state = store == null
          ? StoreAuthNeedsRegistration(phone)
          : StoreAuthAuthenticated(store);
    } catch (e) {
      state = StoreAuthError(_msg(e));
    }
  }

  Future<void> registerStore(StoreRegistrationData data) async {
    state = const StoreAuthLoading();
    try {
      final store = await _repo.completeRegistration(data);
      state = StoreAuthAuthenticated(store);
    } catch (e) {
      state = StoreAuthError(_msg(e));
    }
  }

  Future<void> resendOtp(String phone) async {
    try {
      await _repo.sendOtp(phone);
    } catch (_) {/* best-effort */}
  }

  /// Re-checks status (resume / manual). Emits the updated store on change.
  Future<void> refreshStatus(StoreEntity store) async {
    try {
      final status = await _repo.refreshAccountStatus();
      if (status != store.accountStatus) {
        state = StoreAuthAuthenticated(store.copyWith(accountStatus: status));
      }
    } catch (_) {/* best-effort */}
  }

  /// Records that the store tapped "Start" (one-time welcome seen). Best-effort
  /// — navigation into the app proceeds regardless.
  Future<void> markStarted(StoreEntity store) async {
    try {
      await _repo.markStarted(store.id);
    } catch (_) {/* best-effort */}
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const StoreAuthInitial();
  }

  void reset() => state = const StoreAuthInitial();

  static String _msg(Object e) {
    if (e is UnauthorizedException) return 'Incorrect OTP. Please try again.';
    if (e is ServerException) return e.message;
    final m = e.toString();
    if (m.contains('SocketException') || m.contains('connection')) {
      return 'Cannot reach server. Check your connection.';
    }
    return m.replaceFirst('Exception: ', '');
  }
}
