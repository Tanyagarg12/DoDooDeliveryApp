import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RiderApi.init();
  runApp(const DodooRiderApp());
}

class DodooRiderApp extends StatelessWidget {
  const DodooRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0F766E);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DoDoo Rider',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: teal),
        scaffoldBackgroundColor: const Color(0xFFF4F7F6),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD5DEDC)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD5DEDC)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: teal, width: 1.6),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        useMaterial3: true,
      ),
      home: const RiderAuthScreen(),
    );
  }
}

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

  /// Call once from main() before runApp.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _customUrl = prefs.getString(_urlPrefKey);
  }

  /// Persist a custom backend URL so it survives app restarts.
  static Future<void> saveCustomUrl(String url) async {
    _customUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlPrefKey, url);
  }

  /// Clear any saved custom URL and revert to auto-detect.
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

  static String _normalizeApiUrl(String url) {
    var candidate = url.trim();
    if (candidate.isEmpty) return '';
    if (!candidate.startsWith('http://') && !candidate.startsWith('https://')) {
      candidate = 'http://$candidate';
    }

    final uri = Uri.tryParse(candidate);
    if (uri == null || uri.host.isEmpty) return '';

    var path = uri.path;
    if (path.isEmpty || path == '/') {
      path = '/api';
    }

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

  Future<Map<String, dynamic>> signup({
    required String phone,
    required String firstName,
    required String password,
    required String license,
    required String aadhar,
  }) async {
    final response = await _dio.post(
      '/riders/signup/',
      data: {
        'phone': phone,
        'first_name': firstName,
        'password': password,
        'password2': password,
        'driving_license_number': license,
        'aadhar_number': aadhar,
      },
    );
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final response = await _dio.post(
      '/riders/send-otp/',
      data: {'phone': phone},
    );
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final response = await _dio.post(
      '/riders/verify-otp/',
      data: {'phone': phone, 'otp': otp},
    );
    final data = Map<String, dynamic>.from(response.data);
    await saveTokens(data);
    return data;
  }

  Future<Map<String, dynamic>> login(
    String phone,
    String password, {
    bool saveToken = true,
  }) async {
    final response = await _dio.post(
      '/riders/login/',
      data: {'phone': phone, 'password': password},
    );
    final data = Map<String, dynamic>.from(response.data);
    if (saveToken) {
      await saveTokens(data);
    }
    return data;
  }

  Future<void> saveTokens(Map<String, dynamic> data) async {
    final accessToken = data['access_token']?.toString();
    final refreshToken = data['refresh_token']?.toString();
    if (accessToken != null && accessToken.isNotEmpty) {
      await storage.write(key: 'access_token', value: accessToken);
    }
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await storage.write(key: 'refresh_token', value: refreshToken);
    }
  }

  Future<Map<String, dynamic>> setStatus(String status) async {
    final token = await storage.read(key: 'access_token');
    final response = await _dio.post(
      '/riders/status/',
      data: {'status': status},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> dashboard() async {
    final response = await _dio.get(
      '/orders/rider-dashboard/',
      options: await _authOptions(),
    );
    return Map<String, dynamic>.from(response.data);
  }

  Future<List<Map<String, dynamic>>> offers() async {
    final response = await _dio.get(
      '/orders/offers/',
      options: await _authOptions(),
    );
    final data = response.data;
    if (data is List) {
      return data.map((item) => Map<String, dynamic>.from(item)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> acceptOrder(String orderId) async {
    final response = await _dio.post(
      '/orders/$orderId/accept/',
      options: await _authOptions(),
    );
    return Map<String, dynamic>.from(response.data);
  }

  Future<void> rejectOrder(String orderId) async {
    await _dio.post('/orders/$orderId/reject/', options: await _authOptions());
  }

  Future<Map<String, dynamic>> updateOrderStatus(
    String orderId,
    String status,
  ) async {
    final response = await _dio.post(
      '/orders/$orderId/status/',
      data: {'status': status},
      options: await _authOptions(),
    );
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> updateTracking({
    required double latitude,
    required double longitude,
    String? orderId,
    double? accuracy,
    double? speed,
    double? bearing,
  }) async {
    final data = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
    };
    if (orderId != null) data['order_id'] = orderId;
    if (accuracy != null) data['accuracy'] = accuracy;
    if (speed != null) data['speed'] = speed;
    if (bearing != null) data['bearing'] = bearing;

    final response = await _dio.post(
      '/tracking/rider/',
      data: data,
      options: await _authOptions(),
    );
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> requestWithdrawal({
    required String amount,
    required String bankAccount,
    required String bankIfsc,
  }) async {
    final response = await _dio.post(
      '/tracking/withdrawals/',
      data: {
        'amount': amount,
        'bank_account': bankAccount,
        'bank_ifsc': bankIfsc,
      },
      options: await _authOptions(),
    );
    return Map<String, dynamic>.from(response.data);
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
    final response = await _dio.put(
      '/riders/profile/',
      data: form,
      options: await _authOptions(),
    );
    return Map<String, dynamic>.from(response.data);
  }

  Future<Options> _authOptions() async {
    final token = await storage.read(key: 'access_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }
}

enum AuthMode { login, signup }

class RiderAuthScreen extends StatefulWidget {
  const RiderAuthScreen({super.key});

  @override
  State<RiderAuthScreen> createState() => _RiderAuthScreenState();
}

class _RiderAuthScreenState extends State<RiderAuthScreen> {
  RiderApi _api = RiderApi();
  final _phone = TextEditingController();
  final _firstName = TextEditingController();
  final _password = TextEditingController();
  final _license = TextEditingController();
  final _aadhar = TextEditingController();

  AuthMode _mode = AuthMode.login;
  bool _loading = false;
  String _message = '';

  bool get _isSignup => _mode == AuthMode.signup;

  @override
  void dispose() {
    _phone.dispose();
    _firstName.dispose();
    _password.dispose();
    _license.dispose();
    _aadhar.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_validate()) return;
    if (_isSignup) {
      await _signup();
    } else {
      await _loginWithOtp();
    }
  }

  bool _validate() {
    final phoneDigits = _phone.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (phoneDigits.length < 9 || phoneDigits.length > 10) {
      setState(() => _message = 'Enter a valid 10-digit mobile number.');
      return false;
    }
    if (_password.text.length < 6) {
      setState(() => _message = 'Password must be at least 6 characters.');
      return false;
    }
    if (_isSignup) {
      if (_firstName.text.trim().isEmpty) {
        setState(() => _message = 'Please enter your full name.');
        return false;
      }
      if (_license.text.trim().length < 5) {
        setState(() => _message = 'Enter a valid driving licence number (e.g. MH0120110012345).');
        return false;
      }
      if (_aadhar.text.trim().length != 12) {
        setState(() => _message = 'Aadhaar number must be exactly 12 digits.');
        return false;
      }
    }
    return true;
  }

  Future<void> _loginWithOtp() async {
    await _run(() async {
      final phone = _cleanPhone();
      final loginData = await _api.login(
        phone,
        _password.text,
        saveToken: false,
      );
      final otpData = await _api.sendOtp(phone);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            api: _api,
            phone: phone,
            devOtp: otpData['dev_otp']?.toString(),
            verifiedRider: Map<String, dynamic>.from(loginData['rider']),
            tokenData: loginData,
          ),
        ),
      );
    });
  }

  Future<void> _signup() async {
    await _run(() async {
      final phone = _cleanPhone();
      await _api.signup(
        phone: phone,
        firstName: _firstName.text.trim(),
        password: _password.text,
        license: _license.text.trim(),
        aadhar: _aadhar.text.trim(),
      );
      final otpData = await _api.sendOtp(phone);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            api: _api,
            phone: phone,
            devOtp: otpData['dev_otp']?.toString(),
          ),
        ),
      );
    });
  }

  Future<void> _sendOtpOnly() async {
    await _run(() async {
      final phone = _cleanPhone();
      final otpData = await _api.sendOtp(phone);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            api: _api,
            phone: phone,
            devOtp: otpData['dev_otp']?.toString(),
          ),
        ),
      );
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      await action();
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _message = _dioError(e));
        // Auto-open URL dialog on connection failure so the user can fix it immediately
        if (_isConnectionError(e)) {
          await _changeApiUrl();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isConnectionError(DioException e) =>
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.connectionError;

  String _dioError(DioException e) {
    if (_isConnectionError(e)) {
      return 'Cannot reach backend at ${_api.baseUrl}. '
          'Tap the API address above and enter your PC LAN address.';
    }
    final data = e.response?.data;
    if (data is Map && data.isNotEmpty) {
      final v = data.values.first;
      if (v is List && v.isNotEmpty) return v.first.toString();
      return v.toString();
    }
    return e.message ?? 'Request failed (${e.type.name})';
  }

  String _cleanPhone() {
    final digits = _phone.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    // Already has country code (e.g. user typed 91XXXXXXXXXX)
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    return '+91$digits';
  }

  /// Show a dialog to change the backend URL (auto-opened on connection failure).
  Future<void> _changeApiUrl() async {
    final controller = TextEditingController(text: _api.baseUrl);

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          String testStatus = '';
          bool testing = false;

          Future<void> testConnection() async {
            setLocal(() { testing = true; testStatus = 'Testing…'; });
            final normalized = RiderApi._normalizeApiUrl(controller.text);
            if (normalized.isEmpty) {
              setLocal(() {
                testing = false;
                testStatus = '✗ Invalid URL. Use http://192.168.1.42:8000/api';
              });
              return;
            }
            controller.text = normalized;
            try {
              final testDio = Dio(BaseOptions(
                baseUrl: normalized,
                connectTimeout: const Duration(seconds: 6),
                receiveTimeout: const Duration(seconds: 6),
              ));
              await testDio.get('/', options: Options(validateStatus: (_) => true));
              setLocal(() { testing = false; testStatus = '✓ Server reachable!'; });
            } on DioException catch (e) {
              final unreachable = e.type == DioExceptionType.connectionTimeout ||
                  e.type == DioExceptionType.connectionError;
              if (unreachable) {
                setLocal(() { testing = false; testStatus = '✗ Cannot reach $normalized'; });
              } else {
                // Any HTTP response (even 404) means the server IS up
                setLocal(() { testing = false; testStatus = '✓ Server reachable!'; });
              }
            } catch (_) {
              setLocal(() { testing = false; testStatus = '✗ Unknown error'; });
            }
          }

          return AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.wifi_off, color: Colors.orange),
                SizedBox(width: 8),
                Text('Fix Backend Connection'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F4FD),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF90CAF9)),
                    ),
                    child: const Text(
                      'Physical device: 10.0.2.2 only works in the emulator.\n\n'
                      '1. PC → Command Prompt → run:\n'
                      '      ipconfig\n'
                      '   Note the IPv4 Address (e.g. 192.168.1.42)\n\n'
                      '2. Start Django with:\n'
                      '      python manage.py runserver 0.0.0.0:8000\n\n'
                      '3. Phone & PC must be on the same Wi-Fi.\n\n'
                      '4. Enter URL below:\n'
                      '   http://192.168.1.42:8000/api\n\n'
                      'Windows Firewall blocking? Run in CMD (as admin):\n'
                      '   netsh advfirewall firewall add rule\n'
                      '   name="Django8000" dir=in action=allow\n'
                      '   protocol=TCP localport=8000',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Backend API URL',
                      hintText: 'http://192.168.1.42:8000/api',
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                  ),
                  if (testStatus.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      testStatus,
                      style: TextStyle(
                        fontSize: 13,
                        color: testStatus.startsWith('✓')
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await RiderApi.clearCustomUrl();
                  if (ctx.mounted) Navigator.pop(ctx, '');
                },
                child: const Text('Reset'),
              ),
              TextButton(
                onPressed: testing ? null : testConnection,
                child: const Text('Test'),
              ),
              FilledButton(
                onPressed: () {
                  final normalized = RiderApi._normalizeApiUrl(controller.text);
                  if (normalized.isEmpty) {
                    setLocal(() {});
                    return;
                  }
                  controller.text = normalized;
                  Navigator.pop(ctx, normalized);
                },
                child: const Text('Save & Retry'),
              ),
            ],
          );
        },
      ),
    );

    if (result == null) return; // dismissed without action
    if (result.isEmpty) {
      // Reset to default
      setState(() => _api = RiderApi());
    } else {
      await RiderApi.saveCustomUrl(result);
      setState(() => _api = RiderApi());
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.delivery_dining,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DoDoo Rider',
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          GestureDetector(
                            onTap: _changeApiUrl,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'API: ${_api.baseUrl}',
                                    style: textTheme.bodySmall?.copyWith(
                                      decoration: TextDecoration.underline,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(
                                  Icons.edit,
                                  size: 12,
                                  color: textTheme.bodySmall?.color,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SegmentedButton<AuthMode>(
                  segments: const [
                    ButtonSegment(
                      value: AuthMode.login,
                      label: Text('Login'),
                      icon: Icon(Icons.login),
                    ),
                    ButtonSegment(
                      value: AuthMode.signup,
                      label: Text('Create'),
                      icon: Icon(Icons.person_add),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: _loading
                      ? null
                      : (value) => setState(() => _mode = value.first),
                ),
                const SizedBox(height: 18),
                _AuthPanel(
                  title: _isSignup ? 'Create account' : 'Login',
                  subtitle: _isSignup
                      ? 'Enter rider details, then verify OTP.'
                      : 'Password first, OTP second.',
                  child: Column(
                    children: [
                      _phoneField(),
                      _field(
                        _password,
                        'Password',
                        TextInputType.visiblePassword,
                        obscure: true,
                        icon: Icons.lock,
                      ),
                      if (_isSignup) ...[
                        _field(
                          _firstName,
                          'Full name',
                          TextInputType.name,
                          icon: Icons.badge,
                        ),
                        _field(
                          _license,
                          'Driving licence number',
                          TextInputType.text,
                          icon: Icons.credit_card,
                          hint: 'e.g. MH0120110012345',
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9]'),
                            ),
                            LengthLimitingTextInputFormatter(16),
                          ],
                        ),
                        _field(
                          _aadhar,
                          'Aadhaar number',
                          TextInputType.number,
                          icon: Icons.assignment_ind,
                          hint: '12-digit Aadhaar',
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(12),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      FilledButton.icon(
                        onPressed: _loading ? null : _continue,
                        icon: Icon(
                          _isSignup
                              ? Icons.person_add_alt_1
                              : Icons.verified_user,
                        ),
                        label: Text(
                          _isSignup
                              ? 'Create account and verify OTP'
                              : 'Login and verify OTP',
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _sendOtpOnly,
                        icon: const Icon(Icons.sms),
                        label: const Text('Verify OTP only'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(
                          () => _mode = _isSignup
                              ? AuthMode.login
                              : AuthMode.signup,
                        ),
                  child: Text(
                    _isSignup
                        ? 'Already have an account? Login'
                        : 'New rider? Create account',
                  ),
                ),
                if (_loading) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                ],
                if (_message.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _MessageBanner(message: _message, isError: true),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Phone input with a fixed +91 country code prefix.
  Widget _phoneField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        decoration: InputDecoration(
          labelText: 'Mobile number',
          hintText: '10-digit number',
          prefixIcon: Container(
            margin: const EdgeInsets.only(left: 12, right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: const Color(0xFFD5DEDC)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('🇮🇳', style: TextStyle(fontSize: 16)),
                SizedBox(width: 6),
                Text(
                  '+91',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    TextInputType keyboardType, {
    bool obscure = false,
    IconData? icon,
    String? hint,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon == null ? null : Icon(icon),
        ),
      ),
    );
  }
}

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.api,
    required this.phone,
    this.devOtp,
    this.verifiedRider,
    this.tokenData,
  });

  final RiderApi api;
  final String phone;
  final String? devOtp;
  final Map<String, dynamic>? verifiedRider;
  final Map<String, dynamic>? tokenData;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  late final TextEditingController _otp = TextEditingController(
    text: widget.devOtp ?? '',
  );
  bool _loading = false;
  String _message = '';

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final data = await widget.api.verifyOtp(widget.phone, _otp.text.trim());
      if (widget.tokenData != null) {
        await widget.api.saveTokens(widget.tokenData!);
      }
      final rider =
          widget.verifiedRider ?? Map<String, dynamic>.from(data['rider']);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RiderHomeScreen(
            api: widget.api,
            rider: {...rider, 'is_verified': true},
          ),
        ),
      );
    } on DioException catch (error) {
      setState(() => _message = _formatError(error));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatError(DioException error) {
    final data = error.response?.data;
    if (data is Map && data.isNotEmpty) {
      return data.values.first.toString();
    }
    return 'OTP verification failed';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _AuthPanel(
                  title: 'Verify OTP',
                  subtitle: 'OTP sent to ${widget.phone}',
                  child: Column(
                    children: [
                      if (widget.devOtp != null) ...[
                        _MessageBanner(
                          message: 'Dev OTP auto-filled: ${widget.devOtp}',
                          isError: false,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _otp,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'OTP',
                          prefixIcon: Icon(Icons.pin),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _loading ? null : _verify,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Verify and continue'),
                      ),
                    ],
                  ),
                ),
                if (_loading) ...[
                  const SizedBox(height: 18),
                  const LinearProgressIndicator(),
                ],
                if (_message.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _MessageBanner(message: _message, isError: true),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key, required this.api, required this.rider});

  final RiderApi api;
  final Map<String, dynamic> rider;

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  late Map<String, dynamic> _rider = widget.rider;
  Map<String, dynamic> _earnings = {};
  List<Map<String, dynamic>> _activeOrders = [];
  List<Map<String, dynamic>> _orderHistory = [];
  List<Map<String, dynamic>> _pendingOffers = [];
  List<Map<String, dynamic>> _withdrawalRequests = [];
  final Set<String> _shownOfferIds = {};
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _bankAccount = TextEditingController();
  final _bankIfsc = TextEditingController();
  final _withdrawAmount = TextEditingController();
  XFile? _profilePhoto;
  Map<String, dynamic>? _tracking;
  Timer? _pollTimer;
  int _tabIndex = 0;
  bool _loading = false;
  String _message = 'Ready';

  @override
  void initState() {
    super.initState();
    _syncProfileControllers();
    _refreshDashboard(showLoading: true);
    _pollTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _refreshDashboard(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _address.dispose();
    _bankAccount.dispose();
    _bankIfsc.dispose();
    _withdrawAmount.dispose();
    super.dispose();
  }

  void _syncProfileControllers() {
    _firstName.text = _rider['first_name']?.toString() ?? '';
    _lastName.text = _rider['last_name']?.toString() ?? '';
    _email.text = _rider['email']?.toString() ?? '';
    _address.text = _rider['address']?.toString() ?? '';
    _bankAccount.text = _rider['bank_account_number']?.toString() ?? '';
    _bankIfsc.text = _rider['bank_ifsc_code']?.toString() ?? '';
  }

  Future<void> _refreshDashboard({bool showLoading = false}) async {
    if (showLoading) {
      setState(() => _loading = true);
    }
    try {
      final data = await widget.api.dashboard();
      final offers = _asMapList(data['pending_offers']);
      if (!mounted) return;
      setState(() {
        _rider = Map<String, dynamic>.from(data['rider'] ?? _rider);
        _activeOrders = _asMapList(data['active_orders']);
        _orderHistory = _asMapList(data['order_history']);
        _pendingOffers = offers;
        _withdrawalRequests = _asMapList(data['withdrawal_requests']);
        _earnings = Map<String, dynamic>.from(data['earnings_summary'] ?? {});
        _tracking = _findLatestTracking(_activeOrders);
        _message = 'Dashboard updated';
      });
      _showIncomingOfferIfNeeded(offers);
    } on DioException catch (error) {
      if (mounted) {
        setState(
          () => _message = _formatError(
            error,
            fallback: 'Dashboard refresh failed',
          ),
        );
      }
    } finally {
      if (mounted && showLoading) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _setStatus(String status) async {
    setState(() => _loading = true);
    try {
      final data = await widget.api.setStatus(status);
      setState(() {
        _rider = {..._rider, 'current_status': data['status']};
        _message = data['message'] ?? 'Status updated';
      });
      await _refreshDashboard();
    } on DioException catch (error) {
      setState(
        () => _message =
            error.response?.data.toString() ?? 'Status update failed',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _acceptOffer(Map<String, dynamic> offer) async {
    final order = Map<String, dynamic>.from(offer['order'] ?? {});
    final orderId = order['id']?.toString();
    if (orderId == null) return;
    Navigator.of(context).maybePop();
    setState(() => _loading = true);
    try {
      await widget.api.acceptOrder(orderId);
      if (!mounted) return;
      setState(
        () => _message = 'Order ${order['order_number'] ?? ''} accepted',
      );
      await _refreshDashboard();
    } on DioException catch (error) {
      if (mounted) {
        setState(
          () => _message = _formatError(error, fallback: 'Accept failed'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _rejectOffer(Map<String, dynamic> offer) async {
    final order = Map<String, dynamic>.from(offer['order'] ?? {});
    final orderId = order['id']?.toString();
    if (orderId == null) return;
    Navigator.of(context).maybePop();
    try {
      await widget.api.rejectOrder(orderId);
      if (!mounted) return;
      setState(() => _message = 'Offer rejected');
      await _refreshDashboard();
    } on DioException catch (error) {
      if (mounted) {
        setState(
          () => _message = _formatError(error, fallback: 'Reject failed'),
        );
      }
    }
  }

  Future<void> _updateOrderStage(
    Map<String, dynamic> order,
    String status,
  ) async {
    final orderId = order['id']?.toString();
    if (orderId == null) return;
    setState(() => _loading = true);
    try {
      await widget.api.updateOrderStatus(orderId, status);
      if (!mounted) return;
      setState(() => _message = 'Order moved to ${_statusLabel(status)}');
      await _refreshDashboard();
    } on DioException catch (error) {
      if (mounted) {
        setState(
          () =>
              _message = _formatError(error, fallback: 'Status update failed'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sendCurrentLocation() async {
    setState(() => _loading = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required for rider tracking');
      }
      final position = await Geolocator.getCurrentPosition();
      final activeOrderId = _activeOrders.isNotEmpty
          ? _activeOrders.first['id']?.toString()
          : null;
      final data = await widget.api.updateTracking(
        latitude: position.latitude,
        longitude: position.longitude,
        orderId: activeOrderId,
        accuracy: position.accuracy,
        speed: position.speed,
        bearing: position.heading,
      );
      if (!mounted) return;
      setState(() {
        _tracking = Map<String, dynamic>.from(data['tracking'] ?? {});
        _message = 'Location updated';
      });
      await _refreshDashboard();
    } catch (error) {
      if (mounted) {
        setState(() => _message = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<Position> _currentPosition() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is required for navigation');
    }
    return Geolocator.getCurrentPosition();
  }

  Future<void> _openDropDirections(Map<String, dynamic> order) async {
    setState(() => _loading = true);
    try {
      final position = await _currentPosition();
      final dropLat = order['to_latitude'];
      final dropLng = order['to_longitude'];
      if (dropLat == null || dropLng == null) {
        throw Exception('Drop location is missing');
      }
      final navigationUri = Uri.parse(
        'google.navigation:q=$dropLat,$dropLng&mode=d',
      );
      final geoUri = Uri.parse('geo:0,0?q=$dropLat,$dropLng');
      final directionsUri = Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'origin': '${position.latitude},${position.longitude}',
        'destination': '$dropLat,$dropLng',
        'travelmode': 'driving',
      });
      var opened = false;
      if (!kIsWeb) {
        opened =
            await _tryOpenExternal(navigationUri) ||
            await _tryOpenExternal(geoUri);
      }
      opened = opened || await _tryOpenExternal(directionsUri);
      if (!opened) {
        throw Exception('Could not open Maps. Rebuild the app after pub get.');
      }
      if (mounted) {
        setState(() => _message = 'Opening Google Maps directions');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<bool> _tryOpenExternal(Uri uri) async {
    try {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<void> _requestWithdrawal() async {
    setState(() => _loading = true);
    try {
      final data = await widget.api.requestWithdrawal(
        amount: _withdrawAmount.text.trim(),
        bankAccount: _bankAccount.text.trim(),
        bankIfsc: _bankIfsc.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _withdrawAmount.clear();
        _rider = {
          ..._rider,
          'wallet_balance':
              data['wallet']?['balance'] ?? _rider['wallet_balance'],
        };
        final withdrawal = data['withdrawal'];
        if (withdrawal is Map) {
          _withdrawalRequests = [
            Map<String, dynamic>.from(withdrawal),
            ..._withdrawalRequests,
          ];
        }
        _message = 'Withdrawal accepted';
      });
      await _refreshDashboard();
    } on DioException catch (error) {
      if (mounted) {
        setState(
          () => _message = _formatError(error, fallback: 'Withdrawal failed'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickProfilePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked != null && mounted) {
      setState(() => _profilePhoto = picked);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _loading = true);
    try {
      final data = await widget.api.updateProfile(
        fields: {
          'first_name': _firstName.text.trim(),
          'last_name': _lastName.text.trim(),
          'email': _email.text.trim(),
          'address': _address.text.trim(),
          'bank_account_number': _bankAccount.text.trim(),
          'bank_ifsc_code': _bankIfsc.text.trim(),
        },
        photo: _profilePhoto,
      );
      if (!mounted) return;
      setState(() {
        _rider = data;
        _profilePhoto = null;
        _message = 'Profile updated';
      });
    } on DioException catch (error) {
      if (mounted) {
        setState(
          () =>
              _message = _formatError(error, fallback: 'Profile update failed'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showIncomingOfferIfNeeded(List<Map<String, dynamic>> offers) {
    if (offers.isEmpty || !mounted) return;
    final offer = offers.firstWhere(
      (item) => !_shownOfferIds.contains(item['id']?.toString()),
      orElse: () => {},
    );
    final offerId = offer['id']?.toString();
    if (offerId == null || offerId.isEmpty) return;
    _shownOfferIds.add(offerId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _IncomingOrderSheet(
          offer: offer,
          onAccept: () => _acceptOffer(offer),
          onReject: () => _rejectOffer(offer),
        ),
      );
    });
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is List) {
      return value.map((item) => Map<String, dynamic>.from(item)).toList();
    }
    return [];
  }

  Map<String, dynamic>? _findLatestTracking(List<Map<String, dynamic>> orders) {
    for (final order in orders) {
      final tracking = order['tracking'];
      if (tracking is Map && tracking.isNotEmpty) {
        return Map<String, dynamic>.from(tracking);
      }
    }
    return _tracking;
  }

  String _statusLabel(String status) => status.replaceAll('_', ' ');

  String _formatError(DioException error, {required String fallback}) {
    final data = error.response?.data;
    if (data is Map && data.isNotEmpty) {
      return data.values.first.toString();
    }
    return error.message ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final status = _rider['current_status'] ?? 'offline';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Home'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading
                ? null
                : () => _refreshDashboard(showLoading: true),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              await RiderApi.storage.deleteAll();
              if (!context.mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const RiderAuthScreen()),
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hi ${_rider['first_name'] ?? 'Rider'}',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text('${_rider['phone']}'),
                        ],
                      ),
                    ),
                    _StatusPill(status: status),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Availability',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'offline',
                      label: Text('Offline'),
                      icon: Icon(Icons.power_settings_new),
                    ),
                    ButtonSegment(
                      value: 'online',
                      label: Text('Online'),
                      icon: Icon(Icons.delivery_dining),
                    ),
                    ButtonSegment(
                      value: 'busy',
                      label: Text('Busy'),
                      icon: Icon(Icons.timelapse),
                    ),
                  ],
                  selected: {status},
                  onSelectionChanged: _loading
                      ? null
                      : (values) => _setStatus(values.first),
                ),
                const SizedBox(height: 18),
                NavigationBar(
                  selectedIndex: _tabIndex,
                  onDestinationSelected: (index) =>
                      setState(() => _tabIndex = index),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard),
                      label: 'Summary',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.local_shipping),
                      label: 'Orders',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.location_on),
                      label: 'Tracker',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.payments),
                      label: 'Earnings',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.settings),
                      label: 'Settings',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_tabIndex == 0) _summaryTab(),
                if (_tabIndex == 1) _ordersTab(),
                if (_tabIndex == 2) _trackerTab(),
                if (_tabIndex == 3) _earningsTab(),
                if (_tabIndex == 4) _settingsTab(),
                if (_loading) ...[
                  const SizedBox(height: 18),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 16),
                _MessageBanner(message: _message, isError: false),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryTab() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _metric(
                'Offers',
                '${_pendingOffers.length}',
                Icons.notifications_active,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metric('Active', '${_activeOrders.length}', Icons.route),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _metric(
                'Wallet',
                'Rs ${_rider['wallet_balance'] ?? '0.00'}',
                Icons.account_balance_wallet,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metric(
                'Rating',
                '${_rider['rating'] ?? '5.0'}',
                Icons.star,
              ),
            ),
          ],
        ),
        if (_pendingOffers.isNotEmpty) ...[
          const SizedBox(height: 8),
          _sectionHeader('Incoming offers'),
          ..._pendingOffers.map((offer) => _offerTile(offer)),
        ],
      ],
    );
  }

  Widget _ordersTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Active orders'),
        if (_activeOrders.isEmpty)
          const _EmptyState(text: 'No active orders right now.'),
        ..._activeOrders.map((order) => _activeOrderTile(order)),
        const SizedBox(height: 12),
        _sectionHeader('Pending dispatch offers'),
        if (_pendingOffers.isEmpty)
          const _EmptyState(
            text: 'No pending offers. Go online to receive dispatches.',
          ),
        ..._pendingOffers.map((offer) => _offerTile(offer)),
        const SizedBox(height: 12),
        _sectionHeader('Order history'),
        if (_orderHistory.isEmpty)
          const _EmptyState(text: 'Completed orders will appear here.'),
        ..._orderHistory.map((order) => _OrderCard(order: order)),
      ],
    );
  }

  Widget _earningsTab() {
    return Column(
      children: [
        _metric(
          'Today earnings',
          'Rs ${_earnings['today'] ?? '0.00'}',
          Icons.today,
        ),
        _metric(
          'Week earnings',
          'Rs ${_earnings['week'] ?? '0.00'}',
          Icons.calendar_view_week,
        ),
        _metric(
          'Month earnings',
          'Rs ${_earnings['month'] ?? '0.00'}',
          Icons.calendar_month,
        ),
        _metric(
          'Completed orders',
          '${_earnings['completed_orders'] ?? 0}',
          Icons.task_alt,
        ),
        const SizedBox(height: 8),
        _sectionHeader('Wallet withdrawal'),
        _WithdrawalPanel(
          balance: _rider['wallet_balance'] ?? '0.00',
          amount: _withdrawAmount,
          bankAccount: _bankAccount.text,
          bankIfsc: _bankIfsc.text,
          loading: _loading,
          onSubmit: _requestWithdrawal,
        ),
        const SizedBox(height: 12),
        _sectionHeader('Withdrawal history'),
        if (_withdrawalRequests.isEmpty)
          const _EmptyState(text: 'No withdrawal requests yet.'),
        ..._withdrawalRequests.map((item) => _WithdrawalTile(item: item)),
      ],
    );
  }

  Widget _trackerTab() {
    final order = _activeOrders.isNotEmpty ? _activeOrders.first : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Current route'),
        if (order == null)
          const _EmptyState(
            text: 'Accept an order to see pickup and drop details.',
          ),
        if (order != null) ...[
          _RoutePanel(
            order: order,
            onNavigate: () => _openDropDirections(order),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _loading ? null : _sendCurrentLocation,
            icon: const Icon(Icons.my_location),
            label: const Text('Update my live location'),
          ),
        ],
        const SizedBox(height: 12),
        _sectionHeader('Tracker'),
        _TrackingPanel(tracking: _tracking),
      ],
    );
  }

  Widget _settingsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Profile settings'),
        _ProfilePhotoRow(
          rider: _rider,
          pickedPhoto: _profilePhoto,
          onPick: _pickProfilePhoto,
        ),
        const SizedBox(height: 12),
        _settingsField(_firstName, 'First name', Icons.badge),
        _settingsField(_lastName, 'Last name', Icons.badge_outlined),
        _settingsField(
          _email,
          'Email',
          Icons.email,
          keyboardType: TextInputType.emailAddress,
        ),
        _settingsField(_address, 'Address', Icons.home, maxLines: 2),
        _settingsField(
          _bankAccount,
          'Bank account number',
          Icons.account_balance,
        ),
        _settingsField(_bankIfsc, 'Bank IFSC code', Icons.pin),
        const SizedBox(height: 4),
        FilledButton.icon(
          onPressed: _loading ? null : _saveProfile,
          icon: const Icon(Icons.save),
          label: const Text('Save settings'),
        ),
      ],
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _offerTile(Map<String, dynamic> offer) {
    final order = Map<String, dynamic>.from(offer['order'] ?? {});
    return _OrderCard(
      order: order,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Reject',
            onPressed: () => _rejectOffer(offer),
            icon: const Icon(Icons.close),
          ),
          IconButton.filled(
            tooltip: 'Accept',
            onPressed: () => _acceptOffer(offer),
            icon: const Icon(Icons.check),
          ),
        ],
      ),
    );
  }

  Widget _activeOrderTile(Map<String, dynamic> order) {
    final next = _nextOrderStatus(order['status']?.toString() ?? 'accepted');
    return _OrderCard(
      order: order,
      footer: next == null
          ? FilledButton.icon(
              onPressed: _loading ? null : () => _openDropDirections(order),
              icon: const Icon(Icons.map),
              label: const Text('Navigate to drop'),
            )
          : Column(
              children: [
                FilledButton.icon(
                  onPressed: _loading ? null : () => _openDropDirections(order),
                  icon: const Icon(Icons.map),
                  label: const Text('Navigate to drop'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _updateOrderStage(order, next),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text('Mark ${_statusLabel(next)}'),
                ),
              ],
            ),
    );
  }

  String? _nextOrderStatus(String status) {
    const flow = [
      'accepted',
      'picked_up',
      'in_transit',
      'reached',
      'completed',
    ];
    final index = flow.indexOf(status);
    if (index == -1 || index == flow.length - 1) return null;
    return flow[index + 1];
  }

  Widget _settingsField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDDE4E8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _IncomingOrderSheet extends StatelessWidget {
  const _IncomingOrderSheet({
    required this.offer,
    required this.onAccept,
    required this.onReject,
  });

  final Map<String, dynamic> offer;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final order = Map<String, dynamic>.from(offer['order'] ?? {});
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_active,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Incoming order ${order['order_number'] ?? ''}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _OrderDetails(order: order),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check),
                  label: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, this.trailing, this.footer});

  final Map<String, dynamic> order;
  final Widget? trailing;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDDE4E8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.local_shipping,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(child: _OrderDetails(order: order)),
              ?trailing,
            ],
          ),
          if (footer != null) ...[const SizedBox(height: 12), footer!],
        ],
      ),
    );
  }
}

