class ApiConstants {
  ApiConstants._();

  static const String localAndroidEmulator = 'http://10.0.2.2:8000';
  static const String localDevice = 'http://192.168.1.11:8000';
  static const String localhost = 'http://127.0.0.1:8000';

  static const String prefKeyCustomUrl = 'dodoo_api_url';

  // Riders
  static const String checkPhone = '/api/riders/check-phone/';
  static const String register = '/api/riders/register/';
  static const String sendOtp = '/api/riders/send-otp/';
  static const String verifyOtp = '/api/riders/verify-otp/';
  static const String login = '/api/riders/login/';
  static const String profile = '/api/riders/profile/';
  static const String riderStatus = '/api/riders/status/';
  static const String meStatus = '/api/riders/me/status/';

  // Admin
  static const String adminLogin = '/api/riders/admin/login/';
  static const String adminStats = '/api/riders/admin/stats/';
  static const String adminRiders = '/api/riders/admin/riders/';

  // Orders
  static const String dashboard = '/api/orders/rider-dashboard/';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
