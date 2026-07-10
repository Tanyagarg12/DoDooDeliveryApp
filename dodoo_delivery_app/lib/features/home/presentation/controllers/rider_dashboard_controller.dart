import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/rider_firestore_api.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/sound_service.dart';
import '../../../tracking/data/location_tracking_service.dart';
import 'rider_dashboard_state.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

/// Overridden in HomeShell via ProviderScope.overrides.
final riderApiProvider = Provider<RiderFirestoreApi>((_) => RiderFirestoreApi());

/// Overridden in HomeShell with the authenticated rider map.
final initialRiderProvider = Provider<Map<String, dynamic>>(
  (_) => const {},
);

final riderDashboardProvider =
    StateNotifierProvider<RiderDashboardController, RiderDashboardState>(
  (ref) {
    final api = ref.watch(riderApiProvider);
    final rider = ref.watch(initialRiderProvider);
    return RiderDashboardController(api: api, initialRider: rider);
  },
  // Required in Riverpod 2.x: declare every overridden dependency so the
  // framework looks this provider up in the correct nested ProviderScope.
  dependencies: [riderApiProvider, initialRiderProvider],
);

final themeModeProvider = StateProvider<bool>((_) => false); // false = light

/// Selected bottom-nav tab on the home shell (0=Home … 4=Profile). Lets other
/// widgets (e.g. the wallet badge) jump to a tab.
final selectedHomeTabProvider = StateProvider<int>((_) => 0);

/// The city the rider is filtering offers by on the Orders → Offers tab.
/// Defaults to Anantapur (ATP); `null` would mean "All cities".
final riderCityFilterProvider = StateProvider<String?>((_) => 'ATP');

// ── Controller ────────────────────────────────────────────────────────────────

