import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../features/orders_api/data/dodoo_order_api.dart';
import '../../features/orders_api/data/models/dodoo_order.dart';
import 'firebase_refs.dart';
import 'store_wallet_service.dart';

/// The store-side order lifecycle. DoDoo orders use statuses:
/// open (new) → accept (accepted) → inprogress → deliver (completed) or cancel.
class StoreOrderStatus {
  StoreOrderStatus._();

  // Legacy Model B statuses (kept for backwards compatibility)
  static const placed = 'placed'; // awaiting the store to accept
  static const preparing = 'preparing'; // store accepted, preparing
  static const pending = 'pending'; // ready, offered to riders
  static const accepted = 'accepted'; // a rider accepted
  static const pickedUp = 'picked_up';
  static const completed = 'completed';
  static const cancelled = 'cancelled';

  /// Store-facing label for any order status (DoDoo or Legacy).
  static String label(String? status) {
    final s = status?.toLowerCase() ?? '';
    // DoDoo statuses
    if (s == 'open') return 'New';
    if (s == 'accept') return 'Accepted';
    if (s == 'inprogress') return 'In Progress';
    if (s == 'deliver') return 'Delivered';
    if (s == 'cancel') return 'Cancelled';
    // Legacy Model B statuses
    switch (status) {
      case placed:
        return 'New';
      case preparing:
        return 'Preparing';
      case pending:
        return 'Ready · finding rider';
      case accepted:
        return 'Rider assigned';
      case pickedUp:
      case 'in_transit':
      case 'reached':
        return 'Out for delivery';
      case completed:
        return 'Delivered';
      case cancelled:
        return 'Cancelled';
      default:
        return status ?? '';
    }
  }

