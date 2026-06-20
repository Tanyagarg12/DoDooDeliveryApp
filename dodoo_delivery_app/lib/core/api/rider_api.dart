import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RiderApi {
  RiderApi()
      : _dio = Dio(
          BaseOptions(
            baseUrl: _resolveBaseUrl(),
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            headers: {'Content-Type': 'application/json'},
          ),
        );

  static const storage = FlutterSecureStorage();
  static const _urlPrefKey = 'dodoo_api_url';
  static String? _customUrl;
  final Dio _dio;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _customUrl = prefs.getString(_urlPrefKey);
  }

  static Future<void> saveCustomUrl(String url) async {
    _customUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlPrefKey, url);
  }

  static Future<void> clearCustomUrl() async {
    _customUrl = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_urlPrefKey);
  }

  static String _resolveBaseUrl() {
    if (_customUrl != null && _customUrl!.isNotEmpty) return _customUrl!;
    const configured = String.fromEnvironment('DODOO_API_URL');
    if (configured.isNotEmpty) return configured;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://127.0.0.1:8000/api';
  }

  String get baseUrl => _dio.options.baseUrl;

  static String normalizeApiUrl(String url) {
    var candidate = url.trim();
    if (candidate.isEmpty) return '';
    if (!candidate.startsWith('http://') && !candidate.startsWith('https://')) {
      candidate = 'http://$candidate';
    }
    final uri = Uri.tryParse(candidate);
    if (uri == null || uri.host.isEmpty) return '';
    var path = uri.path;
    if (path.isEmpty || path == '/') path = '/api';
    final normalized = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: path,
    ).toString();
    return normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<void> saveTokens(Map<String, dynamic> data) async {
    final access = data['access_token']?.toString();
    final refresh = data['refresh_token']?.toString();
    if (access != null && access.isNotEmpty) {
      await storage.write(key: 'access_token', value: access);
    }
    if (refresh != null && refresh.isNotEmpty) {
      await storage.write(key: 'refresh_token', value: refresh);
    }
  }

  Future<void> logout() async => storage.deleteAll();

  // ── Rider ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> setStatus(String status) async {
    final token = await storage.read(key: 'access_token');
    final res = await _dio.post(
      '/riders/status/',
      data: {'status': status},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> dashboard() async {
    final res = await _dio.get(
      '/orders/rider-dashboard/',
      options: await _authOptions(),
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> updateProfile({
    required Map<String, String> fields,
    XFile? photo,
  }) async {
    final form = FormData.fromMap({
      ...fields,
      if (photo != null)
        'profile_picture': MultipartFile.fromBytes(
          await photo.readAsBytes(),
          filename: photo.name,
        ),
    });
    final res = await _dio.put(
      '/riders/profile/',
      data: form,
      options: await _authOptions(),
    );
    return Map<String, dynamic>.from(res.data);
  }

  // ── Orders ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> acceptOrder(String orderId) async {
    final res = await _dio.post(
      '/orders/$orderId/accept/',
      options: await _authOptions(),
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<void> rejectOrder(String orderId) async =>
      _dio.post('/orders/$orderId/reject/', options: await _authOptions());

  Future<Map<String, dynamic>> updateOrderStatus(
      String orderId, String status) async {
    final res = await _dio.post(
      '/orders/$orderId/status/',
      data: {'status': status},
      options: await _authOptions(),
    );
    return Map<String, dynamic>.from(res.data);
  }

  // ── Tracking ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> sendCurrentLocation({String? orderId}) async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission required for tracking');
    }
    final pos = await Geolocator.getCurrentPosition();
    final data = <String, dynamic>{
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'accuracy': pos.accuracy,
      'speed': pos.speed,
      'bearing': pos.heading,
      if (orderId != null) 'order_id': orderId,
    };
    final res = await _dio.post(
      '/tracking/rider/',
      data: data,
      options: await _authOptions(),
    );
    return Map<String, dynamic>.from(res.data);
  }

  // ── Order History ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> orderHistory(String filter) async {
    final res = await _dio.get(
      '/orders/history/?filter=$filter',
      options: await _authOptions(),
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<String?> getAccessToken() async =>
      storage.read(key: 'access_token');

  // ── Earnings ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> requestWithdrawal({
    required String amount,
    required String bankAccount,
    required String bankIfsc,
  }) async {
    final res = await _dio.post(
      '/tracking/withdrawals/',
      data: {
        'amount': amount,
        'bank_account': bankAccount,
        'bank_ifsc': bankIfsc,
      },
      options: await _authOptions(),
    );
    return Map<String, dynamic>.from(res.data);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<Options> _authOptions() async {
    final token = await storage.read(key: 'access_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }
}
