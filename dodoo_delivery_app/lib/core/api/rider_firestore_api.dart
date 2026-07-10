import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../cloudinary/cloudinary_service.dart';
import '../firebase/firestore_service.dart';
import '../../features/orders_api/data/dodoo_order_api.dart';

/// Drop-in replacement for [RiderApi] that reads/writes Firestore instead of
/// calling a Django REST backend.  All method signatures are identical so the
/// dashboard controller and home shell don't need structural changes.
class RiderFirestoreApi {
  final _fs = FirestoreService.instance;
  final _dodoo = DodooOrderApi();

  /// Kept for WebSocket compatibility — returns empty string so the WS service
  /// skips the connection attempt when no token is present.
  String get baseUrl => '';

  // ── Rider status ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> setStatus(String status) async {
    await _fs.updateRider({'current_status': status});
    return {'status': status};
  }

  // ── Dashboard ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> dashboard() => _fs.dashboard();

  // ── Orders ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> acceptOrder(String orderId) async {
    final res = await _fs.acceptOrder(orderId);
    _dodoo
        .pushStatus(
          orderNumber: res['order_number']?.toString() ?? '',
          internalStatus: 'accepted',
          orderType: res['order_type']?.toString(),
          riderId: _fs.currentUid,
        )
        .ignore();
    return res;
  }

  Future<void> rejectOrder(String orderId) => _fs.rejectOrder(orderId);

  Future<Map<String, dynamic>> updateOrderStatus(
      String orderId, String status) async {
    final res = await _fs.updateOrderStatus(orderId, status);
    _dodoo
        .pushStatus(
          orderNumber: res['order_number']?.toString() ?? '',
          internalStatus: status,
          orderType: res['order_type']?.toString(),
          riderId: _fs.currentUid,
        )
        .ignore();
    return res;
  }

  // ── History ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> orderHistory(String filter) =>
      _fs.history(filter);

  // ── Location ──────────────────────────────────────────────────────────────

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
    await _fs.updateTracking(
      lat: pos.latitude,
      lng: pos.longitude,
      accuracy: pos.accuracy,
      speed: pos.speed,
      bearing: pos.heading,
      orderId: orderId,
    );
    return {
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'accuracy': pos.accuracy,
    };
  }

  // ── Earnings ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> requestWithdrawal({
    required String amount,
    required String bankAccount,
    required String bankIfsc,
    String? accountHolderName,
    String? bankName,
  }) async {
    final amt = double.tryParse(amount) ?? 0;
    await _fs.requestWithdrawal(
      amount: amt,
      bankAccount: bankAccount,
      bankIfsc: bankIfsc,
      accountHolderName: accountHolderName,
      bankName: bankName,
    );
    // Deduct locally and return updated wallet (Firestore does NOT do this
    // atomically here — admin approves the withdrawal and adjusts the balance)
    final rider = await _fs.getRider();
    final balance = (rider?['wallet_balance'] as num?)?.toDouble() ?? 0;
    return {
      'wallet': {'balance': balance},
    };
  }

  Future<double> totalEarnings() => _fs.totalEarnings();

  /// Admin-configured minutes before the offline reminder fires.
  Future<int> offlineReminderMinutes() => _fs.offlineReminderMinutes();

  // ── Bank details ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> saveBankDetails({
    required String bankAccount,
    required String bankIfsc,
  }) async {
    final updates = <String, dynamic>{
      'bank_account_number': bankAccount,
      'bank_ifsc_code': bankIfsc,
    };
    await _fs.updateRider(updates);
    final rider = await _fs.getRider() ?? {};
    return Map<String, dynamic>.from({...rider, ...updates});
  }

  // ── Documents ─────────────────────────────────────────────────────────────

  /// Uploads a document image to Cloudinary and flags docs for re-approval.
  /// [docType]: 'aadhar_front' | 'aadhar_back' | 'license'
  Future<Map<String, dynamic>> saveDocument({
    required String docType,
    required XFile image,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final url = await CloudinaryService.instance.uploadFile(
      image.path,
      folder: 'rider_documents/$uid',
      publicId: docType,
    );

    const colMap = {
      'aadhar_front': 'aadhar_front_url',
      'aadhar_back': 'aadhar_back_url',
      'license': 'driving_license_image_url',
    };
    final col = colMap[docType]!;

    // Re-uploading a doc resets it to "pending" so the admin re-verifies it.
    // The rider acted, so clear any admin note (it's been answered).
    await _fs.updateRider({
      col: url,
      'is_document_verified': false,
      'document_status.$docType': 'pending',
      'admin_comment': FieldValue.delete(),
    });
    final rider = await _fs.getRider() ?? {};
    return Map<String, dynamic>.from(
        {...rider, col: url, 'is_document_verified': false});
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  /// Stages the rider's profile edits for admin approval instead of applying
  /// them live. Only fields that actually differ from the current (approved)
  /// value are queued into `pending_profile_changes`; the live rider doc — and
  /// therefore everything else in the app — keeps showing the current values
  /// until the admin approves the change. Reverting a field back to its live
  /// value drops it from the pending set.
  Future<Map<String, dynamic>> updateProfile({
    required Map<String, String> fields,
    XFile? photo,
  }) async {
    final rider = await _fs.getRider() ?? {};

    // Start from any edits already awaiting approval so an unrelated pending
    // change isn't lost when the rider edits a different field.
    final pending = <String, dynamic>{};
    final existing = rider['pending_profile_changes'];
    if (existing is Map) {
      pending.addAll(Map<String, dynamic>.from(existing));
    }

    fields.forEach((key, value) {
      final live = (rider[key] ?? '').toString();
      if (value == live) {
        pending.remove(key); // reverted to the approved value — no longer pending
      } else {
        pending[key] = value;
      }
    });

    if (photo != null) {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      // Upload under a distinct public id so the current (approved) photo is
      // untouched until the admin approves this new one.
      pending['profile_picture_url'] = await CloudinaryService.instance
          .uploadFile(photo.path,
              folder: 'profile_pictures', publicId: 'pending_$uid');
    }

    final updates = <String, dynamic>{};
    if (pending.isEmpty) {
      updates['pending_profile_changes'] = FieldValue.delete();
    } else {
      updates['pending_profile_changes'] = pending;
      updates['profile_change_requested_at'] = FieldValue.serverTimestamp();
    }
    // The rider acted on their profile — clear any admin note (it's answered).
    updates['admin_comment'] = FieldValue.delete();
    await _fs.updateRider(updates);

    // Return the (unchanged) live doc plus the pending set so the UI can show
    // the "awaiting approval" badges.
    return await _fs.getRider() ?? {};
  }

  // ── Auth helper ───────────────────────────────────────────────────────────

  /// Returns the Firebase ID token (used nowhere in the Firebase flow, but
  /// the WebSocket service reads this key — it skips connection when null).
  Future<String?> getAccessToken() async {
    final user = FirebaseAuth.instance.currentUser;
    return user?.getIdToken();
  }
}
