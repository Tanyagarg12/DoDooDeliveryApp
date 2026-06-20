class AppConstants {
  AppConstants._();

  static const String appName = 'DoDoo Rider';
  static const int primaryTealValue = 0xFF0F766E;

  // Secure storage keys
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyRiderData = 'rider_data';

  // Image compression
  static const int imageMaxWidth = 1024;
  static const int imageMaxHeight = 1024;
  static const int imageQuality = 75;
  static const int imageMaxSizeKb = 500;

  // OTP
  static const int otpLength = 6;
  static const int otpResendSeconds = 60;
}
