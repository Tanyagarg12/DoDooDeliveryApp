import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_refs.dart';

/// Firestore operations used by the admin portal (orders tab + order detail).
/// Mirrors what the admin screens previously did against Supabase.
class AdminFirestoreService {
  AdminFirestoreService._();
  static final AdminFirestoreService instance = AdminFirestoreService._();

  final _db = FirebaseFirestore.instance;

  // ── Reads ──────────────────────────────────────────────────────────────────

  /// Most-recent orders (newest first).
  Future<List<Map<String, dynamic>>> recentOrders({int limit = 200}) async {
    final snap =
        await Db.orders.orderBy('created_at', descending: true).limit(limit).get();
    return snap.docs.map(_map).toList();
  }

  /// rider_id → display name, for every rider.
  Future<Map<String, String>> riderNames() async {
    final snap = await Db.riders.get();
    final out = <String, String>{};
    for (final d in snap.docs) {
      final r = d.data();
      final name = '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim();
      out[d.id] = name.isEmpty ? 'Rider' : name;
    }
    return out;
  }

  /// Document ids of all approved riders.
  Future<List<String>> approvedRiderIds() async {
    final snap =
        await Db.riders.where('account_status', isEqualTo: 'approved').get();
    return snap.docs.map((d) => d.id).toList();
  }

  /// All riders (id, name, phone, account_status) for the reassign picker.
  Future<List<Map<String, dynamic>>> ridersForPicker() async {
    final snap = await Db.riders.get();
    return snap.docs.map(_map).toList();
  }

  Future<Map<String, dynamic>?> getOrder(String orderId) async {
    final doc = await Db.orders.doc(orderId).get();
    return doc.exists ? _map(doc) : null;
  }

  /// Which of [orderNumbers] already exist in Firestore (chunked for whereIn).
  Future<Set<String>> existingOrderNumbers(List<String> orderNumbers) async {
    final found = <String>{};
    for (var i = 0; i < orderNumbers.length; i += 10) {
      final end = (i + 10) > orderNumbers.length ? orderNumbers.length : i + 10;
      final chunk = orderNumbers.sublist(i, end);
      if (chunk.isEmpty) continue;
      final snap = await Db.orders.where('order_number', whereIn: chunk).get();
      for (final d in snap.docs) {
        final on = d.data()['order_number']?.toString();
        if (on != null) found.add(on);
      }
    }
    return found;
  }

  /// Pending, unassigned orders whose status_updated_at is older than [cutoff].
  Future<List<Map<String, dynamic>>> staleUnpickedOrders(DateTime cutoff) async {
    final snap = await Db.orders.where('status', isEqualTo: 'pending').get();
    final out = <Map<String, dynamic>>[];
    for (final d in snap.docs) {
      final r = _map(d);
      if (r['assigned_rider_id'] != null) continue;
      final ts = _parseDate(d.data()['status_updated_at']);
      if (ts == null || ts.isBefore(cutoff)) out.add(r);
    }
    return out;
  }

  // ── Writes ───────────────────────────────────────────────────────────────

  /// Inserts an order and broadcasts an offer to every approved rider.
  Future<void> insertOrderWithOffers(
    Map<String, dynamic> orderData,
    List<String> riderIds,
  ) async {
    final ref = await Db.orders.add({
      ...orderData,
      'created_at': FieldValue.serverTimestamp(),
    });
    await _broadcast(ref.id, riderIds);
  }

  Future<void> updateOrder(String orderId, Map<String, dynamic> patch) async {
    await Db.orders.doc(orderId).update({
      ...patch,
      'status_updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Re-broadcast: clear existing offers, reset to pending+unassigned, re-offer.
  Future<void> rebroadcast(String orderId, List<String> riderIds) async {
    final existing =
        await Db.orderOffers.where('order_id', isEqualTo: orderId).get();
    final batch = _db.batch();
    for (final d in existing.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
    await _broadcast(orderId, riderIds);
    await Db.orders.doc(orderId).update({
      'status_updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Just re-send offers (used by the unpicked watcher) + bump the timestamp.
  Future<void> reofferStale(String orderId, List<String> riderIds) async {
    final existing =
        await Db.orderOffers.where('order_id', isEqualTo: orderId).get();
    final batch = _db.batch();
    for (final d in existing.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
    await _broadcast(orderId, riderIds);
    await Db.orders.doc(orderId).update({
      'status_updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _broadcast(String orderId, List<String> riderIds) async {
    if (riderIds.isEmpty) return;
    final batch = _db.batch();
    for (final rid in riderIds) {
      batch.set(Db.orderOffers.doc(), {
        'order_id': orderId,
        'rider_id': rid,
        'is_accepted': false,
        'is_rejected': false,
        'notified_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Pull-sync: cancels our still-**pending** orders (in the synced cities)
  /// that DoDoo no longer lists as open — i.e. DoDoo cancelled/closed them.
  /// Only touches `pending` orders, so a rider's in-progress delivery is never
  /// affected. Returns how many were cancelled.
  Future<int> cancelMissingPending(
    Set<String> openOrderNumbers,
    Set<String> cityCodes,
  ) async {
    final snap = await Db.orders.where('status', isEqualTo: 'pending').get();
    var count = 0;
    for (final d in snap.docs) {
      final m = d.data();
      final city = m['city_code']?.toString() ?? '';
      if (!cityCodes.contains(city)) continue; // only reconcile synced cities
      final on = m['order_number']?.toString() ?? '';
      if (on.isEmpty || openOrderNumbers.contains(on)) continue;
      await d.reference.update({
        'status': 'cancelled',
        'status_updated_at': FieldValue.serverTimestamp(),
      });
      count++;
    }
    return count;
  }

  // ── App settings ─────────────────────────────────────────────────────────
  // Stored as app_settings/{key} { value: "<string>" }.

  Future<String?> getSetting(String key) async {
    final doc = await Db.appSettings.doc(key).get();
    return doc.data()?['value']?.toString();
  }

  Future<void> setSetting(String key, String value) async {
    await Db.appSettings.doc(key).set({'value': value}, SetOptions(merge: true));
  }

  /// Admin-configured delivery rate per km — per city, falling back to the
  /// global rate, then 8. Stored at app_settings/price_per_km_<CITY>.
  Future<double> pricePerKm({String? cityCode}) async {
    if (cityCode != null && cityCode.isNotEmpty) {
      final v = await getSetting('price_per_km_$cityCode');
      if (v != null && v.isNotEmpty) return double.tryParse(v) ?? 8.0;
    }
    final g = await getSetting('price_per_km');
    return double.tryParse(g ?? '') ?? 8.0;
  }

  /// Minutes a rider can stay offline before the reminder fires. Defaults to 15.
  Future<int> offlineReminderMinutes() async {
    final v = await getSetting('offline_reminder_minutes');
    return int.tryParse(v ?? '') ?? 15;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _map(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map? ?? {});
    data['id'] = doc.id;
    for (final key in data.keys.toList()) {
      if (data[key] is Timestamp) {
        data[key] = (data[key] as Timestamp).toDate().toIso8601String();
      }
    }
    return data;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
