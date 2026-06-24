import 'package:cloud_firestore/cloud_firestore.dart';

import '../session/rider_session.dart';

/// Central Firestore service — all collections live here.
///
/// Firestore collections:
///   riders/{uid}                 – rider profile
///   orders/{orderId}             – delivery orders
///   order_offers/{offerId}       – per-rider offer records
///   rider_tracking/{uid}         – latest live location
///   withdrawal_requests/{reqId}  – payout requests
///   wallet_transactions/{txId}   – credit/debit log
class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference get _riders => _db.collection('riders');
  CollectionReference get _orders => _db.collection('orders');
  CollectionReference get _offers => _db.collection('order_offers');
  CollectionReference get _tracking => _db.collection('rider_tracking');
  CollectionReference get _withdrawals => _db.collection('withdrawal_requests');
  CollectionReference get _walletTxns => _db.collection('wallet_transactions');

  /// The logged-in rider's doc id (their phone number). Set at OTP verification.
  String get currentUid => RiderSession.riderId ?? '';

  // ── Rider ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getRider([String? uid]) async {
    final doc = await _riders.doc(uid ?? currentUid).get();
    if (!doc.exists) return null;
    return _toMap(doc);
  }

  Future<Map<String, dynamic>?> findRiderByPhone(String phone) async {
    final snap = await _riders
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return _toMap(snap.docs.first);
  }

  Future<void> createRider(String uid, Map<String, dynamic> data) async {
    await _riders.doc(uid).set({
      ...data,
      'account_status': 'pending',
      'current_status': 'offline',
      'is_verified': false,
      'is_document_verified': false,
      'wallet_balance': 0,
      'total_orders': 0,
      'rating': 5.0,
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateRider(Map<String, dynamic> fields, [String? uid]) async {
    await _riders.doc(uid ?? currentUid).update(fields);
  }

  // ── Dashboard composite read ───────────────────────────────────────────────

  Future<Map<String, dynamic>> dashboard() async {
    final uid = currentUid;

    final results = await Future.wait([
      _riders.doc(uid).get(),
      _orders
          .where('assigned_rider_id', isEqualTo: uid)
          .where('status', whereIn: ['accepted', 'picked_up', 'in_transit', 'reached'])
          .orderBy('created_at', descending: true)
          .get(),
      _orders
          .where('assigned_rider_id', isEqualTo: uid)
          .where('status', whereIn: ['completed', 'cancelled'])
          .orderBy('created_at', descending: true)
          .limit(30)
          .get(),
      _offers
          .where('rider_id', isEqualTo: uid)
          .where('is_accepted', isEqualTo: false)
          .where('is_rejected', isEqualTo: false)
          .get(),
      _withdrawals
          .where('rider_id', isEqualTo: uid)
          .orderBy('created_at', descending: true)
          .limit(10)
          .get(),
    ]);

    final riderDoc = results[0] as DocumentSnapshot;
    final activeSnap = results[1] as QuerySnapshot;
    final historySnap = results[2] as QuerySnapshot;
    final offersSnap = results[3] as QuerySnapshot;
    final withdrawalSnap = results[4] as QuerySnapshot;

    final rider = riderDoc.exists ? _toMap(riderDoc) : <String, dynamic>{'id': uid};

    // Build pending offers — fetch order for each offer, filter by pending
    final pendingOffers = <Map<String, dynamic>>[];
    final seenOrderIds = <String>{};
    await Future.wait(offersSnap.docs.map((offerDoc) async {
      final offerData = _toMap(offerDoc);
      final orderId = offerData['order_id'] as String?;
      if (orderId == null) return;
      final orderDoc = await _orders.doc(orderId).get();
      if (!orderDoc.exists) return;
      final orderData = _toMap(orderDoc);
      if (orderData['status'] != 'pending') return;
      seenOrderIds.add(orderId);
      pendingOffers.add({...offerData, 'order': orderData});
    }));

    // Also surface ANY unassigned pending order — even one that was never
    // broadcast to this rider (e.g. imported before they registered). This is
    // why a pending/"unassigned" order in the admin must still appear here.
    // Orders this rider already rejected are excluded.
    try {
      final results2 = await Future.wait([
        _orders.where('status', isEqualTo: 'pending').limit(50).get(),
        _offers
            .where('rider_id', isEqualTo: uid)
            .where('is_rejected', isEqualTo: true)
            .get(),
      ]);
      final openSnap = results2[0] as QuerySnapshot;
      final rejectedSnap = results2[1] as QuerySnapshot;
      final rejectedOrderIds = rejectedSnap.docs
          .map((d) => _toMap(d)['order_id']?.toString())
          .whereType<String>()
          .toSet();

      for (final doc in openSnap.docs) {
        final order = _toMap(doc);
        final oid = order['id'].toString();
        if (seenOrderIds.contains(oid)) continue; // already have an offer
        if (rejectedOrderIds.contains(oid)) continue; // rider passed on it
        final assigned = order['assigned_rider_id']?.toString() ?? '';
        if (assigned.isNotEmpty) continue; // already taken
        seenOrderIds.add(oid);
        pendingOffers.add({
          'id': 'open_$oid',
          'order_id': oid,
          'rider_id': uid,
          'is_accepted': false,
          'is_rejected': false,
          'order': order,
        });
      }
    } catch (_) {/* best-effort — offer-based list still works */}

    // Earnings summary
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = now.subtract(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month, 1);

    double todayE = 0, weekE = 0, monthE = 0;
    int completedCount = 0;
    for (final doc in historySnap.docs) {
      final d = _toMap(doc);
      if (d['status'] != 'completed') continue;
      completedCount++;
      final amt = _toDouble(d['total_earning']);
      final at = _parseDate(d['completed_at']);
      if (at == null) continue;
      if (!at.isBefore(monthStart)) monthE += amt;
      if (!at.isBefore(weekStart)) weekE += amt;
      if (!at.isBefore(todayStart)) todayE += amt;
    }

    return {
      'rider': rider,
      'active_orders': activeSnap.docs.map(_toMap).toList(),
      'order_history': historySnap.docs.map(_toMap).toList(),
      'pending_offers': pendingOffers,
      'earnings_summary': {
        'today': todayE,
        'week': weekE,
        'month': monthE,
        'completed_orders': completedCount,
      },
      'wallet': {'balance': rider['wallet_balance'] ?? 0},
      'withdrawal_requests': withdrawalSnap.docs.map(_toMap).toList(),
    };
  }

  // ── Order operations ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> acceptOrder(String orderId) async {
    final uid = currentUid;
    final orderRef = _orders.doc(orderId);

    return _db.runTransaction<Map<String, dynamic>>((txn) async {
      final orderDoc = await txn.get(orderRef);
      if (!orderDoc.exists) throw Exception('Order not found');
      final orderData = _toMap(orderDoc);
      if (orderData['status'] != 'pending') {
        throw Exception('Order is no longer available');
      }

      txn.update(orderRef, {
        'status': 'accepted',
        'assigned_rider_id': uid,
        'accepted_at': FieldValue.serverTimestamp(),
        'status_updated_at': FieldValue.serverTimestamp(),
      });

      // Update rider status to busy
      txn.update(_riders.doc(uid), {'current_status': 'busy'});

      return {...orderData, 'status': 'accepted', 'assigned_rider_id': uid};
    });
  }

  Future<void> rejectOrder(String orderId) async {
    final uid = currentUid;
    final offerSnap = await _offers
        .where('order_id', isEqualTo: orderId)
        .where('rider_id', isEqualTo: uid)
        .limit(1)
        .get();

    if (offerSnap.docs.isNotEmpty) {
      await _offers.doc(offerSnap.docs.first.id).update({
        'is_rejected': true,
        'rejected_at': FieldValue.serverTimestamp(),
      });
    } else {
      await _offers.add({
        'order_id': orderId,
        'rider_id': uid,
        'is_accepted': false,
        'is_rejected': true,
        'notified_at': FieldValue.serverTimestamp(),
        'rejected_at': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<Map<String, dynamic>> updateOrderStatus(String orderId, String status) async {
    final uid = currentUid;
    final updates = <String, dynamic>{
      'status': status,
      'status_updated_at': FieldValue.serverTimestamp(),
    };
    if (status == 'picked_up') updates['picked_up_at'] = FieldValue.serverTimestamp();
    if (status == 'completed') {
      updates['completed_at'] = FieldValue.serverTimestamp();
      await _creditRider(orderId, uid);
      await _riders.doc(uid).update({
        'current_status': 'online',
        'total_orders': FieldValue.increment(1),
      });
    }
    await _orders.doc(orderId).update(updates);
    final doc = await _orders.doc(orderId).get();
    return _toMap(doc);
  }

  Future<void> _creditRider(String orderId, String uid) async {
    final orderDoc = await _orders.doc(orderId).get();
    if (!orderDoc.exists) return;
    final orderData = _toMap(orderDoc);
    final amount = _toDouble(orderData['total_earning']);
    if (amount <= 0) return;

    final batch = _db.batch();
    batch.update(_riders.doc(uid), {'wallet_balance': FieldValue.increment(amount)});
    batch.set(_walletTxns.doc(), {
      'rider_id': uid,
      'order_id': orderId,
      'type': 'credit',
      'amount': amount,
      'description': 'Order ${orderData['order_number'] ?? ''} completed',
      'created_at': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  // ── History ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> history(String filter) async {
    final uid = currentUid;
    final now = DateTime.now();
    final start = switch (filter) {
      'today' => Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
      'month' => Timestamp.fromDate(DateTime(now.year, now.month, 1)),
      _ => Timestamp.fromDate(now.subtract(const Duration(days: 7))),
    };

    final results = await Future.wait([
      _orders
          .where('assigned_rider_id', isEqualTo: uid)
          .where('status', whereIn: ['completed', 'cancelled'])
          .where('created_at', isGreaterThanOrEqualTo: start)
          .orderBy('created_at', descending: true)
          .get(),
      _offers
          .where('rider_id', isEqualTo: uid)
          .where('is_rejected', isEqualTo: true)
          .where('notified_at', isGreaterThanOrEqualTo: start)
          .orderBy('notified_at', descending: true)
          .get(),
    ]);

    final completedSnap = results[0] as QuerySnapshot;
    final rejectedSnap = results[1] as QuerySnapshot;

    final accepted = completedSnap.docs.map(_toMap).toList();
    double totalEarnings = 0;
    int totalCompleted = 0;
    for (final o in accepted) {
      if (o['status'] == 'completed') {
        totalCompleted++;
        totalEarnings += _toDouble(o['total_earning']);
      }
    }

    // Build rejected list with embedded order data
    final rejected = <Map<String, dynamic>>[];
    await Future.wait(rejectedSnap.docs.map((offerDoc) async {
      final offerData = _toMap(offerDoc);
      final orderId = offerData['order_id'] as String?;
      if (orderId == null) return;
      final orderDoc = await _orders.doc(orderId).get();
      if (!orderDoc.exists) return;
      rejected.add({...offerData, 'order': _toMap(orderDoc)});
    }));

    return {
      'accepted': accepted,
      'rejected': rejected,
      'summary': {
        'total_completed': totalCompleted,
        'total_earnings': totalEarnings.toString(),
        'total_rejected': rejected.length,
      },
    };
  }

  // ── Tracking ───────────────────────────────────────────────────────────────

  Future<void> updateTracking({
    required double lat,
    required double lng,
    required double accuracy,
    required double speed,
    required double bearing,
    String? orderId,
  }) async {
    await _tracking.doc(currentUid).set({
      'latitude': lat,
      'longitude': lng,
      'accuracy': accuracy,
      'speed': speed,
      'bearing': bearing,
      if (orderId != null) 'order_id': orderId,
      'updated_at': FieldValue.serverTimestamp(),
      'is_tracking': true,
    }, SetOptions(merge: true));
  }

  /// Marks the rider as no longer broadcasting their location.
  Future<void> stopTracking() async {
    await _tracking.doc(currentUid).set(
      {'is_tracking': false, 'updated_at': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  // ── Withdrawals ────────────────────────────────────────────────────────────

  Future<void> requestWithdrawal({
    required double amount,
    required String bankAccount,
    required String bankIfsc,
    String? accountHolderName,
    String? bankName,
  }) async {
    await _withdrawals.add({
      'rider_id': currentUid,
      'amount': amount,
      'bank_account': bankAccount,
      'bank_ifsc': bankIfsc,
      if (accountHolderName != null) 'account_holder_name': accountHolderName,
      if (bankName != null) 'bank_name': bankName,
      'status': 'pending',
      'is_auto': false,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  // ── Earnings & settings ─────────────────────────────────────────────────────

  /// Lifetime earnings — sum of total_earning across this rider's completed
  /// orders (mirrors the Supabase implementation).
  Future<double> totalEarnings() async {
    final snap = await _orders
        .where('assigned_rider_id', isEqualTo: currentUid)
        .where('status', isEqualTo: 'completed')
        .get();
    double sum = 0;
    for (final d in snap.docs) {
      sum += _toDouble(_toMap(d)['total_earning']);
    }
    return sum;
  }

  /// Admin-configured minutes before the offline reminder fires.
  /// Stored at app_settings/offline_reminder_minutes { value: "<int>" }.
  Future<int> offlineReminderMinutes() async {
    try {
      final doc =
          await _db.collection('app_settings').doc('offline_reminder_minutes').get();
      final v = doc.data()?['value'];
      return int.tryParse(v?.toString() ?? '') ?? 15;
    } catch (_) {
      return 15;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _toMap(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map? ?? {});
    data['id'] = doc.id;
    // Convert Timestamps to ISO strings so the UI can parse them
    for (final key in data.keys.toList()) {
      if (data[key] is Timestamp) {
        data[key] = (data[key] as Timestamp).toDate().toIso8601String();
      }
    }
    return data;
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v is String) return DateTime.tryParse(v);
    if (v is Timestamp) return v.toDate();
    return null;
  }
}