  static Color color(String? status) {
    final s = status?.toLowerCase() ?? '';
    // DoDoo statuses
    if (s == 'open') return const Color(0xFFD97706); // amber
    if (s == 'accept') return const Color(0xFF7C3AED); // purple
    if (s == 'inprogress') return const Color(0xFF2563EB); // blue
    if (s == 'deliver') return const Color(0xFF059669); // green
    if (s == 'cancel') return const Color(0xFFDC2626); // red
    // Legacy Model B statuses
    switch (status) {
      case placed:
        return const Color(0xFFD97706); // amber — needs action
      case preparing:
        return const Color(0xFF7C3AED); // purple
      case pending:
        return const Color(0xFF2563EB); // blue — waiting for rider
      case accepted:
      case pickedUp:
      case 'in_transit':
      case 'reached':
        return const Color(0xFF0EA5E9);
      case completed:
        return const Color(0xFF059669);
      case cancelled:
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  /// Active (open) statuses the store still has a hand in / is tracking.
  static const activeStatuses = [
    placed,
    preparing,
    pending,
    accepted,
    pickedUp,
    'in_transit',
    'reached',
    'open',
    'accept',
    'inprogress',
  ];

  static bool isActive(String? s) {
    if (s == null) return false;
    return activeStatuses.contains(s) ||
        activeStatuses.contains(s.toLowerCase());
  }

  static bool isFinished(String? s) {
    if (s == null) return false;
    final lower = s.toLowerCase();
    return lower == completed ||
        lower == cancelled ||
        lower == 'deliver' ||
        lower == 'cancel';
  }
}

class StoreOrderService {
  StoreOrderService._();
  static final StoreOrderService instance = StoreOrderService._();

  final _db = FirebaseFirestore.instance;
  late final _dodooApi = DodooOrderApi();

  /// Live stream of this store's orders from DoDoo API (newest first).
  /// Polls DoDoo API every 2 minutes for auto-refresh + manual refresh support.
  Stream<List<Map<String, dynamic>>> streamOrdersFromDodoo(String storeId) async* {
    // Fetch once immediately
    try {
      final orders = await _dodooApi.getStoreOrders(storeId);
      yield _dodooOrdersToMaps(orders);
    } catch (_) {
      yield [];
    }

    // Then poll every 2 minutes
    while (true) {
      await Future.delayed(const Duration(minutes: 2));
      try {
        final orders = await _dodooApi.getStoreOrders(storeId);
        yield _dodooOrdersToMaps(orders);
      } catch (_) {
        yield [];
      }
    }
  }

  /// Manual fetch from DoDoo API (for refresh button).
  Future<List<Map<String, dynamic>>> fetchStoreOrdersFromDodoo(
      String storeId) async {
    try {
      final orders = await _dodooApi.getStoreOrders(storeId);
      return _dodooOrdersToMaps(orders);
    } catch (_) {
      return [];
    }
  }

  /// Convert DodooOrder list to Map format for UI consumption.
  List<Map<String, dynamic>> _dodooOrdersToMaps(List<DodooOrder> orders) {
    return orders
        .map((o) => {
              'id': o.orderId,
              'order_number': o.orderId,
              'store_id': o.storeId,
              'store_name': o.storeName,
              'customer_name': o.name ?? '—',
              'customer_phone': o.contactNo ?? '—',
              'to_address': o.dropAddress ?? '—',
              'items_summary': o.desc ?? '',
              'order_amount': o.price,
              'store_earning': o.price,
              'total_earning': o.deliveryCharge,
              'status': o.status?.toLowerCase() ?? 'unknown',
              'created_at': o.orderDate ?? '',
              'order_type': o.orderType,
              'raw': o.raw,
            })
        .toList()
      ..sort((a, b) => (b['created_at']?.toString() ?? '')
          .compareTo(a['created_at']?.toString() ?? ''));
  }

  /// Live stream of this store's orders (newest first, sorted client-side to
  /// avoid a composite index). [DEPRECATED: Use streamOrdersFromDodoo instead]
  Stream<List<Map<String, dynamic>>> streamOrders(String storeId) {
    return Db.orders
        .where('store_id', isEqualTo: storeId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(_toMap).toList()
        ..sort((a, b) => (b['created_at']?.toString() ?? '')
            .compareTo(a['created_at']?.toString() ?? ''));
      return list;
    });
  }

  /// Push a DoDoo order status update via the DoDoo API.
  Future<void> updateDodooOrderStatus({
    required String orderId,
    required String newStatus,
    String? orderType,
  }) async {
    await _dodooApi.pushStatus(
      orderNumber: orderId,
      internalStatus: newStatus,
      orderType: orderType,
    );
  }

  /// Model B — the store creates a delivery order itself (walk-in / phone).
  /// Starts at `placed`; the store then Accepts → Ready to dispatch a rider.
  Future<String> createOrder({
    required String storeId,
    required String storeName,
    required String fromAddress,
    required String cityCode,
    required String customerName,
    required String customerPhone,
    required String dropAddress,
    required String itemsSummary,
    double? orderAmount,
    required double riderEarning,
  }) async {
    final now = DateTime.now();
    final orderNumber =
        'ST${now.millisecondsSinceEpoch.remainder(1000000).toString().padLeft(6, '0')}';
    final ref = await Db.orders.add({
      'order_number': orderNumber,
      'store_id': storeId,
      'store_name': storeName,
      'source': 'store',
      'status': StoreOrderStatus.placed,
      'from_address': fromAddress,
      'to_address': dropAddress,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'items_summary': itemsSummary,
      'order_amount': orderAmount,
      // The item total is the store's payout (settled by the platform); the
      // rider is paid the delivery fee (total_earning) separately.
      'store_earning': orderAmount,
      'total_earning': riderEarning,
      'minimum_fare': riderEarning,
      'distance_in_km': 2.0,
      'city_code': cityCode,
      'created_at': FieldValue.serverTimestamp(),
      'status_updated_at': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Store accepts a new order → preparing.
  Future<void> acceptOrder(String orderId) async {
    await Db.orders.doc(orderId).update({
      'status': StoreOrderStatus.preparing,
      'accepted_by_store_at': FieldValue.serverTimestamp(),
      'status_updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Store marks the order Ready → becomes rider-facing `pending` and is
  /// broadcast to all approved riders (offers), reusing the rider flow.
  Future<void> markReady(String orderId) async {
    // Fetch the order to get store_id and store_earning.
    final orderSnap = await Db.orders.doc(orderId).get();
    final data = orderSnap.data();
    if (data == null) throw Exception('Order not found');

    final storeId = data['store_id']?.toString();
    final storeEarning = data['store_earning'] ?? data['order_amount'];

    if (storeId == null) throw Exception('Store ID not found');

    // Update order status.
    await Db.orders.doc(orderId).update({
      'status': StoreOrderStatus.pending,
      'ready_at': FieldValue.serverTimestamp(),
      'status_updated_at': FieldValue.serverTimestamp(),
    });

    // Credit the store wallet (auto-settlement).
    if (storeEarning != null && storeEarning > 0) {
      try {
        await StoreWalletService.instance.creditWallet(
          storeId,
          amount: double.parse(storeEarning.toString()),
          orderId: orderId,
          description: 'Order payout (#${data['order_number'] ?? orderId})',
        );
      } catch (_) {
        // Log but don't fail the order; the credit can be retried via admin.
      }
    }

    // Broadcast to riders.
    await _broadcastToRiders(orderId);
  }

  /// Store cancels an order (only meaningful before a rider takes it).
  Future<void> cancelOrder(String orderId) async {
    await Db.orders.doc(orderId).update({
      'status': StoreOrderStatus.cancelled,
      'status_updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Creates a per-rider offer for every approved rider (mirrors the admin
  /// broadcast). Riders then see it via their existing pending-offer flow.
  Future<void> _broadcastToRiders(String orderId) async {
    final riders =
        await Db.riders.where('account_status', isEqualTo: 'approved').get();
    if (riders.docs.isEmpty) return;
    // Clear any stale offers for this order first, then re-offer.
    final existing =
        await Db.orderOffers.where('order_id', isEqualTo: orderId).get();
    final batch = _db.batch();
    for (final o in existing.docs) {
      batch.delete(o.reference);
    }
    for (final r in riders.docs) {
      batch.set(Db.orderOffers.doc(), {
        'order_id': orderId,
        'rider_id': r.id,
        'is_accepted': false,
        'is_rejected': false,
        'notified_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
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
