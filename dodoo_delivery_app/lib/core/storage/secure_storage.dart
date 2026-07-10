import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

class SecureStorageService {
  const SecureStorageService();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // The rider session is ALSO mirrored to plain SharedPreferences. Encrypted
  // secure-storage reads occasionally fail on a cold start (keystore quirks),
  // which would log the rider out on reopen. The rider's own profile is not
  // secret (Firestore is the source of truth), so a plain mirror is a safe,
  // reliable fallback that keeps them logged in until they log out manually.
  static const _prefsRiderKey = 'rider_session_json';
  // Store (merchant) app session — same dual secure + plain-mirror approach.
  static const _prefsStoreKey = 'store_session_json';
  static const _secureStoreKey = 'store_session_data';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: AppConstants.keyAccessToken, value: accessToken),
      _storage.write(key: AppConstants.keyRefreshToken, value: refreshToken),
    ]);
  }

  Future<String?> getAccessToken() =>
      _storage.read(key: AppConstants.keyAccessToken);

  Future<String?> getRefreshToken() =>
      _storage.read(key: AppConstants.keyRefreshToken);

  Future<void> saveRiderJson(String json) async {
    try {
      await _storage.write(key: AppConstants.keyRiderData, value: json);
    } catch (_) {/* fall back to the plain mirror below */}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsRiderKey, json);
    } catch (_) {}
  }

  Future<String?> getRiderJson() async {
    try {
      final v = await _storage.read(key: AppConstants.keyRiderData);
      if (v != null && v.isNotEmpty) return v;
    } catch (_) {/* secure read flaked — use the plain mirror */}
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_prefsRiderKey);
      if (v != null && v.isNotEmpty) return v;
    } catch (_) {}
    return null;
  }

  Future<bool> hasSession() async {
    final rider = await getRiderJson();
    return rider != null && rider.isNotEmpty;
  }

  // ── Store (merchant) session ───────────────────────────────────────────────

  Future<void> saveStoreJson(String json) async {
    try {
      await _storage.write(key: _secureStoreKey, value: json);
    } catch (_) {/* fall back to the plain mirror below */}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsStoreKey, json);
    } catch (_) {}
  }

  Future<String?> getStoreJson() async {
    try {
      final v = await _storage.read(key: _secureStoreKey);
      if (v != null && v.isNotEmpty) return v;
    } catch (_) {/* secure read flaked — use the plain mirror */}
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_prefsStoreKey);
      if (v != null && v.isNotEmpty) return v;
    } catch (_) {}
    return null;
  }

  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsRiderKey);
      await prefs.remove(_prefsStoreKey);
    } catch (_) {}
  }
}
