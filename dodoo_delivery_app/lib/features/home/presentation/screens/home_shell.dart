import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/rider_firestore_api.dart';
import '../controllers/rider_dashboard_controller.dart';
import '../controllers/rider_dashboard_state.dart';
import '../widgets/incoming_order_sheet.dart';
import 'earnings_tab.dart';
import 'history_tab.dart';
import 'home_tab.dart';
import 'orders_tab.dart';
import 'profile_tab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.api,
    required this.initialRider,
  });

  final RiderFirestoreApi api;
  final Map<String, dynamic> initialRider;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final List<Override> _overrides;

  @override
  void initState() {
    super.initState();
    // Store overrides once — prevents ProviderScope from detecting a changed
    // override value on every parent rebuild (which would dispose the container
    // mid-refresh and trigger the Riverpod assertion).
    _overrides = [
      riderApiProvider.overrideWithValue(widget.api),
      initialRiderProvider.overrideWithValue(widget.initialRider),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: _overrides,
      child: const _HomeShellContent(),
    );
  }
}

class _HomeShellContent extends ConsumerStatefulWidget {
  const _HomeShellContent();

  @override
  ConsumerState<_HomeShellContent> createState() => _HomeShellContentState();
}

class _HomeShellContentState extends ConsumerState<_HomeShellContent> {
  static const _tabs = [
    HomeTab(),
    OrdersTab(),
    HistoryTab(),
    EarningsTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    // Watch for new incoming offer and show bottom sheet
    ref.listen<RiderDashboardState>(riderDashboardProvider, (prev, next) {
      if (next.newOfferId != null &&
          next.newOfferId != prev?.newOfferId &&
          !next.hasActiveOrder && // don't interrupt an active delivery
          mounted) {
        ref.read(riderDashboardProvider.notifier).clearNewOffer();
        final offer = next.pendingOffers.firstWhere(
          (o) => o['id']?.toString() == next.newOfferId,
          orElse: () => next.pendingOffers.isNotEmpty
              ? next.pendingOffers.first
              : <String, dynamic>{},
        );
        if (offer.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => IncomingOrderSheet(
                offer: offer,
                onAccept: () async {
                  Navigator.pop(context);
                  await ref
                      .read(riderDashboardProvider.notifier)
                      .acceptOffer(offer);
                },
                onReject: () async {
                  Navigator.pop(context);
                  await ref
                      .read(riderDashboardProvider.notifier)
                      .rejectOffer(offer);
                },
              ),
            );
          });
        }
      }

      // Offline-too-long reminder → ask the rider to go online.
      if (next.offlineReminder && !(prev?.offlineReminder ?? false) && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showDialog<void>(
            context: context,
            builder: (dctx) => AlertDialog(
              title: const Text('Still offline?'),
              content: const Text(
                  'You have been offline for a while. Would you like to go online?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dctx);
                    ref
                        .read(riderDashboardProvider.notifier)
                        .dismissOfflineReminder(reArm: true);
                  },
                  child: const Text('Stay Offline'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(dctx);
                    final n = ref.read(riderDashboardProvider.notifier);
                    n.dismissOfflineReminder();
                    // A profile photo is required to go online — send them to
                    // Profile to add one if they don't have one yet.
                    if (ref.read(riderDashboardProvider).needsProfilePhoto) {
                      ref.read(selectedHomeTabProvider.notifier).state = 4;
                    } else {
                      n.setStatus('online');
                    }
                  },
                  child: const Text('Go Online'),
                ),
              ],
            ),
          );
        });
      }
    });

    final cs = Theme.of(context).colorScheme;
    final index = ref.watch(selectedHomeTabProvider);
    return Scaffold(
      body: IndexedStack(index: index, children: _tabs),
      bottomNavigationBar: _BottomNav(
        index: index,
        onTap: (i) => ref.read(selectedHomeTabProvider.notifier).state = i,
        pendingOffers: ref.watch(
          riderDashboardProvider.select((s) => s.pendingOffers.length),
        ),
        activeOrders: ref.watch(
          riderDashboardProvider.select((s) => s.activeOrders.length),
        ),
        cs: cs,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.index,
    required this.onTap,
    required this.pendingOffers,
    required this.activeOrders,
    required this.cs,
  });

  final int index;
  final ValueChanged<int> onTap;
  final int pendingOffers;
  final int activeOrders;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final ordersBadge = (pendingOffers + activeOrders);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onTap,
        animationDuration: const Duration(milliseconds: 300),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Badge.count(
              count: ordersBadge,
              isLabelVisible: ordersBadge > 0,
              child: const Icon(Icons.delivery_dining_outlined),
            ),
            selectedIcon: Badge.count(
              count: ordersBadge,
              isLabelVisible: ordersBadge > 0,
              child: const Icon(Icons.delivery_dining_rounded),
            ),
            label: 'Orders',
          ),
          const NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          const NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Earnings',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