class _RoutePanel extends StatelessWidget {
  const _RoutePanel({required this.order, required this.onNavigate});

  final Map<String, dynamic> order;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDDE4E8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RouteStop(
            icon: Icons.store,
            label: 'Pickup',
            address: '${order['from_address'] ?? '-'}',
            lat: order['from_latitude'],
            lng: order['from_longitude'],
          ),
          const Divider(height: 22),
          _RouteStop(
            icon: Icons.flag,
            label: 'Drop',
            address: '${order['to_address'] ?? '-'}',
            lat: order['to_latitude'],
            lng: order['to_longitude'],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _MiniBadge(text: '${order['distance_in_km'] ?? 0} km'),
              _MiniBadge(text: '${order['estimated_time_minutes'] ?? 30} min'),
              _MiniBadge(text: '${order['status'] ?? 'accepted'}'),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onNavigate,
            icon: const Icon(Icons.map),
            label: const Text('Navigate to drop'),
          ),
        ],
      ),
    );
  }
}

class _WithdrawalPanel extends StatelessWidget {
  const _WithdrawalPanel({
    required this.balance,
    required this.amount,
    required this.bankAccount,
    required this.bankIfsc,
    required this.loading,
    required this.onSubmit,
  });

  final dynamic balance;
  final TextEditingController amount;
  final String bankAccount;
  final String bankIfsc;
  final bool loading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDDE4E8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Available Rs $balance',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Withdrawal amount',
              prefixIcon: Icon(Icons.currency_rupee),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _MiniBadge(
                text: bankAccount.isEmpty
                    ? 'Bank account missing'
                    : 'Bank $bankAccount',
              ),
              _MiniBadge(
                text: bankIfsc.isEmpty ? 'IFSC missing' : 'IFSC $bankIfsc',
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: loading ? null : onSubmit,
            icon: const Icon(Icons.payments),
            label: const Text('Request withdrawal'),
          ),
        ],
      ),
    );
  }
}

