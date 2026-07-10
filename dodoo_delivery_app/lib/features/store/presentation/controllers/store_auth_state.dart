import '../../domain/entities/store_entity.dart';

sealed class StoreAuthState {
  const StoreAuthState();
}

class StoreAuthInitial extends StoreAuthState {
  const StoreAuthInitial();
}

class StoreAuthLoading extends StoreAuthState {
  const StoreAuthLoading();
}

/// Phone verified but no store exists → collect registration details.
class StoreAuthNeedsRegistration extends StoreAuthState {
  final String phone;
  const StoreAuthNeedsRegistration(this.phone);
}

/// OTP sent to the phone; waiting for the code.
class StoreAuthOtpSent extends StoreAuthState {
  final String phone;
  final bool isNewRegistration;
  const StoreAuthOtpSent({required this.phone, this.isNewRegistration = false});
}

/// Fully authenticated store.
class StoreAuthAuthenticated extends StoreAuthState {
  final StoreEntity store;
  const StoreAuthAuthenticated(this.store);
}

class StoreAuthError extends StoreAuthState {
  final String message;
  const StoreAuthError(this.message);
}
