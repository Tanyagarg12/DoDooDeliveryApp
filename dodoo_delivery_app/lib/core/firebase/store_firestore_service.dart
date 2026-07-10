import 'package:cloud_firestore/cloud_firestore.dart';

import '../session/store_session.dart';
import 'firebase_refs.dart';

/// Firestore access for the store/merchant app. Stores live in `stores/{uid}`
/// where uid is the owner's phone number (see [StoreSession]).
class StoreFirestoreService {
  StoreFirestoreService._();
  static final StoreFirestoreService instance = StoreFirestoreService._();

  /// The logged-in store's doc id (their phone number).
  String get currentUid => StoreSession.storeId ?? '';

  Future<Map<String, dynamic>?> getStore([String? uid]) async {
    final doc = await Db.stores.doc(uid ?? currentUid).get();
    if (!doc.exists) return null;
    return _toMap(doc);
  }

  /// Creates (or re-submits) a store. Always forces the safe defaults so a
  /// client can't self-register as an already-approved / verified store.
  Future<void> createStore(String uid, Map<String, dynamic> data) async {
    await Db.stores.doc(uid).set({
      ...data,
      'account_status': 'pending',
      'current_status': 'closed',
      'is_verified': false,
      'is_document_verified': false,
      'rating': 5.0,
      'total_orders': 0,
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateStore(Map<String, dynamic> fields, [String? uid]) async {
    await Db.stores.doc(uid ?? currentUid).update(fields);
  }

  /// Reads just the account status (used by the status screen's refresh).
  Future<String> fetchAccountStatus() async {
    final store = await getStore();
    return store?['account_status']?.toString() ?? 'pending';
  }

  Map<String, dynamic> _toMap(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map? ?? {});
    data['id'] = doc.id;
    for (final key in data.keys.toList()) {
      final v = data[key];
      if (v is Timestamp) data[key] = v.toDate().toIso8601String();
    }
    return data;
  }
}