class _WithdrawalTile extends StatelessWidget {
  const _WithdrawalTile({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDDE4E8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.receipt_long,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rs ${item['amount'] ?? '0.00'}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Requested ${item['requested_at'] ?? '-'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if ((item['transaction_id']?.toString() ?? '').isNotEmpty)
                  Text(
                    'Ref ${item['transaction_id']}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          _MiniBadge(text: '${item['status'] ?? 'pending'}'),
        ],
      ),
    );
  }
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({
    required this.icon,
    required this.label,
    required this.address,
    required this.lat,
    required this.lng,
  });

  final IconData icon;
  final String label;
  final String address;
  final dynamic lat;
  final dynamic lng;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(address),
              const SizedBox(height: 2),
              Text('$lat, $lng', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrackingPanel extends StatelessWidget {
  const _TrackingPanel({required this.tracking});

  final Map<String, dynamic>? tracking;

  @override
  Widget build(BuildContext context) {
    if (tracking == null || tracking!.isEmpty) {
      return const _EmptyState(text: 'No live location has been sent yet.');
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDDE4E8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lat: ${tracking!['latitude']}'),
          Text('Lng: ${tracking!['longitude']}'),
          Text('Accuracy: ${tracking!['accuracy'] ?? '-'} m'),
          Text('Updated: ${tracking!['updated_at'] ?? '-'}'),
        ],
      ),
    );
  }
}