class RiderDashboardController
    extends StateNotifier<RiderDashboardState> {
  RiderDashboardController({
    required RiderFirestoreApi api,
    required Map<String, dynamic> initialRider,
  })  : _api = api,
        super(RiderDashboardState(rider: initialRider)) {
    _start();
  }

  final RiderFirestoreApi _api;
  Timer? _pollTimer;
  Timer? _offlineTimer;
  int _offlineReminderMinutes = 15;
  final Set<String> _shownOfferIds = {};
  // Suppresses the alert chime on the very first dashboard load (existing
  // pending offers shouldn't sound like they just arrived).
  bool _firstDashboardLoad = true;
  // Tracks the admin's note so a newly-arrived one notifies the rider once
  // (the first load is silent so an existing note doesn't ping on app open).
  String _lastAdminComment = '';
  bool _sawFirstComment = false;

  Future<void> _start() async {
    // Defer first refresh past provider construction
    Future.microtask(() => refresh(showLoading: true));
    _pollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => refresh(),
    );

    // Init local notifications (non-blocking)
    NotificationService.instance.init().ignore();

    // Load the admin-configured offline-reminder timing.
    _api.offlineReminderMinutes().then((m) {
      _offlineReminderMinutes = m;
      if (mounted) _evaluateOfflineReminder(state.currentStatus);
    }).ignore();

    // Load initial history (after short delay so dashboard loads first)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setHistoryFilter('week');
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _offlineTimer?.cancel();
    SoundService.instance.stopAlert();
    LocationTrackingService.instance.stop();
    super.dispose();
  }

  // ── Offline reminder ────────────────────────────────────────────────────

  /// Starts/stops the "you've been offline a while" reminder based on status.
  void _evaluateOfflineReminder(String status) {
    if (status == 'offline') {
      // (Re)start the countdown only if it isn't already running.
      _offlineTimer ??= Timer(
        Duration(minutes: _offlineReminderMinutes),
        _fireOfflineReminder,
      );
    } else {
      _offlineTimer?.cancel();
      _offlineTimer = null;
      if (state.offlineReminder) {
        state = state.copyWith(offlineReminder: false);
      }
    }
  }

  void _fireOfflineReminder() {
    _offlineTimer = null;
    if (!mounted || state.currentStatus != 'offline') return;
    NotificationService.instance.showOfflineReminder().ignore();
    state = state.copyWith(offlineReminder: true);
  }

  /// Called by the UI after showing the reminder dialog.
  void dismissOfflineReminder({bool reArm = false}) {
    state = state.copyWith(offlineReminder: false);
    if (reArm && state.currentStatus == 'offline') {
      _offlineTimer ??= Timer(
        Duration(minutes: _offlineReminderMinutes),
        _fireOfflineReminder,
      );
    }
  }

  // ── Refresh ───────────────────────────────────────────────────────────────

  Future<void> refresh({bool showLoading = false}) async {
    if (!mounted) return;
    if (showLoading) state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _api.dashboard();
      if (!mounted) return;
      final offers = _asList(data['pending_offers']);

      // Offer ids before/after this poll, for notification bookkeeping.
      final prevIds =
          state.pendingOffers.map((o) => o['id'].toString()).toSet();
      final currIds = offers.map((o) => o['id'].toString()).toSet();

      // An offer that vanished was taken by another rider (or expired) — clear
      // its notification so riders aren't pinged about an order they can't take.
      for (final goneId in prevIds.difference(currIds)) {
        NotificationService.instance.cancel(goneId.hashCode).ignore();
      }

      // The first not-yet-seen offer drives the in-app incoming sheet.
      final newOffer = _findNewOffer(offers);

      // Notify for brand-new offers, but cap how many notifications we push so
      // the rider isn't flooded — only the first couple ping; the rest still
      // appear in the Offers tab (just without a notification banner).
      const maxNotifications = 2;
      var hasBrandNewOffer = false;
      var notified = 0;
      for (final o in offers) {
        final id = o['id'].toString();
        if (_shownOfferIds.contains(id)) continue;
        _shownOfferIds.add(id);
        hasBrandNewOffer = true;
        if (notified >= maxNotifications) continue; // rest: Offers list only
        notified++;
        final order = (o['order'] as Map?) ?? o;
        final amount = order['total_earning'] ?? order['minimum_fare'] ?? '0';
        final from =
            (order['from_address']?.toString() ?? '').split(',').first;
        NotificationService.instance
            .showNewOrder(
              title: 'New Delivery Request',
              body: '₹$amount • $from',
              id: id.hashCode,
            )
            .ignore();
      }
      final wasFirstLoad = _firstDashboardLoad;
      _firstDashboardLoad = false;

      // Ring a LOOPING alert while there is an un-answered offer the rider can
      // act on (and they're not already on a delivery). It keeps ringing until
      // they accept/reject or the offer is taken — then we stop it. The very
      // first dashboard load doesn't ring for already-waiting offers.
      final canAct = offers.isNotEmpty && !state.hasActiveOrder;
      final newArrival = hasBrandNewOffer && !wasFirstLoad;
      if (canAct && (newArrival || SoundService.instance.isAlerting)) {
        SoundService.instance.startAlertLoop().ignore();
      } else if (!canAct) {
        SoundService.instance.stopAlert().ignore();
      }

      // Admin note → notify the rider when a new message arrives (once).
      final newComment =
          ((data['rider'] as Map?)?['admin_comment'] ?? '').toString().trim();
      if (_sawFirstComment &&
          newComment.isNotEmpty &&
          newComment != _lastAdminComment) {
        NotificationService.instance
            .showSupportMessage(
              title: 'Message from DoDoo',
              body: newComment,
            )
            .ignore();
      }
      _sawFirstComment = true;
      _lastAdminComment = newComment;

      state = state.copyWith(
        rider: Map<String, dynamic>.from(data['rider'] ?? state.rider),
        earnings: Map<String, dynamic>.from(data['earnings_summary'] ?? {}),
        activeOrders: _asList(data['active_orders']),
        orderHistory: _asList(data['order_history']),
        pendingOffers: offers,
        withdrawalRequests: _asList(data['withdrawal_requests']),
        isLoading: false,
        newOfferId: newOffer?['id']?.toString(),
      );
      _evaluateOfflineReminder(state.currentStatus);
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          error: _errorMsg(e),
        );
      }
    }
  }

  void clearNewOffer() => state = state.copyWith(clearNewOffer: true);

  // ── History ───────────────────────────────────────────────────────────────

  Future<void> setHistoryFilter(String filter) async {
    if (!mounted) return;
    state = state.copyWith(historyFilter: filter, isHistoryLoading: true);
    try {
      final data = await _api.orderHistory(filter);
      if (!mounted) return;
      state = state.copyWith(
        acceptedHistory: _asList(data['accepted']),
        rejectedHistory: _asList(data['rejected']),
        historySummary: Map<String, dynamic>.from(data['summary'] ?? {}),
        isHistoryLoading: false,
      );
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isHistoryLoading: false, error: _errorMsg(e));
      }
    }
  }

  // ── Status ────────────────────────────────────────────────────────────────

  Future<void> setStatus(String status) async {
    if (!mounted) return;
    // A profile photo is mandatory before a rider can go online. (The UI routes
    // them to Profile to add one; this is the enforcement backstop.)
    if (status == 'online' && state.needsProfilePhoto) {
      state = state.copyWith(
        error: 'Add a profile photo before going online.',
      );
      return;
    }
    // Status automation: while a delivery is active the rider is locked to
    // 'busy' and cannot manually switch. It returns to 'online' automatically
    // when the order completes (handled server-side in updateOrderStatus).
    if (state.hasActiveOrder && status != 'busy') {
      state = state.copyWith(
        error: 'Your status is locked while you have an active delivery.',
      );
      return;
    }
    state = state.copyWith(isStatusLoading: true, clearError: true);
    try {
      final data = await _api.setStatus(status);
      if (!mounted) return;
      state = state.copyWith(
        rider: {...state.rider, 'current_status': data['status'] ?? status},
        isStatusLoading: false,
      );
      // Live location sharing follows the rider's online state.
      final newStatus = (data['status'] ?? status).toString();
      if (newStatus == 'online') {
        LocationTrackingService.instance.start();
      } else if (newStatus == 'offline') {
        LocationTrackingService.instance.stop();
      }
      _evaluateOfflineReminder(newStatus);
      await refresh();
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isStatusLoading: false,
          error: _errorMsg(e),
        );
      }
    }
  }

  // ── Orders ────────────────────────────────────────────────────────────────

  Future<bool> acceptOffer(Map<String, dynamic> offer) async {
    final orderId = offer['order']?['id']?.toString() ?? offer['id']?.toString();
    if (orderId == null) return false;
    if (!mounted) return false;
    // One active delivery at a time.
    if (state.hasActiveOrder) {
      state = state.copyWith(
        error: 'Finish your current delivery before accepting a new one.',
      );
      return false;
    }
    _cancelOfferNotification(offer);
    SoundService.instance.stopAlert().ignore();
    state = state.copyWith(isLoading: true);
    try {
      await _api.acceptOrder(orderId);
      // Status automation: accepting an order makes the rider Busy.
      try {
        await _api.setStatus('busy');
      } catch (_) {/* non-fatal — refresh will reconcile */}
      // Ensure live location is shared during the delivery so the admin can
      // track this rider on the live map (navigation replaces in-app tracking
      // for the rider themselves).
      LocationTrackingService.instance.start();
      // (No "order assigned" notification — the rider just tapped Accept, and
      // it showed an internal id which isn't useful.)
      if (!mounted) return false;
      await refresh();
      return true;
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false, error: _errorMsg(e));
      return false;
    }
  }

  Future<void> rejectOffer(Map<String, dynamic> offer) async {
    final orderId = offer['order']?['id']?.toString() ?? offer['id']?.toString();
    if (orderId == null) return;
    _cancelOfferNotification(offer);
    SoundService.instance.stopAlert().ignore();
    try {
      await _api.rejectOrder(orderId);
      if (!mounted) return;
      await refresh();
    } catch (e) {
      if (mounted) state = state.copyWith(error: _errorMsg(e));
    }
  }

  Future<void> advanceOrderStatus(
      Map<String, dynamic> order, String nextStatus) async {
    final orderId = order['id']?.toString();
    if (orderId == null) return;
    if (!mounted) return;
    state = state.copyWith(isLoading: true);
    try {
      await _api.updateOrderStatus(orderId, nextStatus);
      // Once delivered/cancelled the order is no longer active — remove it
      // immediately so the "status locked while you have an active delivery"
      // message clears right away (don't wait for the next refresh).
      if (nextStatus == 'completed' || nextStatus == 'cancelled') {
        final remaining = state.activeOrders
            .where((o) => o['id']?.toString() != orderId)
            .toList();
        state = state.copyWith(activeOrders: remaining);
      }
      if (nextStatus == 'completed') {
        final earning =
            order['total_earning'] ?? order['minimum_fare'] ?? '';
        NotificationService.instance
            .showPayment(
              title: 'Payment credited',
              body: earning == ''
                  ? 'Delivery completed and added to your wallet.'
                  : '₹$earning credited to your wallet.',
            )
            .ignore();
      }
      if (!mounted) return;
      await refresh();
      // Completed/cancelled orders move to history — refresh it so the
      // History tab reflects the change immediately.
      if (nextStatus == 'completed' || nextStatus == 'cancelled') {
        await setHistoryFilter(state.historyFilter);
      }
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false, error: _errorMsg(e));
    }
  }

  // ── Location ──────────────────────────────────────────────────────────────

  Future<void> sendLocation() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true);
    try {
      final orderId = state.activeOrders.isNotEmpty
          ? state.activeOrders.first['id']?.toString()
          : null;
      await _api.sendCurrentLocation(orderId: orderId);
      if (!mounted) return;
      state = state.copyWith(isLoading: false);
      await refresh();
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false, error: _errorMsg(e));
    }
  }

  // ── Earnings ──────────────────────────────────────────────────────────────

  Future<bool> requestWithdrawal({
    required String amount,
    required String bankAccount,
    required String bankIfsc,
    String? accountHolderName,
    String? bankName,
  }) async {
    if (!mounted) return false;
    state = state.copyWith(isLoading: true);
    try {
      final data = await _api.requestWithdrawal(
        amount: amount,
        bankAccount: bankAccount,
        bankIfsc: bankIfsc,
        accountHolderName: accountHolderName,
        bankName: bankName,
      );
      if (!mounted) return false;
      final newBalance = data['wallet']?['balance'];
      state = state.copyWith(
        rider: newBalance != null
            ? {...state.rider, 'wallet_balance': newBalance}
            : null,
        isLoading: false,
      );
      await refresh();
      return true;
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false, error: _errorMsg(e));
      return false;
    }
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  Future<bool> saveProfile({
    required Map<String, String> fields,
    XFile? photo,
  }) async {
    if (!mounted) return false;
    state = state.copyWith(isLoading: true);
    try {
      final data = await _api.updateProfile(fields: fields, photo: photo);
      if (!mounted) return false;
      state = state.copyWith(rider: data, isLoading: false);
      return true;
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false, error: _errorMsg(e));
      return false;
    }
  }

  Future<bool> saveBankDetails({
    required String bankAccount,
    required String bankIfsc,
  }) async {
    if (!mounted) return false;
    state = state.copyWith(isLoading: true);
    try {
      final data = await _api.saveBankDetails(
        bankAccount: bankAccount,
        bankIfsc: bankIfsc,
      );
      if (!mounted) return false;
      state = state.copyWith(rider: data, isLoading: false);
      return true;
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false, error: _errorMsg(e));
      return false;
    }
  }

  Future<bool> saveDocument({
    required String docType,
    required XFile image,
  }) async {
    if (!mounted) return false;
    state = state.copyWith(isLoading: true);
    try {
      final data = await _api.saveDocument(docType: docType, image: image);
      if (!mounted) return false;
      state = state.copyWith(rider: data, isLoading: false);
      return true;
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false, error: _errorMsg(e));
      return false;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _asList(dynamic v) {
    if (v is List) {
      return v.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  void _cancelOfferNotification(Map<String, dynamic> offer) {
    final id = offer['id']?.toString();
    if (id != null) {
      NotificationService.instance.cancel(id.hashCode).ignore();
    }
  }

  Map<String, dynamic>? _findNewOffer(List<Map<String, dynamic>> offers) {
    if (offers.isEmpty) return null;
    for (final o in offers) {
      final id = o['id']?.toString();
      if (id != null && !_shownOfferIds.contains(id)) return o;
    }
    return null;
  }

  String _errorMsg(Object e) {
    final msg = e.toString();
    if (msg.contains('connection') || msg.contains('SocketException')) {
      return 'Cannot reach server. Check your connection.';
    }
    return msg.replaceFirst('Exception: ', '');
  }
}
