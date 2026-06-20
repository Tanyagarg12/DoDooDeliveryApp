import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/firebase/firebase_auth_service.dart';
import '../../../../core/firebase/firestore_service.dart';
import '../../../../core/firebase/storage_service.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../domain/entities/rider_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/rider_model.dart';

class FirebaseAuthRepositoryImpl implements AuthRepository {
  FirebaseAuthRepositoryImpl({required SecureStorageService storage})
      : _storage = storage;

  final SecureStorageService _storage;
  final _auth = FirebaseAuthService.instance;
  final _fs = FirestoreService.instance;

  // Held in memory between register() and verifyOtp() calls
  RegistrationData? _pendingRegistration;

  @override
  Future<CheckPhoneResult> checkPhone(String phone) async {
    final rider = await _fs.findRiderByPhone(phone);
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
  }

  @override
  Future<String> sendOtp(String phone) async {
    await _auth.sendOtp(phone);
    return ''; // Firebase handles OTP natively — no dev_otp needed
  }

  @override
  Future<RiderEntity> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final user = await _auth.verifyOtp(otp);

    final existing = await _fs.getRider(user.uid);
    Map<String, dynamic> riderData;

    if (existing != null) {
      riderData = existing;
    } else {
      // New user — create Firestore document from pending registration
      final reg = _pendingRegistration;
      final data = <String, dynamic>{
        'phone': phone,
        'first_name': reg?.firstName ?? '',
        'last_name': reg?.lastName ?? '',
        'email': reg?.email ?? '',
        'address': reg?.address ?? '',
        'aadhar_number': reg?.aadhaarNumber ?? '',
        'driving_license_number': reg?.drivingLicenseNumber ?? '',
      };
      // Upload the photo + KYC documents to Firebase Storage (best-effort —
      // a failed upload shouldn't block account creation).
      if (reg != null) {
        await _uploadRegistrationDocs(user.uid, reg, data);
      }
      await _fs.createRider(user.uid, data);
      _pendingRegistration = null;
      riderData = {...data, 'id': user.uid, 'account_status': 'pending'};
    }

    final rider = RiderModel.fromJson(riderData);
    await _storage.saveRiderJson(rider.toJsonString());
    return rider;
  }

  @override
  Future<void> register(RegistrationData data) async {
    // Store locally — the actual Firestore write happens after OTP verification
    _pendingRegistration = data;
  }

  /// Uploads the registration photo + KYC images to Firebase Storage and adds
  /// their URLs into [data]. Each upload is best-effort.
  Future<void> _uploadRegistrationDocs(
    String uid,
    RegistrationData reg,
    Map<String, dynamic> data,
  ) async {
    final jobs = <String, ({String field, String path})>{
      'profile': (field: 'profile_picture_url', path: 'profile_pictures/$uid.jpg'),
      'aadhar_front': (
        field: 'aadhar_front_url',
        path: 'rider_documents/$uid/aadhar_front.jpg'
      ),
      'aadhar_back': (
        field: 'aadhar_back_url',
        path: 'rider_documents/$uid/aadhar_back.jpg'
      ),
      'license': (
        field: 'driving_license_image_url',
        path: 'rider_documents/$uid/license.jpg'
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
        final url = await StorageService.instance
            .uploadFile(entry.value.path, local);
        data[entry.value.field] = url;
      } catch (_) {
        // Best-effort — skip a failed upload, keep registering.
      }
    }
  }

  @override
  Future<RiderEntity?> getCachedRider() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    try {
      final riderData = await _fs.getRider(currentUser.uid);
      if (riderData == null) return null;
      final rider = RiderModel.fromJson(riderData);
      await _storage.saveRiderJson(rider.toJsonString());
      return rider;
    } catch (_) {
      // Fall back to locally cached data if Firestore is unavailable
      final json = await _storage.getRiderJson();
      if (json == null) return null;
      return RiderModel.fromJsonString(json);
    }
  }

  @override
  Future<void> logout() async {
    _pendingRegistration = null;
    await _auth.signOut();
    await _storage.clearAll();
  }

  @override
  Future<AccountStatus> fetchAccountStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('Not signed in');
    final data = await _fs.getRider(currentUser.uid);
    if (data == null) throw Exception('Rider document not found');
    return AccountStatus.fromString(data['account_status']?.toString());
  }
}
