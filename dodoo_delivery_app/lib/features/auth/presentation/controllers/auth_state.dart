import '../../domain/entities/rider_entity.dart';

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Phone check completed — phone does not exist → show registration.
class AuthNeedsRegistration extends AuthState {
  final String phone;
  const AuthNeedsRegistration(this.phone);
}

/// OTP was sent to the phone; waiting for user to enter it.
class AuthOtpSent extends AuthState {
  final String phone;
  final bool isNewRegistration;
  /// The OTP returned by the backend (demo only — remove in production).
  final String devOtp;
  const AuthOtpSent({
    required this.phone,
    this.isNewRegistration = false,
    this.devOtp = '',
  });
}

/// Registration submitted; OTP pending verification.
class AuthRegistrationSubmitted extends AuthState {
  final String phone;
  const AuthRegistrationSubmitted(this.phone);
}

/// OTP verified — rider is fully authenticated.
class AuthAuthenticated extends AuthState {
  final RiderEntity rider;
  const AuthAuthenticated(this.rider);
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}
