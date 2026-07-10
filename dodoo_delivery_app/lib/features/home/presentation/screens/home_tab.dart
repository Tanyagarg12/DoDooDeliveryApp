import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/support_modal.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/screens/phone_input_screen.dart';
import '../../../notifications/presentation/notifications_screen.dart';
import '../controllers/rider_dashboard_controller.dart';
import '../controllers/rider_dashboard_state.dart';
import '../widgets/order_card.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(riderDashboardProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(riderDashboardProvider.notifier).refresh(showLoading: true),
        color: cs.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _HomeAppBar(state: state, isDark: isDark),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 20),
                  _StatusCard(state: state, isDark: isDark),
                  const SizedBox(height: 16),
                  _TodayStatsRow(state: state),
                  if (state.hasActiveOrder) ...[
                    const SizedBox(height: 20),
                    _SectionHeader(
                        title: 'Active Order',
                        icon: Icons.delivery_dining_rounded,
                        color: cs.primary),
                    const SizedBox(height: 8),
                    ActiveOrderCard(
                        order: state.activeOrders.first,
                        isLoading: state.isLoading),
                  ],
                  // Offers are hidden while on an active delivery — one at a time.
                  if (state.hasPendingOffers && !state.hasActiveOrder) ...[
                    const SizedBox(height: 20),
                    _SectionHeader(
                        title: 'Incoming Offers',
                        icon: Icons.notifications_active_rounded,
                        color: AppColors.busy),
                    const SizedBox(height: 8),
                    ...state.pendingOffers.map((o) => _OfferCard(offer: o)),
                  ],
                  if (!state.hasActiveOrder && !state.hasPendingOffers) ...[
                    const SizedBox(height: 24),
                    _IdleCard(status: state.currentStatus),
                  ],
                  if (state.error != null) ...[
                    const SizedBox(height: 12),
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

// ── App Bar ───────────────────────────────────────────────────────────────────

class _HomeAppBar extends ConsumerWidget {
  const _HomeAppBar({required this.state, required this.isDark});
  final RiderDashboardState state;
  final bool isDark;

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(authControllerProvider.notifier).logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PhoneInputScreen()),
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
              // DoDoo wordmark (replaces the greeting).
              Image.asset(
                'assets/images/dodoo_status.png',
                height: 30,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const AppLogo(size: 36),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () =>
                    ref.read(selectedHomeTabProvider.notifier).state = 3,
                child: _WalletBadge(balance: state.walletBalance),
              ),
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
      toolbarHeight: 80,
    );
  }
}

