import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/store_firestore_service.dart';
import '../../../../core/firebase/store_order_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../domain/entities/store_entity.dart';
import 'store_dashboard_state.dart';

/// Selected bottom-nav tab on the store home shell
/// (0=Dashboard, 1=Orders, 2=Menu, 3=Wallet, 4=Settings). Lets other widgets
/// (e.g. the dashboard earnings badge) jump to a tab.
final selectedStoreTabProvider = StateProvider<int>((_) => 0);

final storeDashboardProvider = StateNotifierProvider.family<
    StoreDashboardController,
    StoreDashboardState,
    StoreEntity>((ref, store) {
  return StoreDashboardController(initialStore: store);
});

class StoreDashboardController extends StateNotifier<StoreDashboardState> {
  StoreDashboardController({required StoreEntity initialStore})
      : super(StoreDashboardState(store: initialStore)) {
    _init();
  }

  final _orderService = StoreOrderService.instance;
  final _firestoreService = StoreFirestoreService.instance;
  StreamSubscription<List<Map<String, dynamic>>>? _ordersSub;

  /// Order ids already seen, so a poll only notifies for genuinely new orders.
  final Set<String> _seenOrderIds = {};
  bool _firstPollDone = false;

  void _init() {
    _listenToOrders();
  }

  void _listenToOrders() {
    _ordersSub?.cancel();
    _ordersSub = _orderService
        .streamOrdersFromDodoo(state.store.id)
        .listen((orders) {
      _maybeNotifyNewOrders(orders);
      if (orders.isEmpty) {
        state = state.copyWith(
          activeOrdersCount: 0,
          completedOrdersCount: 0,
          activeOrders: [],
          isLoading: false,
        );
        return;
      }

      // Count active vs completed
      final active = orders
          .where((o) => StoreOrderStatus.isActive(o['status']?.toString()))
          .toList();
      final completed = orders
          .where((o) => StoreOrderStatus.isFinished(o['status']?.toString()))
          .length;

      // Calculate today's earnings
      double todayEarnings = 0;
      for (final o in orders) {
        final earnings = o['store_earning'] ?? 0;
        if (earnings is num) {
          todayEarnings += earnings.toDouble();
        }
      }

      state = state.copyWith(
        activeOrdersCount: active.length,
        completedOrdersCount: completed,
        todayEarnings: todayEarnings,
        activeOrders: active,
        isLoading: false,
      );
    }, onError: (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    });
  }

  /// Sets the store open/closed. Explicit (not a blind flip) so each button
  /// does exactly what its label says. Updates the UI optimistically and
  /// reverts if the Firestore write fails.
  Future<void> setStoreOpen(bool open) async {
    final newStatus = open ? 'open' : 'closed';
    if (state.store.currentStatus == newStatus) return; // already there

    final previous = state.store;
    // Optimistic: reflect immediately so the toggle feels instant.
    state = state.copyWith(
      store: state.store.copyWith(currentStatus: newStatus),
      error: null,
    );
    try {
      await _firestoreService.updateStore({'current_status': newStatus});
    } catch (e) {
      // Revert on failure and surface the reason.
      state = state.copyWith(
        store: previous,
        error: 'Failed to update store status: ${e.toString()}',
      );
    }
  }

  Future<void> toggleStoreStatus() => setStoreOpen(!state.isStoreOpen);

  /// Fires a local notification for each newly-arrived order. Skips the first
  /// poll (so existing orders don't alert on app open) and keeps existing
  /// orders across a transient empty poll (avoids a false burst on error).
  void _maybeNotifyNewOrders(List<Map<String, dynamic>> orders) {
    if (orders.isEmpty) {
      _firstPollDone = true; // keep _seenOrderIds intact
      return;
    }
    if (_firstPollDone) {
      for (final o in orders) {
        final id = o['id']?.toString() ?? '';
        if (id.isEmpty || _seenOrderIds.contains(id)) continue;
        final st = o['status']?.toString().toLowerCase();
        if (st == 'open' || st == 'placed') {
          _notifyNewOrder(o);
        }
      }
    }
    _seenOrderIds
      ..clear()
      ..addAll(orders
          .map((o) => o['id']?.toString() ?? '')
          .where((s) => s.isNotEmpty));
    _firstPollDone = true;
  }

  void _notifyNewOrder(Map<String, dynamic> o) {
    final number = (o['order_number'] ?? o['id'] ?? '').toString();
    final amt = o['store_earning'] ?? o['order_amount'];
    final customer = o['customer_name']?.toString();
    final parts = <String>[
      if (number.isNotEmpty) '#$number',
      if (amt != null) '₹$amt',
      if (customer != null && customer.isNotEmpty && customer != '—') customer,
    ];
    unawaited(NotificationService.instance.showNewOrder(
      title: 'New order received 🛎️',
      body: parts.isEmpty ? 'You have a new order' : 'Order ${parts.join(' · ')}',
      id: number.hashCode & 0x7fffffff,
    ));
  }

  Future<void> refresh({bool showLoading = false}) async {
    if (showLoading) {
      state = state.copyWith(isLoading: true);
    }
    _listenToOrders();
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    super.dispose();
  }
}
