import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/dodoo_categories.dart';
import '../../../core/constants/dodoo_cities.dart';
import '../../../core/firebase/firebase_refs.dart';
import '../../orders_api/data/dodoo_store_api.dart';

/// Outcome of a single publish attempt.
class DodooPublishOutcome {
  const DodooPublishOutcome({
    required this.ok,
    required this.unreachable,
    this.dodooId,
    this.message,
  });

  /// Store was saved on DoDoo.
  final bool ok;

  /// Failed only because the DoDoo store server couldn't be reached — the
  /// store is queued (`dodoo_publish_pending`) for automatic retry.
  final bool unreachable;

  /// The linked DoDoo Store ID, if one was fetched.
  final String? dodooId;

  /// Human-readable failure reason (when [ok] is false).
  final String? message;
}

/// Publishes an approved store to the DoDoo marketplace (SaveStore) and links
/// its DoDoo Store ID. Shared by the admin store-detail "Publish" button and
/// the Stores-tab background auto-retry sweep so both behave identically.
///
/// Contract:
///  - success  → writes `dodoo_store_id` (if fetched) and clears
///    `dodoo_publish_pending`.
///  - unreachable server → sets `dodoo_publish_pending: true` so the sweep can
///    retry later (only writes the flag if it wasn't already set).
///  - other failure → returns the message; no queueing (retrying won't help).
class DodooStorePublisher {
  DodooStorePublisher._();

  static Future<DodooPublishOutcome> publish({
    required String storeId,
    required Map<String, dynamic> store,
    DodooStoreApi? api,
  }) async {
    final client = api ?? DodooStoreApi();
    final storeName = (store['store_name']?.toString() ?? '').trim();
    final mobile = store['phone']?.toString() ?? storeId;
    if (storeName.isEmpty) {
      return const DodooPublishOutcome(
          ok: false, unreachable: false, message: 'Store has no name yet.');
    }
    final existingId = (store['dodoo_store_id']?.toString() ?? '').trim();

    final res = await client.saveStore(
      id: existingId.isEmpty ? '0' : existingId,
      storeName: storeName,
      address: store['address']?.toString() ?? '',
      city: DodooCities.nameFor(store['city_code']?.toString()),
      categoryId: DodooCategories.forStoreKey(store['category']?.toString()),
      mobile: mobile,
      email: store['email']?.toString() ?? '',
    );

    if (!res.ok) {
      if (res.unreachable && store['dodoo_publish_pending'] != true) {
        await _setPending(storeId, true);
      }
      return DodooPublishOutcome(
          ok: false, unreachable: res.unreachable, message: res.message);
    }

    // SaveStore doesn't echo the new id → look it up by mobile.
    var newId = existingId;
    if (newId.isEmpty && mobile.isNotEmpty) {
      final profile = await client.storeAdminAuthentication(mobile: mobile);
      final fetched = profile?['id']?.toString() ?? '';
      if (fetched.isNotEmpty) newId = fetched;
    }

    // Success → persist id (if any) and clear the pending flag.
    final update = <String, dynamic>{'dodoo_publish_pending': false};
    if (newId.isNotEmpty) update['dodoo_store_id'] = newId;
    await Db.stores.doc(storeId).set(update, SetOptions(merge: true));

    return DodooPublishOutcome(
      ok: true,
      unreachable: false,
      dodooId: newId.isEmpty ? null : newId,
    );
  }

  static Future<void> _setPending(String storeId, bool pending) async {
    try {
      await Db.stores
          .doc(storeId)
          .set({'dodoo_publish_pending': pending}, SetOptions(merge: true));
    } catch (_) {}
  }
}