class _WalletBadge extends StatelessWidget {
  const _WalletBadge({required this.balance});
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
          const Icon(Icons.account_balance_wallet_rounded,
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

// ── Status Card ───────────────────────────────────────────────────────────────

class _StatusCard extends ConsumerStatefulWidget {
  const _StatusCard({required this.state, required this.isDark});
  final RiderDashboardState state;
  final bool isDark;

  @override
  ConsumerState<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends ConsumerState<_StatusCard>
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
    final status = widget.state.currentStatus;
    final isLoading = widget.state.isStatusLoading;
    final gradient = AppGradients.statusGradient(status, widget.isDark);
    final statusColor = _statusColor(status);
    final statusLabel = _label(status);
    final statusSubtitle = _subtitle(status);

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
              // Animated pulsing dot
              if (status == 'online')
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
                  statusLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            statusSubtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),

          // Status selector — locked to 'Busy' during an active delivery.
          if (widget.state.hasActiveOrder)
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
                      'On delivery — status locked until the order is completed',
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
                _StatusChip(
                  label: 'Offline',
                  icon: Icons.power_settings_new_rounded,
                  isSelected: status == 'offline',
                  onTap: isLoading
                      ? null
                      : () => ref
                          .read(riderDashboardProvider.notifier)
                          .setStatus('offline'),
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  label: 'Online',
                  icon: Icons.check_circle_rounded,
                  isSelected: status == 'online',
                  onTap: isLoading ? null : () => _goOnline(context),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Goes online, but first requires a profile photo. A rider with no photo
  /// (and none pending) is sent to their Profile to add one instead.
  void _goOnline(BuildContext context) {
    if (widget.state.needsProfilePhoto) {
      _promptForPhoto(context);
      return;
    }
    ref.read(riderDashboardProvider.notifier).setStatus('online');
  }

  void _promptForPhoto(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dCtx) => AlertDialog(
        icon: const Icon(Icons.add_a_photo_rounded, color: AppColors.primary),
        title: const Text('Profile photo required'),
        content: const Text(
          'Please add a profile photo before going online. You can add it in '
          'your Profile — you\'ll be able to go online as soon as it\'s added.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dCtx);
              // Jump to the Profile tab (index 4 on the home shell).
              ref.read(selectedHomeTabProvider.notifier).state = 4;
            },
            child: const Text('Go to Profile'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'online':
        return AppColors.online;
      case 'busy':
        return const Color(0xFF4F46E5); // friendly indigo, not warning-orange
      default:
        return AppColors.offline;
    }
  }

  String _label(String s) {
    switch (s) {
      case 'online':
        return 'ONLINE';
      case 'busy':
        return 'ON DELIVERY';
      default:
        return 'OFFLINE';
    }
  }

  String _subtitle(String s) {
    switch (s) {
      case 'online':
        return 'You are available for new orders';
      case 'busy':
        return 'You are on a delivery';
      default:
        return 'Go online to receive orders';
    }
  }
}

class _PulsingDot extends StatelessWidget {
  const _PulsingDot({required this.controller, required this.color});
  final AnimationController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final pulse = (math.sin(controller.value * 2 * math.pi) + 1) / 2;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 12 + pulse * 10,
              height: 12 + pulse * 10,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.3 * (1 - pulse)),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 12,
              height: 12,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ],
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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

// ── Today stats row ───────────────────────────────────────────────────────────

class _TodayStatsRow extends StatelessWidget {
  const _TodayStatsRow({required this.state});
  final RiderDashboardState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.currency_rupee_rounded,
            iconColor: AppColors.online,
            iconBg: AppColors.onlineBg,
            label: "Today's Earn",
            value: '₹${state.todayEarnings.toStringAsFixed(0)}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.local_shipping_rounded,
            iconColor: AppColors.primary,
            iconBg: AppColors.primaryContainer,
            label: "Today's Orders",
            value: '${state.todayOrders}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.star_rounded,
            iconColor: AppColors.amber,
            iconBg: AppColors.amberContainer,
            label: 'Rating',
            value: state.rating.toStringAsFixed(1),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE8F0EE),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isDark ? iconColor.withValues(alpha: 0.15) : iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Idle card ─────────────────────────────────────────────────────────────────

class _IdleCard extends StatelessWidget {
  const _IdleCard({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final isOffline = status == 'offline';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE8F0EE),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isOffline
                  ? AppColors.offlineBg
                  : AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOffline
                  ? Icons.power_settings_new_rounded
                  : Icons.delivery_dining_rounded,
              size: 40,
              color:
                  isOffline ? AppColors.offline : AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isOffline ? 'You are offline' : 'No orders yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isOffline
                ? 'Switch to Online to start receiving delivery requests'
                : 'Stay online — new orders will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Offer card on Home ────────────────────────────────────────────────────────

class _OfferCard extends ConsumerWidget {
  const _OfferCard({required this.offer});
  final Map<String, dynamic> offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order =
        Map<String, dynamic>.from(offer['order'] ?? offer);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.busy.withValues(alpha: 0.12)
            : AppColors.busyBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.busy.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.busy.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.notifications_active_rounded,
                    size: 18, color: AppColors.busy),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'New Order #${order['order_number'] ?? '—'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              _EarningBadge(
                value:
                    order['total_earning'] ?? order['minimum_fare'] ?? '0',
              ),
            ],
          ),
          const SizedBox(height: 10),
          _RouteRow(
            from: order['from_address']?.toString() ?? '—',
            to: order['to_address']?.toString() ?? '—',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 48,
                height: 44,
                child: OutlinedButton(
                  onPressed: () => ref
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
                  onPressed: () async {
                    await ref
                        .read(riderDashboardProvider.notifier)
                        .acceptOffer(offer);
                  },
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text('Accept Order',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor: AppColors.online,
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
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
      {required this.title, required this.icon, required this.color});
  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.from, required this.to});
  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Column(
          children: [
            Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle)),
            Container(width: 2, height: 28, color: AppColors.primary.withValues(alpha: 0.3)),
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    border: Border.all(color: AppColors.busy, width: 2),
                    shape: BoxShape.circle)),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                from,
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Text(
                to,
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EarningBadge extends StatelessWidget {
  const _EarningBadge({required this.value});
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: const BoxDecoration(
        gradient: AppGradients.brandSplash,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Text(
        '₹$value',
        style: const TextStyle(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
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
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