class _ProfilePhotoRow extends StatelessWidget {
  const _ProfilePhotoRow({
    required this.rider,
    required this.pickedPhoto,
    required this.onPick,
  });

  final Map<String, dynamic> rider;
  final XFile? pickedPhoto;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final imageUrl = rider['profile_picture_url']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDDE4E8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: imageUrl.isEmpty ? null : NetworkImage(imageUrl),
            child: imageUrl.isEmpty ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              pickedPhoto == null ? 'Upload rider photo' : pickedPhoto!.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Choose photo',
            onPressed: onPick,
            icon: const Icon(Icons.photo_camera),
          ),
        ],
      ),
    );
  }
}

class _OrderDetails extends StatelessWidget {
  const _OrderDetails({required this.order});

  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${order['order_number'] ?? 'Order'}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text('${order['from_address'] ?? '-'}'),
        const SizedBox(height: 2),
        Text('${order['to_address'] ?? '-'}'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _MiniBadge(text: '${order['distance_in_km'] ?? 0} km'),
            _MiniBadge(
              text:
                  'Rs ${order['total_earning'] ?? order['minimum_fare'] ?? '0.00'}',
            ),
            _MiniBadge(text: '${order['status'] ?? 'pending'}'),
          ],
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isOnline = status == 'online';
    final isBusy = status == 'busy';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isOnline
            ? const Color(0xFFE8F5F1)
            : isBusy
            ? const Color(0xFFFFF4DE)
            : const Color(0xFFF0F2F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: isOnline
              ? const Color(0xFF0B5F56)
              : isBusy
              ? const Color(0xFF835400)
              : const Color(0xFF4B5563),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5F4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFA),
        border: Border.all(color: const Color(0xFFDDE4E8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text),
    );
  }
}

class _AuthPanel extends StatelessWidget {
  const _AuthPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDDE4E8)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? colors.errorContainer : const Color(0xFFE8F5F1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isError ? colors.onErrorContainer : const Color(0xFF0B5F56),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
