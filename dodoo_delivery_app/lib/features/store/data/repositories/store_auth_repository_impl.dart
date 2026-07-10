import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/cloudinary/cloudinary_service.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/firebase/store_firestore_service.dart';
import '../../../../core/session/store_session.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../orders_api/data/dodoo_order_api.dart';
import '../../domain/entities/store_entity.dart';
import '../models/store_model.dart';

/// Store auth, backed by:
///  • the external **DoDoo OTP API** for phone verification (reused from the
///    rider flow — no Firebase Phone Auth / Blaze needed), and
///  • **Firestore** for the store doc, under an anonymous Firebase session.
///
/// Stores are identified by the owner's phone number (the `stores` doc id).
class StoreAuthRepository {
  StoreAuthRepository({required SecureStorageService storage})
      : _storage = storage;

  final SecureStorageService _storage;
  final _fs = StoreFirestoreService.instance;
  final _dodoo = DodooOrderApi();

  // Held in memory between sendOtp and verifyOtp.
  String? _pendingOtp;

  static String _digits(String phone) => phone.replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _ensureAnonSession() async {
    if (FirebaseAuth.instance.currentUser == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
      } catch (_) {/* Anonymous sign-in must be enabled in the console */}
    }
  }

  /// Optimistic existence check (decides the OTP-screen hint). A Firestore
  /// hiccup must not block sending the OTP, so failures are treated as "new".
  Future<StoreCheckPhoneResult> checkPhone(String phone) async {
    await _ensureAnonSession();
    final id = _digits(phone);
    try {
      final store = await _fs.getStore(id);
      if (store == null) {
        return StoreCheckPhoneResult(exists: false, phone: phone);
      }
      return StoreCheckPhoneResult(
        exists: true,
        phone: phone,
        accountStatus: store['account_status']?.toString(),
      );
    } catch (_) {
      return StoreCheckPhoneResult(exists: false, phone: phone);
    }
  }

  /// DoDoo generates + SMSes the OTP and returns the code; we hold it to verify.
  Future<void> sendOtp(String phone) async {
    final otp = await _dodoo.validateSignup(_digits(phone));
    if (otp == null || otp.isEmpty) {
      throw const ServerException('Could not send OTP. Please try again.');
    }
    _pendingOtp = otp.trim();
  }

  /// Verifies the code (client-side, matching the rider flow). Returns the
  /// existing store, or null for a new number (caller routes to registration).
  Future<StoreEntity?> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    if (_pendingOtp == null || otp.trim() != _pendingOtp) {
      throw const UnauthorizedException();
    }
    final id = _digits(phone);
    await _ensureAnonSession();
    StoreSession.storeId = id;
    _pendingOtp = null;

    Map<String, dynamic>? existing;
    try {
      existing = await _fs.getStore(id);
    } catch (_) {
      throw const ServerException(
          'Could not reach the server. Check your internet and try again.');
    }
    if (existing == null) return null;
    final store = StoreModel.fromJson(existing);
    await _storage.saveStoreJson(store.toJsonString());
    return store;
  }

  Future<StoreEntity> completeRegistration(StoreRegistrationData data) async {
    final id = _digits(data.phone);
    await _ensureAnonSession();
    StoreSession.storeId = id;

    final fields = <String, dynamic>{
      'phone': id,
      'owner_first_name': data.ownerFirstName,
      'owner_last_name': data.ownerLastName,
      'store_name': data.storeName,
      'category': data.category,
      'email': data.email ?? '',
      'address': data.address,
      'city_code': data.cityCode,
      'fssai_number': data.fssaiNumber,
      'gst_number': data.gstNumber,
      'owner_id_type': data.ownerIdType,
      'owner_id_number': data.ownerIdNumber,
    };
    await _uploadDocs(id, data, fields);
    // All uploaded documents start pending admin verification.
    fields['document_status'] = {
      'storefront': 'pending',
      'fssai': 'pending',
      'owner_id': 'pending',
    };

    await _fs.createStore(id, fields);

    final store = StoreModel.fromJson(
        {...fields, 'id': id, 'account_status': 'pending'});
    await _storage.saveStoreJson(store.toJsonString());
    return store;
  }

  /// Uploads the storefront / FSSAI / owner-ID images to Cloudinary and adds
  /// their URLs into [target]. Each upload is best-effort.
  Future<void> _uploadDocs(
    String id,
    StoreRegistrationData reg,
    Map<String, dynamic> target,
  ) async {
    final jobs = <String, ({String field, String publicId, String? path})>{
      'storefront': (
        field: 'storefront_photo_url',
        publicId: 'storefront',
        path: reg.storefrontPhotoPath
      ),
      'fssai': (
        field: 'fssai_doc_url',
        publicId: 'fssai',
        path: reg.fssaiDocPath
      ),
      'owner_id': (
        field: 'owner_id_url',
        publicId: 'owner_id',
        path: reg.ownerIdPath
      ),
    };
    for (final job in jobs.values) {
      final path = job.path;
      if (path == null || path.isEmpty) continue;
      try {
        target[job.field] = await CloudinaryService.instance.uploadFile(
          path,
          folder: 'store_documents/$id',
          publicId: job.publicId,
        );
      } catch (_) {/* best-effort — skip a failed upload */}
    }
  }

  Future<StoreEntity?> restoreSession() async {
    final json = await _storage.getStoreJson();
    if (json == null || json.isEmpty) return null;

    StoreModel cached;
    try {
      cached = StoreModel.fromJsonString(json);
    } catch (_) {
      return null;
    }

    final id = cached.id.isNotEmpty ? cached.id : _digits(cached.phone);
    if (id.isEmpty) return null;
    StoreSession.storeId = id;
    await _ensureAnonSession();

    // Refresh from Firestore so approval/status changes show after a restart.
    try {
      final fresh = await _fs.getStore(id);
      if (fresh != null) {
        final store = StoreModel.fromJson(fresh);
        await _storage.saveStoreJson(store.toJsonString());
        return store;
      }
    } catch (_) {/* offline — fall back to the cached store */}
    return cached;
  }

  /// Re-reads the account status from Firestore (for the status screen).
  Future<String> refreshAccountStatus() => _fs.fetchAccountStatus();

  /// Marks the store as having entered the app (tapped "Start"), so the
  /// one-time "Store Approved!" welcome isn't shown again. Persists to
  /// Firestore and refreshes the local cache.
  Future<void> markStarted(String storeId) async {
    await _ensureAnonSession();
    await _fs.updateStore({'has_started': true}, storeId);
    final fresh = await _fs.getStore(storeId);
    if (fresh != null) {
      await _storage.saveStoreJson(StoreModel.fromJson(fresh).toJsonString());
    }
  }

  Future<void> logout() async {
    _pendingOtp = null;
    StoreSession.storeId = null;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    await _storage.clearAll();
  }
}
