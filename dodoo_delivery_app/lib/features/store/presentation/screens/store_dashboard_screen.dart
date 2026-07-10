import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/store_order_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/support_modal.dart';
import '../../../notifications/presentation/notifications_screen.dart';
import '../../domain/entities/store_entity.dart';
import '../controllers/store_auth_controller.dart';
import '../controllers/store_dashboard_controller.dart';
import '../controllers/store_dashboard_state.dart';
import 'store_phone_input_screen.dart';

class StoreDashboardScreen extends ConsumerWidget {
  const StoreDashboardScreen({super.key, required this.store});
  final StoreEntity store;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(storeDashboardProvider(store));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(storeDashboardProvider(store).notifier).refresh(showLoading: true),
        color: cs.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _DashboardAppBar(state: state),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 20),
                  _StoreStatusCard(store: store, state: state),
                  const SizedBox(height: 20),
                  _TodayStatsRow(state: state),
                  if (state.hasActiveOrders) ...[
                    const SizedBox(height: 24),
                    _SectionHeader(
                      title: 'Active Orders (${state.activeOrdersCount})',
                      icon: Icons.receipt_long_rounded,
                    ),
                    const SizedBox(height: 12),
                    ...state.activeOrders.map((o) => _ActiveOrderCard(order: o)),
                  ] else ...[
                    const SizedBox(height: 32),
                    _IdleCard(isOpen: state.isStoreOpen),
                  ],
                  if (state.error != null) ...[
                    const SizedBox(height: 16),
                    _ErrorBanner(state.error!),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardAppBar extends ConsumerWidget {
  const _DashboardAppBar({required this.state});
  final StoreDashboardState state;

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(storeAuthControllerProvider.notifier).logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const StorePhoneInputScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      snap: true,
      pinned: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      flexibleSpace: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
        child: SafeArea(
          child: Row(
            children: [
              Image.asset(
                'assets/images/dodoo_status.png',
                height: 30,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const AppLogo(size: 36),
              ),
              const Spacer(),
              // Tapping the earnings badge jumps to the Wallet tab.
              GestureDetector(
                onTap: () =>
                    ref.read(selectedStoreTabProvider.notifier).state = 3,
                child: _EarningsBadge(balance: state.todayEarnings),
              ),
              const SizedBox(width: 8),
              const NotificationBell(),
              PopupMenuButton<String>(
                tooltip: 'Menu',
                icon: const Icon(Icons.more_vert_rounded),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (v) {
                  if (v == 'support') {
                    showSupportSheet(context);
                  } else if (v == 'logout') {
                    _logout(context, ref);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'support',
                    child: Row(children: [
                      Icon(Icons.support_agent_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Help & Support'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(children: [
                      Icon(Icons.logout_rounded,
                          size: 18, color: AppColors.error),
                      SizedBox(width: 10),
                      Text('Logout',
                          style: TextStyle(color: AppColors.error)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      toolbarHeight: 70,
    );
  }
}

class _EarningsBadge extends StatelessWidget {
  const _EarningsBadge({required this.balance});
  final double balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: AppGradients.brandSplash,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLight.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.trending_up_rounded,
              size: 16, color: AppColors.onPrimary),
          const SizedBox(width: 6),
          Text(
            '₹${balance.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreStatusCard extends ConsumerStatefulWidget {
  const _StoreStatusCard({required this.store, required this.state});

  /// The STABLE store from the screen — used as the provider family key so
  /// taps always target the controller the screen is watching. (Do not use
  /// state.store here: it's a fresh instance after every toggle, which would
  /// point at a different family instance and silently break the button.)
  final StoreEntity store;
  final StoreDashboardState state;

  @override
  ConsumerState<_StoreStatusCard> createState() => _StoreStatusCardState();
}

class _StoreStatusCardState extends ConsumerState<_StoreStatusCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = widget.state.isStoreOpen;
    final hasActiveOrders = widget.state.hasActiveOrders;

    final gradient = isOpen
        ? LinearGradient(
            colors: [const Color(0xFF059669), const Color(0xFF10B981)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight)
        : LinearGradient(
            colors: [Colors.grey.shade600, Colors.grey.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight);

    final statusColor =
        isOpen ? const Color(0xFF059669) : Colors.grey.shade600;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isOpen)
                _PulsingDot(controller: _pulseCtrl, color: Colors.white)
              else
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isOpen ? 'OPEN' : 'CLOSED',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isOpen ? 'Ready to accept orders' : 'Not accepting orders right now',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          if (hasActiveOrders)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'You have active orders — status locked',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                _StoreStatusChip(
                  label: 'Closed',
                  icon: Icons.power_settings_new_rounded,
                  isSelected: !isOpen,
                  onTap: () => ref
                      .read(storeDashboardProvider(widget.store).notifier)
                      .setStoreOpen(false),
                ),
                const SizedBox(width: 8),
                _StoreStatusChip(
                  label: 'Open',
                  icon: Icons.check_circle_rounded,
                  isSelected: isOpen,
                  onTap: () => ref
                      .read(storeDashboardProvider(widget.store).notifier)
                      .setStoreOpen(true),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StoreStatusChip extends StatelessWidget {
  const _StoreStatusChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.black87 : Colors.white,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.black87 : Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingDot extends StatelessWidget {
  const _PulsingDot({required this.controller, required this.color});
  final AnimationController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _TodayStatsRow extends StatelessWidget {
  const _TodayStatsRow({required this.state});
  final StoreDashboardState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: "Today's Earnings",
            value: '₹${state.todayEarnings.toStringAsFixed(0)}',
            icon: Icons.trending_up_rounded,
            color: const Color(0xFF059669),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Active',
            value: '${state.activeOrdersCount}',
            icon: Icons.receipt_long_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Completed',
            value: '${state.completedOrdersCount}',
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF2563EB),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order});
  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final status = order['status']?.toString() ?? '';
    final color = StoreOrderStatus.color(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8F0EE), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.receipt_long_rounded, size: 17, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${order['order_number'] ?? ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      order['customer_name']?.toString() ?? '—',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  StoreOrderStatus.label(status),
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            order['to_address']?.toString() ?? '—',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
          ),
          if ((order['store_earning'] ?? 0) > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'You earn ₹${(order['store_earning'] ?? 0).toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF059669),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IdleCard extends StatelessWidget {
  const _IdleCard({required this.isOpen});
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isOpen ? const Color(0xFFF0FDF4) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOpen ? const Color(0xFFC6F6D5) : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isOpen ? const Color(0xFF059669) : Colors.grey)
                .withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            isOpen ? Icons.hourglass_empty_rounded : Icons.pause_circle_rounded,
            size: 56,
            color: isOpen ? const Color(0xFF059669) : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            isOpen ? 'Waiting for orders' : 'Store is closed',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isOpen ? const Color(0xFF059669) : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isOpen
                ? 'Orders will appear here when customers order from you'
                : 'Toggle above to open your store and start accepting orders',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFDC2626),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
