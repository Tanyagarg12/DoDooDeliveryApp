import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/dodoo_cities.dart';
import '../../../../core/constants/order_status.dart';
import '../../../../core/firebase/admin_firestore_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/widgets/city_selector.dart';
import '../../../../core/widgets/fade_in.dart';
import '../../../orders_api/data/dodoo_order_api.dart';
import '../../../orders_api/data/models/dodoo_order.dart';
import 'admin_order_detail_screen.dart';

/// Orders management tab inside the admin portal. Auto-syncs new orders from the
/// DoDoo API into Firestore (broadcasting them to riders), then lists every
/// order with its status, assigned rider, route and fare.
class AdminOrdersTab extends StatefulWidget {
  const AdminOrdersTab({super.key});

  @override
  State<AdminOrdersTab> createState() => AdminOrdersTabState();
}

class AdminOrdersTabState extends State<AdminOrdersTab> {
  // Minutes a pending order may wait unpicked before auto re-broadcast + alert.
  static const _unpickedMinutes = 5;
  // How many recent finished (delivered/cancelled) orders per city to backfill
  // so the Completed/Cancelled sections show recent history — the endpoint
  // returns thousands of years-old orders we must not import wholesale.
  static const _recentFinishedPerCity = 40;

  final _dodoo = DodooOrderApi();
  final _admin = AdminFirestoreService.instance;
  final _searchCtrl = TextEditingController();
  Timer? _watchTimer;
  StreamSubscription<List<Map<String, dynamic>>>? _ordersSub;

  List<Map<String, dynamic>> _orders = [];
  final Map<String, String> _riderNames = {}; // rider_id → name
  bool _loading = true;
  bool _syncing = false;
  String? _error;
  // An AdminOrderStatus.key (ongoing | inprogress | accepted | completed | cancelled)
  String _filter = 'ongoing';
  String _query = '';
  String? _cityCode; // selected delivery city; null = All cities
  int _reboardedAlert = 0; // # of orders auto re-broadcast in the last check
  // Suppresses the new-order chime on the very first sync (orders already on
  // the platform shouldn't sound like they just arrived).
  bool _firstSync = true;

