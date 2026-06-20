import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/dodoo_cities.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/city_selector.dart';
import '../../../../core/widgets/fade_in.dart';
import '../../../../core/widgets/support_modal.dart';
import '../controllers/rider_dashboard_controller.dart';
import '../widgets/order_card.dart';

/// Filters a list of pending offers down to a single city code (null = all).
List<Map<String, dynamic>> filterOffersByCity(
    List<Map<String, dynamic>> offers, String? cityCode) {
  if (cityCode == null) return offers;
  return offers.where((o) {
    final order = (o['order'] as Map?) ?? o;
    return (order['city_code']?.toString() ?? '') == cityCode;
  }).toList();
}

class OrdersTab extends ConsumerStatefulWidget {
  const OrdersTab({super.key});

  @override
  ConsumerState<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends ConsumerState<OrdersTab>
    with SingleTickerProviderStateMixin {
  late TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(riderDashboardProvider);
    final cityFilter = ref.watch(riderCityFilterProvider);
    final visibleOffers =
        filterOffersByCity(state.pendingOffers, cityFilter);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('My Orders',
                            style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(
                          'Track your active deliveries & offers',
                          style: TextStyle(
                              fontSize: 12.5, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (state.isLoading)
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
                      onPressed: () => ref
                          .read(riderDashboardProvider.notifier)
                          .refresh(showLoading: true),
                      icon: const Icon(Icons.refresh_rounded),
                      color: cs.primary,
                    ),
                  const SupportIconButton(),
                ],
              ),
            ),

