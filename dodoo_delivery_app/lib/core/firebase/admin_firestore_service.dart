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

  /// LIVE stream of the most-recent orders (newest first). The admin list
  /// subscribes to this so a rider's status change (accepted → picked_up →
  /// delivered, etc.) shows up automatically, without a manual refresh.
  Stream<List<Map<String, dynamic>>> recentOrdersStream({int limit = 200}) {
    return Db.orders
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(_map).toList());
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

  /// Maps each approved store's DoDoo Store ID → its Firestore store id, so the
  /// order sync can route DoDoo store orders to the matching registered store.
  /// Only stores with a non-empty `dodoo_store_id` are included.
  Future<Map<String, String>> approvedStoresByDodooId() async {
    final snap =
        await Db.stores.where('account_status', isEqualTo: 'approved').get();
    final out = <String, String>{};
    for (final d in snap.docs) {
      final ext = (d.data()['dodoo_store_id']?.toString() ?? '').trim();
      if (ext.isNotEmpty) out[ext] = d.id;
    }
    return out;
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

  /// Existing orders keyed by order_number → {id, status, assigned_rider_id}.
  /// Used to re-sync each order's status from DoDoo on every sync.
  Future<Map<String, Map<String, dynamic>>> existingOrdersByNumber(
      List<String> orderNumbers) async {
    final out = <String, Map<String, dynamic>>{};
    for (var i = 0; i < orderNumbers.length; i += 10) {
      final end = (i + 10) > orderNumbers.length ? orderNumbers.length : i + 10;
      final chunk = orderNumbers.sublist(i, end);
      if (chunk.isEmpty) continue;
      final snap = await Db.orders.where('order_number', whereIn: chunk).get();
      for (final d in snap.docs) {
        final m = _map(d);
        final on = m['order_number']?.toString();
        if (on != null) out[on] = m;
      }
    }
    return out;
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
    final data = {...orderData};
    // Keep the real order time (set from the DoDoo OrderDate) for sorting;
    // only fall back to the server clock when the order carries no date.
    data['created_at'] = data['created_at'] ?? FieldValue.serverTimestamp();
    // First (immediate) broadcast — track count + time so the auto re-broadcast
    // schedule (2 min, 5 min, then stop) can run off it.
    if (riderIds.isNotEmpty) {
      data['broadcast_count'] = 1;
      data['first_broadcast_at'] = FieldValue.serverTimestamp();
    }
    final ref = await Db.orders.add(data);
    await _broadcast(ref.id, riderIds);
  }

  /// Auto re-broadcast schedule for pending, unassigned orders:
  ///   broadcast #1 = on import (immediate), #2 = 2 min later, #3 = 5 min later.
  /// After 3 broadcasts it STOPS — the admin can still re-broadcast manually.
  /// Returns how many orders were re-broadcast this run.
  Future<int> runScheduledRebroadcasts(List<String> riderIds) async {
    if (riderIds.isEmpty) return 0;
    final snap = await Db.orders.where('status', isEqualTo: 'pending').get();
    final now = DateTime.now();
    var count = 0;
    for (final d in snap.docs) {
      final m = _map(d);
      if ((m['assigned_rider_id']?.toString() ?? '').trim().isNotEmpty) continue;
      final bc = (m['broadcast_count'] as num?)?.toInt() ?? 1;
      if (bc >= 3) continue; // schedule exhausted — manual only from here
      final first =
          _parseDate(m['first_broadcast_at']) ?? _parseDate(m['created_at']);
      if (first == null) continue;
      final elapsed = now.difference(first);
      final due = (bc == 1 && elapsed >= const Duration(minutes: 2)) ||
          (bc == 2 && elapsed >= const Duration(minutes: 5));
      if (!due) continue;

      // Clear old offers and re-offer to all approved riders, bump the count.
      final existing =
          await Db.orderOffers.where('order_id', isEqualTo: d.id).get();
      final batch = _db.batch();
      for (final o in existing.docs) {
        batch.delete(o.reference);
      }
      await batch.commit();
      await _broadcast(d.id, riderIds);
      await d.reference.update({
        'broadcast_count': bc + 1,
        'status_updated_at': FieldValue.serverTimestamp(),
      });
      count++;
    }
    return count;
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

  /// Flat base fare added to every (store) order's rider earning. Default 0.
  Future<double> riderBaseFare() async {
    final v = await getSetting('rider_base_fare');
    return double.tryParse(v ?? '') ?? 0.0;
  }

  /// Minimum rider earning for a store order (a floor under base + km×rate).
  /// Admin-configurable; defaults to ₹42.
  Future<double> minDeliveryCharge() async {
    final v = await getSetting('min_delivery_charge');
    return double.tryParse(v ?? '') ?? 42.0;
  }

  /// Flat rider earning for a Pick & Drop (PDP) order. Admin-configurable;
  /// defaults to ₹60.
  Future<double> pickDropCharge() async {
    final v = await getSetting('pickdrop_charge');
    return double.tryParse(v ?? '') ?? 60.0;
  }

  /// Recomputes total_earning using the current rules:
  ///   PDP   → flat [pdpCharge]
  ///   store → max(baseFare + distance_km × city rate, [minFare])
  ///
  /// ONLY recomputes **pending (ongoing)** orders — so a settings change is
  /// reflected on ongoing + new orders, but an order a rider has already
  /// accepted keeps its earning LOCKED (accepted / in-progress / completed /
  /// cancelled are never re-priced).
  Future<void> recomputeEarnings({
    required double baseFare,
    required double minFare,
    required double pdpCharge,
    required Map<String, double> ratesByCity,
    required double defaultRate,
  }) async {
    final snap = await Db.orders.where('status', isEqualTo: 'pending').get();
    for (final d in snap.docs) {
      final m = d.data();
      // Don't re-price an order a rider already took.
      if ((m['assigned_rider_id']?.toString() ?? '').trim().isNotEmpty) continue;

      final on = (m['order_number'] ?? '').toString().toUpperCase();
      final otype = (m['order_type'] ?? '').toString().toLowerCase();
      final isPdp = on.contains('PDP') || otype.contains('pick');
      final km = (m['distance_in_km'] as num?)?.toDouble() ?? 2.0;
      final rate = ratesByCity[(m['city_code'] ?? '').toString()] ?? defaultRate;

      double earn;
      if (isPdp) {
        earn = pdpCharge;
      } else {
        final calc = baseFare + km * rate;
        earn = calc < minFare ? minFare : calc;
      }
      earn = double.parse(earn.toStringAsFixed(2));

      final cur = (m['total_earning'] as num?)?.toDouble();
      if (cur == null || (cur - earn).abs() > 0.01 || m['per_km_rate'] == null) {
        await d.reference.update({
          'total_earning': earn,
          'minimum_fare': earn,
          'per_km_rate': isPdp ? 0 : rate,
          'base_fare': isPdp ? 0 : baseFare,
          'min_fare': isPdp ? 0 : minFare,
        });
      }
    }
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
