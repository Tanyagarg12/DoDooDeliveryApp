import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/firebase/store_order_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/fade_in.dart';
import '../../../../core/widgets/support_modal.dart';
import '../../domain/entities/store_entity.dart';
import 'store_order_detail_screen.dart';

/// The store's Orders tab — modelled on the rider's "My Orders" page: a clean
/// header, a rounded Active/History tab bar, and premium order cards.
///
/// Live orders come from the DoDoo API (auto-refresh every 2 min + manual
/// refresh). The store Open/Closed control lives on the Dashboard, not here.
class StoreOrdersView extends StatefulWidget {
  const StoreOrdersView({super.key, required this.store});
  final StoreEntity store;

  @override
  State<StoreOrdersView> createState() => _StoreOrdersViewState();
}

class _StoreOrdersViewState extends State<StoreOrdersView>
    with SingleTickerProviderStateMixin {
  late final TabController _tc = TabController(length: 2, vsync: this);
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _tc.addListener(() => setState(() {})); // repaint header/badges on swipe
    _sub = StoreOrderService.instance
        .streamOrdersFromDodoo(widget.store.id)
        .listen((orders) {
      if (mounted) {
        setState(() {
          _orders = orders;
          _loading = false;
          _refreshing = false;
        });
      }
    }, onError: (_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _tc.dispose();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final orders = await StoreOrderService.instance
          .fetchStoreOrdersFromDodoo(widget.store.id);
      if (mounted) {
        setState(() {
          _orders = orders;
          _refreshing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  List<Map<String, dynamic>> get _active => _orders
      .where((o) => StoreOrderStatus.isActive(o['status']?.toString()))
      .toList();

  List<Map<String, dynamic>> get _history => _orders
      .where((o) => StoreOrderStatus.isFinished(o['status']?.toString()))
      .toList();

  @override
  Widget build(BuildContext context) {
    final active = _active;
    final history = _history;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            _tabBar(active.length, history.length),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tc,
                      children: [
                        _OrderList(
                          orders: active,
                          onRefresh: _refresh,
                          onOpen: _openDetail,
                          emptyIcon: Icons.receipt_long_rounded,
                          emptyTitle: 'No active orders',
                          emptySubtitle:
                              'New orders will appear here as customers place them.',
                        ),
                        _OrderList(
                          orders: history,
                          onRefresh: _refresh,
                          onOpen: _openDetail,
                          emptyIcon: Icons.history_rounded,
                          emptyTitle: 'No past orders yet',
                          emptySubtitle:
                              'Delivered and cancelled orders will show up here.',
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(Map<String, dynamic> o) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoreOrderDetailScreen(
          orderId: o['id'].toString(),
          orderData: o,
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My Orders',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text('Track your incoming & past orders',
                    style: TextStyle(
                        fontSize: 12.5, color: Colors.grey.shade600)),
              ],
            ),
          ),
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              color: AppColors.primary,
              tooltip: 'Refresh orders',
            ),
          const SupportIconButton(),
        ],
      ),
    );
  }

  // ── Tab bar ─────────────────────────────────────────────────────────────────

  Widget _tabBar(int activeCount, int histCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tc,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(9),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        tabs: [
          _tab('Active', activeCount, 0, AppColors.primary),
          _tab('History', histCount, 1, const Color(0xFF64748B)),
        ],
      ),
    );
  }

  Widget _tab(String label, int count, int idx, Color badgeColor) {
    final selected = _tc.index == idx;
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            _CountBadge(count, color: selected ? Colors.white : badgeColor),
          ],
        ],
      ),
    );
  }
}

// ── Order list (reused for Active + History) ──────────────────────────────────

class _OrderList extends StatelessWidget {
  const _OrderList({
    required this.orders,
    required this.onRefresh,
    required this.onOpen,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  final List<Map<String, dynamic>> orders;
  final Future<void> Function() onRefresh;
  final void Function(Map<String, dynamic>) onOpen;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return _EmptyTab(
        onRefresh: onRefresh,
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => FadeIn(
          index: i,
          child: _StoreOrderCard(order: orders[i], onTap: () => onOpen(orders[i])),
        ),
      ),
    );
  }
}

// ── Order card ────────────────────────────────────────────────────────────────

class _StoreOrderCard extends StatelessWidget {
  const _StoreOrderCard({required this.order, required this.onTap});
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = order['status']?.toString() ?? '';
    final color = StoreOrderStatus.color(status);
    final label = StoreOrderStatus.label(status);
    final earn = order['store_earning'] ?? order['order_amount'];
    final when = _fmtDate(order['created_at']?.toString() ?? '');
    final lower = status.toLowerCase();
    final cancelled = lower == 'cancel' || lower == 'cancelled';
    final finished = StoreOrderStatus.isFinished(status);

    return Opacity(
      opacity: cancelled ? 0.72 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEDEFE0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Column(
              children: [
                // Coloured header strip
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  color: color.withValues(alpha: 0.08),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                            finished
                                ? (cancelled
                                    ? Icons.cancel_rounded
                                    : Icons.check_circle_rounded)
                                : Icons.receipt_long_rounded,
                            size: 17,
                            color: color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Order #${order['order_number'] ?? ''}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5)),
                            if (when.isNotEmpty) ...[
                              const SizedBox(height: 1),
                              Text(when,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600)),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(label,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    children: [
                      _infoRow(Icons.person_rounded, 'Customer',
                          order['customer_name']?.toString() ?? '—'),
                      const SizedBox(height: 12),
                      _infoRow(Icons.location_on_rounded, 'Deliver to',
                          order['to_address']?.toString() ?? '—'),
                      if ((order['items_summary'] ?? order['desc'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _infoRow(
                            Icons.shopping_bag_rounded,
                            'Items',
                            (order['items_summary'] ?? order['desc'] ?? '')
                                .toString()),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          if (earn != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: const BoxDecoration(
                                gradient: AppGradients.brandSplash,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10)),
                              ),
                              child: Text('You earn ₹$earn',
                                  style: const TextStyle(
                                      color: AppColors.onPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13)),
                            ),
                          const Spacer(),
                          Text('View details',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary)),
                          const Icon(Icons.chevron_right_rounded,
                              size: 18, color: AppColors.primary),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.4,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(value.isEmpty ? '—' : value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, height: 1.25),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Shared bits ───────────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count, {this.color = AppColors.primary});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$count',
          style: TextStyle(
              color: color == Colors.white ? AppColors.primary : Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800)),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onRefresh,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: FadeIn(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primaryContainer,
                              AppColors.primaryContainer.withValues(alpha: 0.4),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 44, color: AppColors.primary),
                      ),
                      const SizedBox(height: 22),
                      Text(title,
                          style: const TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              height: 1.5)),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Refresh'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmtDate(String raw) {
  if (raw.isEmpty) return '';
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}