  @override
  void initState() {
    super.initState();
    // LIVE order list — updates the moment a rider changes a status.
    _ordersSub = _admin.recentOrdersStream().listen((orders) {
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
        _error = null;
      });
    }, onError: (e) {
      if (mounted) setState(() => _error = e.toString());
    });
    load();
    // Watch for unpicked orders every 45s.
    _watchTimer = Timer.periodic(
        const Duration(seconds: 45), (_) => _checkUnpicked());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _watchTimer?.cancel();
    _ordersSub?.cancel();
    super.dispose();
  }

  /// Public so the dashboard can trigger a refresh. The order list itself comes
  /// from the LIVE stream (see initState); here we just (re)load rider names and
  /// pull fresh DoDoo orders in the BACKGROUND — never blocking the display.
  Future<void> load({bool silent = false}) async {
    await _loadRiderNames();
    await _backgroundSync();
  }

  Future<void> _loadRiderNames() async {
    try {
      final names = await _admin.riderNames();
      _riderNames
        ..clear()
        ..addAll(names);
      if (mounted) setState(() {});
    } catch (_) {/* names are best-effort */}
  }

  /// Pulls fresh orders from DoDoo into Firestore; the live stream then updates
  /// the list automatically.
  Future<void> _backgroundSync() async {
    await _syncFromDodoo();
    await _checkUnpicked();
  }

  /// Fetches open orders from the DoDoo API and imports any that aren't already
  /// in Supabase, broadcasting each to all approved riders. Best-effort: any
  /// failure (network, empty city) is swallowed so the existing list still loads.
  Future<void> _syncFromDodoo() async {
    if (_syncing) return;
    _syncing = true;
    if (mounted) setState(() {});
    try {
      // "All cities" syncs every configured city; otherwise just the one.
      final cities = _cityCode == null
          ? DodooCities.all
          : [DodooCities.byCode(_cityCode)];

      final riderIds = await _admin.approvedRiderIds();

      var imported = 0;
      final openIds = <String>{};
      final syncedCities = <String>{};
      for (final city in cities) {
        final pricePerKm = await _admin.pricePerKm(cityCode: city.code);
        final allOrders = await _dodoo.getAllOrders(cityCode: city.code);

        // Bucket by status so each lands in its admin section. The endpoint
        // returns thousands of years-old finished orders, so:
        //  • Open      → full detail + broadcast to riders (dispatch).
        //  • Active     (Accept/InProgress/OnGoing) → sparse, no broadcast.
        //  • Finished   (Deliver/Cancel) → only the most-recent few, sparse.
        final open = <DodooOrder>[];
        final active = <DodooOrder>[];
        final finished = <DodooOrder>[];
        for (final o in allOrders) {
          switch (o.internalStatus) {
            case 'pending':
              open.add(o);
            case 'completed':
            case 'cancelled':
              finished.add(o);
            default: // accepted / picked_up / in_transit
              active.add(o);
          }
        }
        finished.sort((a, b) =>
            (b.orderDate ?? '').compareTo(a.orderDate ?? ''));
        final recentFinished =
            finished.take(_recentFinishedPerCity).toList();

        syncedCities.add(city.code);
        openIds.addAll(open.map((o) => o.orderId));

        // Only OPEN orders are dispatched to riders + counted as "new".
        imported +=
            await _importOrders(open, city, pricePerKm, riderIds);
        // Active + recent finished: imported so the sections show, but sparse
        // (no per-order detail fetch) and never broadcast.
        await _importOrders(active, city, pricePerKm, const [],
            fetchDetail: false);
        await _importOrders(recentFinished, city, pricePerKm, const [],
            fetchDetail: false);
      }

      // Pull-sync: any of our still-pending orders that DoDoo no longer lists
      // as open were cancelled/closed on DoDoo → reflect that here.
      if (syncedCities.isNotEmpty) {
        await _admin.cancelMissingPending(openIds, syncedCities);
      }

      // Audible + banner alert when genuinely new orders arrive — but not on
      // the first sync (those orders were already waiting on the platform).
      if (imported > 0 && !_firstSync) {
        SoundService.instance.playNewOrder().ignore();
        NotificationService.instance
            .showNewOrder(
              title: 'New order${imported > 1 ? 's' : ''} received',
              body:
                  '$imported new order${imported > 1 ? 's' : ''} synced and broadcast to riders.',
            )
            .ignore();
      }
      _firstSync = false;
    } catch (_) {
      // Non-fatal — the Supabase order list still loads below.
    } finally {
      _syncing = false;
      if (mounted) setState(() {});
    }
  }

  /// Imports any orders not already in Firestore, broadcasting each new order
  /// to all approved riders. Returns the number of new orders imported.
  Future<int> _importOrders(
    List<DodooOrder> orders,
    DodooCity city,
    double? pricePerKm,
    List<String> riderIds, {
    bool fetchDetail = true,
  }) async {
    if (orders.isEmpty) return 0;

    final ids = orders.map((o) => o.orderId).toList();
    final existing = await _admin.existingOrderNumbers(ids);

    final newOnes = orders.where((o) => !existing.contains(o.orderId)).toList();
    if (newOnes.isEmpty) return 0;

    for (final o in newOnes) {
      // For dispatched (Open) orders, fetch the full detail (addresses,
      // customer, items, pricing) so they aren't blank. For history/active
      // backfill we keep the sparse list row to avoid thousands of calls.
      var full = o;
      if (fetchDetail) {
        try {
          final detail =
              await _dodoo.getOrderDetail(o.orderId, orderType: o.orderType);
          if (detail != null && !detail.isNoData) full = detail;
        } catch (_) {/* keep the sparse list row if detail fails */}
      }

      final data = full.toSupabaseOrder(
          pricePerKm: pricePerKm, cityCodeOverride: city.code);
      // Only broadcast offers for orders that are actually open/pending;
      // orders DoDoo already has in-progress are imported but not re-offered.
      final broadcastTo = data['status'] == 'pending' ? riderIds : const <String>[];
      await _admin.insertOrderWithOffers(data, broadcastTo);
    }
    return newOnes.length;
  }

  /// Re-broadcasts pending orders that have gone unpicked for > [_unpickedMinutes]
  /// and alerts the admin. Resetting status_updated_at throttles re-triggering.
  Future<void> _checkUnpicked() async {
    try {
      final cutoff = DateTime.now()
          .subtract(const Duration(minutes: _unpickedMinutes));
      final list = await _admin.staleUnpickedOrders(cutoff);
      if (list.isEmpty) {
        if (_reboardedAlert != 0 && mounted) setState(() => _reboardedAlert = 0);
        return;
      }

      // Re-broadcast each stale order to all approved riders.
      final riderIds = await _admin.approvedRiderIds();
      for (final o in list) {
        await _admin.reofferStale(o['id'].toString(), riderIds);
      }

      // Alert the admin (in-app banner + a local notification on mobile).
      NotificationService.instance
          .showApproval(
            title: 'Unpicked orders re-broadcast',
            body:
                '${list.length} order(s) were not picked for $_unpickedMinutes min and were re-sent to riders.',
          )
          .ignore();
      if (mounted) setState(() => _reboardedAlert = list.length);
    } catch (_) {
      // Best-effort — don't disrupt the list.
    }
  }

  Future<void> _openDetail(Map<String, dynamic> order) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AdminOrderDetailScreen(orderId: order['id'].toString()),
      ),
    );
    if (changed == true) load(silent: true);
  }

  /// True when an order belongs to the selected city. With "All cities"
  /// (_cityCode == null) every order matches. Legacy orders that were imported
  /// before city tagging (null/empty city_code) are shown under the default
  /// city so they never disappear entirely.
  bool _inSelectedCity(Map<String, dynamic> o) {
    if (_cityCode == null) return true; // All cities
    final c = o['city_code']?.toString() ?? '';
    if (c.isEmpty) return _cityCode == DodooCities.defaultCity.code;
    return c == _cityCode;
  }

  /// Orders for the selected city only — the base for both the list and counts.
  List<Map<String, dynamic>> get _cityOrders =>
      _orders.where(_inSelectedCity).toList();

  void _onCityChanged(String? code) {
    if (code == _cityCode) return;
    setState(() => _cityCode = code);
    // Pull this city's (or all cities') orders from DoDoo and refresh the list.
    load();
  }

  List<Map<String, dynamic>> get _filtered {
    final base = _cityOrders;
    var list = _filter == 'all'
        ? base
        : base
            .where((o) =>
                AdminOrderStatus.fromInternal(o['status']?.toString()).key ==
                _filter)
            .toList();
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((o) {
        final fields = [
          o['order_number'],
          o['customer_name'],
          o['from_address'],
          o['to_address'],
          _riderNames[o['assigned_rider_id']?.toString()],
        ];
        return fields.any(
            (f) => (f?.toString().toLowerCase() ?? '').contains(q));
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // City picker — drives which city's orders are synced & shown.
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: CitySelector(
                  value: _cityCode,
                  includeAll: true,
                  onChanged: _onCityChanged,
                ),
              ),
              const SizedBox(width: 8),
              // Manual refresh (re-syncs from DoDoo + reloads).
              Material(
                color: const Color(0xFFF2F5A0),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _loading || _syncing ? null : () => load(),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: _syncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF6B6E00)))
                        : const Icon(Icons.refresh_rounded,
                            size: 18, color: Color(0xFF6B6E00)),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Search bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search order #, customer, address, rider…',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
        ),
        // Unpicked-order admin alert
        if (_reboardedAlert > 0)
          Material(
            color: const Color(0xFFFEF3C7),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 18, color: Color(0xFFB45309)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$_reboardedAlert order(s) went unpicked for $_unpickedMinutes min and were auto re-broadcast.',
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB45309)),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded,
                        size: 16, color: Color(0xFFB45309)),
                    onPressed: () => setState(() => _reboardedAlert = 0),
                  ),
                ],
              ),
            ),
          ),
        Builder(builder: (_) {
          final city = _cityOrders;
          return _FilterRow(
            active: _filter,
            counts: {
              'all': city.length,
              for (final s in AdminOrderStatus.all)
                s.key: city
                    .where((o) =>
                        AdminOrderStatus.fromInternal(o['status']?.toString())
                            .key ==
                        s.key)
                    .length,
            },
            onChanged: (f) => setState(() => _filter = f),
          );
        }),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          child: _syncing
              ? Container(
                  width: double.infinity,
                  color: const Color(0xFFF2F5A0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: const Row(
                    children: [
                      SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF6B6E00))),
                      SizedBox(width: 8),
                      Text('Syncing orders from DoDoo…',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B6E00),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 44, color: Colors.grey),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final list = _filtered;
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => load(silent: true),
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Center(
                child: Text(_cityCode == null
                    ? 'No orders yet.'
                    : 'No orders in ${DodooCities.byCode(_cityCode).name} yet.')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => load(silent: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        itemBuilder: (_, i) => FadeIn(
          index: i,
          child: _OrderCard(
            order: list[i],
            riderName: _riderNames[list[i]['assigned_rider_id']?.toString()],
            onTap: () => _openDetail(list[i]),
          ),
        ),
      ),
    );
  }
}