            // Tab bar
            Container(
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: TabBar(
                controller: _tc,
                indicator: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(9),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: cs.onSurfaceVariant,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Active'),
                        if (state.activeOrders.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _CountBadge(state.activeOrders.length),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Offers'),
                        if (visibleOffers.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _CountBadge(visibleOffers.length,
                              color: AppColors.busy),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tc,
                children: [
                  _ActiveOrdersList(state: state),
                  _OffersList(state: state),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Active orders list ────────────────────────────────────────────────────────

class _ActiveOrdersList extends ConsumerWidget {
  const _ActiveOrdersList({required this.state});
  final dynamic state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refresh() =>
        ref.read(riderDashboardProvider.notifier).refresh(showLoading: true);
    if (state.activeOrders.isEmpty) {
      return _EmptyTab(
        onRefresh: refresh,
        icon: Icons.delivery_dining_outlined,
        title: 'No active orders',
        subtitle:
            'Accepted orders appear here.\nGo online to receive new requests.',
      );
    }
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: state.activeOrders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => FadeIn(
          index: i,
          child: ActiveOrderCard(
            order: state.activeOrders[i],
            isLoading: state.isLoading,
          ),
        ),
      ),
    );
  }
}

// ── Offers list ───────────────────────────────────────────────────────────────

class _OffersList extends ConsumerWidget {
  const _OffersList({required this.state});
  final dynamic state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refresh() =>
        ref.read(riderDashboardProvider.notifier).refresh(showLoading: true);
    final busy = state.hasActiveOrder;
    final cityFilter = ref.watch(riderCityFilterProvider);
    final offers = filterOffersByCity(state.pendingOffers, cityFilter);

    // City picker sits above the list so the rider can pick where they want to
    // pick up requests from.
    final selector = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: CitySelector(
        value: cityFilter,
        includeAll: true,
        label: 'Requests in',
        onChanged: (code) =>
            ref.read(riderCityFilterProvider.notifier).state = code,
      ),
    );

    if (offers.isEmpty) {
      return Column(
        children: [
          selector,
          Expanded(
            child: _EmptyTab(
              onRefresh: refresh,
              icon: Icons.notifications_none_rounded,
              title: state.pendingOffers.isEmpty
                  ? 'No pending offers'
                  : 'No offers in this city',
              subtitle: state.pendingOffers.isEmpty
                  ? 'New delivery requests appear here when you are online.'
                  : 'Try “All cities” to see requests from other locations.',
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        selector,
        Expanded(
          child: RefreshIndicator(
            onRefresh: refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: offers.length + (busy ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                if (busy && i == 0) return const _BusyBanner();
                final offer = offers[busy ? i - 1 : i];
                final order = Map<String, dynamic>.from(offer['order'] ?? offer);
                return FadeIn(
                  index: i,
                  child: _OfferCard(
                    offer: offer,
                    order: order,
                    isLoading: state.isLoading,
                    locked: busy,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown atop the Offers list while a delivery is active.
class _BusyBanner extends StatelessWidget {
  const _BusyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_clock_rounded, color: Color(0xFF4F46E5), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'You\'re on a delivery. Finish it to accept new orders.',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4F46E5)),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends ConsumerWidget {
  const _OfferCard({
    required this.offer,
    required this.order,
    required this.isLoading,
    this.locked = false,
  });
  final Map<String, dynamic> offer;
  final Map<String, dynamic> order;
  final bool isLoading;
  final bool locked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? AppColors.busy.withValues(alpha: 0.2)
              : AppColors.busyBg,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.busy.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top gradient header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.busy.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_rounded,
                    color: AppColors.busy, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Order #${order['order_number'] ?? '—'}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: const BoxDecoration(
                    gradient: AppGradients.brandSplash,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Text(
                    '₹${order['total_earning'] ?? order['minimum_fare'] ?? '0'}',
                    style: const TextStyle(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // From/to
                _AddressRow(
                  icon: Icons.store_rounded,
                  iconColor: AppColors.primary,
                  label: 'Pickup',
                  address: order['from_address']?.toString() ?? '—',
                ),
                const SizedBox(height: 8),
                _AddressRow(
                  icon: Icons.location_on_rounded,
                  iconColor: AppColors.busy,
                  label: 'Drop',
                  address: order['to_address']?.toString() ?? '—',
                ),
                const SizedBox(height: 12),

                // Meta chips
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Chip(
                        icon: Icons.straighten_rounded,
                        label:
                            '${order['distance_in_km'] ?? 0} km'),
                    _Chip(
                        icon: Icons.schedule_rounded,
                        label:
                            '${order['estimated_time_minutes'] ?? 30} min'),
                    if ((order['city_code']?.toString() ?? '').isNotEmpty)
                      _Chip(
                          icon: Icons.location_city_rounded,
                          label: DodooCities.nameFor(
                              order['city_code']?.toString())),
                  ],
                ),
                const SizedBox(height: 14),

                // Accept / Reject
                Row(
                  children: [
                    SizedBox(
                      width: 48,
                      height: 46,
                      child: OutlinedButton(
                        onPressed: isLoading
                            ? null
                            : () => ref
                                .read(riderDashboardProvider.notifier)
                                .rejectOffer(offer),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: (isLoading || locked)
                            ? null
                            : () => ref
                                .read(riderDashboardProvider.notifier)
                                .acceptOffer(offer),
                        icon: Icon(
                            locked
                                ? Icons.lock_rounded
                                : Icons.check_circle_rounded,
                            size: 18),
                        label: Text(locked ? 'On a delivery' : 'Accept Order',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          backgroundColor: AppColors.online,
                          disabledBackgroundColor:
                              AppColors.offline.withValues(alpha: 0.4),
                          textStyle: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w800),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared ────────────────────────────────────────────────────────────────────

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.address,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String address;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.4,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(address,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: cs.onSurface),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceDark
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurface),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface)),
        ],
      ),
    );
  }
}

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
      child: Text(
        '$count',
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRefresh,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = LayoutBuilder(
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
                            cs.primaryContainer,
                            cs.primaryContainer.withValues(alpha: 0.4),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 44, color: cs.primary),
                    ),
                    const SizedBox(height: 22),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                          height: 1.5),
                    ),
                    if (onRefresh != null) ...[
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Refresh'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.primary,
                          side: BorderSide(color: cs.primary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (onRefresh == null) return content;
    return RefreshIndicator(onRefresh: onRefresh!, child: content);
  }
}
