import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import '../errors/exceptions.dart';
import '../storage/secure_storage.dart';

class ApiClient {
  static String? _customUrl;
  late final Dio _dio;

  ApiClient(SecureStorageService secureStorage) {
    _dio = Dio(BaseOptions(
      baseUrl: _resolveBaseUrl(),
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(_AuthInterceptor(secureStorage, _dio));
    _dio.interceptors.add(_ErrorInterceptor());
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ));
    }
  }

  /// Call once from main() before runApp — loads any saved custom URL.
  /// Also re-normalises old URLs that may have been saved without the port.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(ApiConstants.prefKeyCustomUrl);
    if (saved != null && saved.isNotEmpty) {
      final fixed = normalise(saved);
      _customUrl = fixed;
      if (fixed != saved) {
        // Persist the corrected URL so future runs use the right port
        await prefs.setString(ApiConstants.prefKeyCustomUrl, fixed);
      }
    }
  }

  /// Persist a custom backend URL. Accepts bare IPs and normalises them.
  static Future<void> setCustomUrl(String raw) async {
    final url = normalise(raw);
    _customUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiConstants.prefKeyCustomUrl, url);
  }

  static Future<void> clearCustomUrl() async {
    _customUrl = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConstants.prefKeyCustomUrl);
  }

  /// Normalise user input:
  ///  "192.168.1.5"        → "http://192.168.1.5:8000"
  ///  "192.168.1.5:8000"   → "http://192.168.1.5:8000"
  ///  "http://192.168.1.5" → "http://192.168.1.5:8000"
  static String normalise(String raw) {
    String url = raw.trim();
    if (url.isEmpty) return url;

    // Add scheme if missing
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }

    // Dart's Uri.port returns 80 for plain http:// URLs (HTTP default), not 0.
    // So we must check uri.authority (the "host:port" string) for an explicit colon
    // rather than comparing uri.port == 0.
    final uri = Uri.tryParse(url);
    if (uri != null && uri.host.isNotEmpty && !uri.authority.contains(':')) {
      // No explicit port — add :8000
      url = uri.replace(port: 8000).toString();
    }

    // Strip trailing slash
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static String _resolveBaseUrl() {
    if (_customUrl != null && _customUrl!.isNotEmpty) return _customUrl!;
    if (kIsWeb) return ApiConstants.localhost;
    return ApiConstants.localAndroidEmulator;
  }

  /// The URL that will be used for the next request.
  static String get currentBaseUrl => _resolveBaseUrl();

  // ── Sync base URL before every request so URL changes take effect immediately
  void _syncBaseUrl() => _dio.options.baseUrl = _resolveBaseUrl();

  Future<Response> get(String path, {Map<String, dynamic>? queryParams}) async {
    _syncBaseUrl();
    return _dio.get(path, queryParameters: queryParams);
  }

  Future<Response> post(String path, {dynamic data}) async {
    _syncBaseUrl();
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) async {
    _syncBaseUrl();
    return _dio.put(path, data: data);
  }

  Future<Response> postMultipart(String path, FormData formData) async {
    _syncBaseUrl();
    return _dio.post(path, data: formData);
  }

  /// Quick connectivity test — hits the health endpoint and returns true on any response.
  Future<bool> testConnection() async {
    _syncBaseUrl();
    try {
      await _dio.get(
        '/api/health/',
        options: Options(
          validateStatus: (_) => true,
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ── Interceptors ──────────────────────────────────────────────────────────────

class _AuthInterceptor extends Interceptor {
  final SecureStorageService _storage;
  final Dio _dio;

  _AuthInterceptor(this._storage, this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      try {
        final refreshToken = await _storage.getRefreshToken();
        if (refreshToken == null) return handler.next(err);

        final response = await _dio.post(
          '/api/token/refresh/',
          data: {'refresh': refreshToken},
        );
        final newAccess = response.data['access'] as String?;
        if (newAccess == null) return handler.next(err);

        await _storage.saveTokens(
          accessToken: newAccess,
          refreshToken: refreshToken,
        );
        err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
        final retried = await _dio.fetch(err.requestOptions);
        return handler.resolve(retried);
      } catch (_) {
        await _storage.clearAll();
      }
    }
    handler.next(err);
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return handler.reject(DioException(
          requestOptions: err.requestOptions,
          error: const NetworkException('Connection timed out'),
          type: err.type,
        ));
      case DioExceptionType.connectionError:
        return handler.reject(DioException(
          requestOptions: err.requestOptions,
          error: const NetworkException('Cannot reach the server'),
          type: err.type,
        ));
      default:
        handler.next(err);
    }
  }
}
