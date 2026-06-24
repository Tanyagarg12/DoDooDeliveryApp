import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/cloudinary/cloudinary_service.dart';
import '../../../../core/firebase/firestore_service.dart';
import '../../../../core/session/rider_session.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../orders_api/data/dodoo_order_api.dart';
import '../../domain/entities/rider_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/rider_model.dart';

/// Auth backed by:
///  • the external **DoDoo OTP API** for phone verification (no Firebase Phone
///    Auth / Blaze needed), and
///  • **Firestore** for rider data, with an anonymous Firebase session so the
///    security rules pass.
///
/// Riders are identified by their **phone number**, which is also their
/// Firestore `riders` document id (see [RiderSession]).
class FirebaseAuthRepositoryImpl implements AuthRepository {
  FirebaseAuthRepositoryImpl({required SecureStorageService storage})
      : _storage = storage;

  final SecureStorageService _storage;
  final _fs = FirestoreService.instance;
  final _dodoo = DodooOrderApi();

  // Held in memory between sendOtp and verifyOtp.
  String? _pendingOtp;

  static String _digits(String phone) => phone.replaceAll(RegExp(r'[^0-9]'), '');

  /// Anonymous Firebase session so Firestore rules (`request.auth != null`) pass.
  Future<void> _ensureAnonSession() async {
    if (FirebaseAuth.instance.currentUser == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
      } catch (_) {/* Anonymous sign-in must be enabled in the console */}
    }
  }

  @override
  Future<CheckPhoneResult> checkPhone(String phone) async {
    await _ensureAnonSession();
    final id = _digits(phone);
    // This lookup is only an optimization (it decides the OTP-screen hint).
    // The OTP itself comes from the DoDoo HTTPS API, so a Firestore hiccup
    // (e.g. cloud_firestore/unavailable on a flaky network) must NOT block
    // sending the OTP. On failure we treat the number as unknown; verifyOtp
    // re-resolves existing-vs-new after the code is entered.
    try {
      final rider = await _fs.getRider(id);
      if (rider == null) {
        return CheckPhoneResult(exists: false, phone: phone);
      }
      return CheckPhoneResult(
        exists: true,
        phone: phone,
        accountStatus: AccountStatus.fromString(
            rider['account_status']?.toString()),
        riderId: rider['id']?.toString(),
      );
    } catch (_) {
      return CheckPhoneResult(exists: false, phone: phone);
    }
  }

  @override
  Future<String> sendOtp(String phone) async {
    // DoDoo generates + SMSes the OTP and returns the code.
    final otp = await _dodoo.validateSignup(_digits(phone));
    if (otp == null || otp.isEmpty) {
      throw const ServerException('Could not send OTP. Please try again.');
    }
    _pendingOtp = otp.trim();
    // Return empty so the code is NOT shown on screen — the rider gets it by SMS.
    return '';
  }

  @override
  Future<RiderEntity?> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    if (_pendingOtp == null || otp.trim() != _pendingOtp) {
      throw const UnauthorizedException();
    }
    final id = _digits(phone);
    await _ensureAnonSession();
    RiderSession.riderId = id;
    _pendingOtp = null;

    // Existing rider → return them. New number → null (caller routes to register).
    // A thrown error here means Firestore was unreachable (NOT "new rider"),
    // so surface a clear network message instead of mis-routing to register.
    Map<String, dynamic>? existing;
    try {
      existing = await _fs.getRider(id);
    } catch (_) {
      throw const ServerException(
          'Could not reach the server. Check your internet and try again.');
    }
    if (existing == null) return null;
    final rider = RiderModel.fromJson(existing);
    await _storage.saveRiderJson(rider.toJsonString());
    return rider;
  }

  @override
  Future<RiderEntity> completeRegistration(RegistrationData data) async {
    // OTP already verified; the anonymous session + RiderSession are set.
    final id = _digits(data.phone);
    await _ensureAnonSession();
    RiderSession.riderId = id;

    final fields = <String, dynamic>{
      'phone': id,
      'first_name': data.firstName,
      'last_name': data.lastName,
      'email': data.email ?? '',
      'address': data.address ?? '',
      'aadhar_number': data.aadhaarNumber ?? '',
      'driving_license_number': data.drivingLicenseNumber ?? '',
    };
    await _uploadRegistrationDocs(id, data, fields);
    await _fs.createRider(id, fields);

    final rider =
        RiderModel.fromJson({...fields, 'id': id, 'account_status': 'pending'});
    await _storage.saveRiderJson(rider.toJsonString());
    return rider;
  }

  /// Uploads the registration photo + KYC images to Cloudinary and adds their
  /// URLs into [data]. Each upload is best-effort. [id] is the rider's phone.
  Future<void> _uploadRegistrationDocs(
    String id,
    RegistrationData reg,
    Map<String, dynamic> data,
  ) async {
    final jobs = <String, ({String field, String folder, String publicId})>{
      'profile': (
        field: 'profile_picture_url',
        folder: 'profile_pictures',
        publicId: id
      ),
      'aadhar_front': (
        field: 'aadhar_front_url',
        folder: 'rider_documents/$id',
        publicId: 'aadhar_front'
      ),
      'aadhar_back': (
        field: 'aadhar_back_url',
        folder: 'rider_documents/$id',
        publicId: 'aadhar_back'
      ),
      'license': (
        field: 'driving_license_image_url',
        folder: 'rider_documents/$id',
        publicId: 'license'
      ),
    };
    final locals = <String, String?>{
      'profile': reg.profilePicturePath,
      'aadhar_front': reg.aadhaarFrontPath,
      'aadhar_back': reg.aadhaarBackPath,
      'license': reg.drivingLicenseImagePath,
    };

    for (final entry in jobs.entries) {
      final local = locals[entry.key];
      if (local == null || local.isEmpty) continue;
      try {
        final url = await CloudinaryService.instance.uploadFile(
          local,
          folder: entry.value.folder,
          publicId: entry.value.publicId,
        );
        data[entry.value.field] = url;
      } catch (_) {
        // Best-effort — skip a failed upload, keep registering.
      }
    }
  }

  @override
  Future<RiderEntity?> getCachedRider() async {
    final id = RiderSession.riderId;
    if (id == null) return null;
    try {
      final riderData = await _fs.getRider(id);
      if (riderData == null) return null;
      final rider = RiderModel.fromJson(riderData);
      await _storage.saveRiderJson(rider.toJsonString());
      return rider;
    } catch (_) {
      final json = await _storage.getRiderJson();
      if (json == null) return null;
      return RiderModel.fromJsonString(json);
    }
  }

  @override
  Future<RiderEntity?> restoreSession() async {
    final json = await _storage.getRiderJson();
    if (json == null || json.isEmpty) return null;

    RiderModel cached;
    try {
      cached = RiderModel.fromJsonString(json);
    } catch (_) {
      return null; // corrupt cache → treat as logged out
    }

    final id = cached.id.isNotEmpty ? cached.id : _digits(cached.phone);
    if (id.isEmpty) return null;
    RiderSession.riderId = id;
    await _ensureAnonSession();

    // Refresh from Firestore so approval/status changes show after a restart.
    try {
      final fresh = await _fs.getRider(id);
      if (fresh != null) {
        final rider = RiderModel.fromJson(fresh);
        await _storage.saveRiderJson(rider.toJsonString());
        return rider;
      }
    } catch (_) {/* offline — fall back to the cached rider below */}
    return cached;
  }

  @override
  Future<void> logout() async {
    _pendingOtp = null;
    RiderSession.riderId = null;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    await _storage.clearAll();
  }

  @override
  Future<AccountStatus> fetchAccountStatus() async {
    final id = RiderSession.riderId;
    if (id == null) throw Exception('Not signed in');
    final data = await _fs.getRider(id);
    if (data == null) throw Exception('Rider document not found');
    return AccountStatus.fromString(data['account_status']?.toString());
  }
}