// ── Filter chips ────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.active,
    required this.counts,
    required this.onChanged,
  });
  final String active;
  final Map<String, int> counts;
  final void Function(String) onChanged;

  /// The five business statuses, in workflow order (no 'All' — it loaded
  /// everything and was slow).
  static final List<({String key, String label})> _entries = [
    for (final s in AdminOrderStatus.all) (key: s.key, label: s.label),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: _entries.map((e) {
            final selected = active == e.key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${e.label} ${counts[e.key] ?? 0}'),
                selected: selected,
                onSelected: (_) => onChanged(e.key),
                selectedColor: const Color(0xFFBABC2F),
                labelStyle: TextStyle(
                  color: selected
                      ? const Color(0xFF1C1D00)
                      : const Color(0xFF6B6E00),
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
                backgroundColor: const Color(0xFFF2F5A0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Order card ───────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  const _OrderCard(
      {required this.order, required this.riderName, this.onTap});
  final Map<String, dynamic> order;
  final String? riderName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final statusInfo =
        AdminOrderStatus.fromInternal(order['status']?.toString());
    final color = statusInfo.color;
    final assignedId = order['assigned_rider_id']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('#${order['order_number'] ?? '—'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusInfo.label.toUpperCase(),
                      style: TextStyle(
                          color: color,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${(order['customer_name']?.toString().isNotEmpty ?? false) ? order['customer_name'] : 'Customer'}  ·  ${_fmtDate(order['created_at'])}',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              _line('Pickup', order['from_address']?.toString() ?? '—',
                  const Color(0xFFBABC2F)),
              const SizedBox(height: 2),
              _line('Drop', order['to_address']?.toString() ?? '—',
                  const Color(0xFFDC2626)),
              const SizedBox(height: 8),
              Text(
                _footer(order, assignedId, riderName),
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact "Pickup/Drop · address" line with a small colour dot (no big icon).
  Widget _line(String label, String text, Color dot) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 6),
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
        ),
        Expanded(
          child: Text('$label: $text',
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  /// Text-only footer: distance (only if known) · fare · assignee.
  String _footer(Map<String, dynamic> order, String? assignedId, String? riderName) {
    final km = (order['distance_in_km'] as num?)?.toDouble() ?? 0;
    final earnRaw = order['total_earning'] ?? order['minimum_fare'] ?? 0;
    final earnNum = earnRaw is num
        ? earnRaw.toDouble()
        : double.tryParse(earnRaw.toString()) ?? 0;
    final earn =
        earnNum % 1 == 0 ? earnNum.toStringAsFixed(0) : earnNum.toStringAsFixed(2);
    final parts = <String>[
      if (km > 0) '${km % 1 == 0 ? km.toStringAsFixed(0) : km.toStringAsFixed(1)} km',
      '₹$earn',
      assignedId == null ? 'Unassigned' : (riderName ?? 'Rider'),
    ];
    return parts.join('   ·   ');
  }

  String _fmtDate(dynamic raw) {
    final dt = DateTime.tryParse(raw?.toString() ?? '');
    if (dt == null) return '';
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year}';
  }

}
