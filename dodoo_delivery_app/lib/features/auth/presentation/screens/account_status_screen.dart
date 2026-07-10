import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/support_modal.dart';
import '../../domain/entities/rider_entity.dart';
import '../controllers/auth_controller.dart';
import '../controllers/auth_state.dart';
import 'rider_registration_screen.dart';

/// Shown when a rider's account is pending, rejected, or suspended.
/// Refreshes on app-resume and via the manual "Check Status Now" button — no
/// background polling, to keep server load low.
class AccountStatusScreen extends ConsumerStatefulWidget {
  const AccountStatusScreen({super.key, required this.rider});

  final RiderEntity rider;

  @override
  ConsumerState<AccountStatusScreen> createState() =>
      _AccountStatusScreenState();
}

class _AccountStatusScreenState extends ConsumerState<AccountStatusScreen>
    with WidgetsBindingObserver {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (_refreshing || !mounted) return;
    setState(() => _refreshing = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .refreshStatus(widget.rider);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // React to status changes detected on refresh (resume / "Check Status Now"):
    //  • approved            → go straight to the dashboard
    //  • any other change     → rebuild this screen with the new status so the
    //    right actions show (e.g. Re-apply appears when pending → rejected).
    ref.listen<AuthState>(authControllerProvider, (_, next) {
      if (next is! AuthAuthenticated || !mounted) return;
      if (next.rider.isApproved) {
        Navigator.pushNamedAndRemoveUntil(
            context, '/home', (r) => false, arguments: next.rider);
      } else if (next.rider.accountStatus != widget.rider.accountStatus) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AccountStatusScreen(rider: next.rider),
          ),
        );
      }
    });

    final config = _statusConfig(widget.rider.accountStatus);

    return Scaffold(
      backgroundColor: config.bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              _StatusIllustration(config: config),
              const SizedBox(height: 32),
              Text(
                config.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                config.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              if (_refreshing) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 2,
                  child: LinearProgressIndicator(
                    backgroundColor: config.accentColor.withValues(alpha: 0.1),
                    color: config.accentColor,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if ((widget.rider.adminComment ?? '').trim().isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.campaign_rounded,
                              size: 16, color: Color(0xFFB45309)),
                          SizedBox(width: 6),
                          Text('Message from DoDoo',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF92400E))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(widget.rider.adminComment!.trim(),
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF92400E))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _DetailCard(rider: widget.rider, config: config),
              if (widget.rider.isPending) ...[
                const SizedBox(height: 8),
                Text(
                  'Tap "Check Status Now" to refresh',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
              const Spacer(flex: 3),
              _ActionButtons(
                rider: widget.rider,
                ref: ref,
                config: config,
                onManualRefresh: _refresh,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  _StatusConfig _statusConfig(AccountStatus status) {
    switch (status) {
      case AccountStatus.pending:
        return const _StatusConfig(
          title: 'Under Review',
          subtitle:
              'Your registration is being reviewed by our team.\nWe\'ll notify you once approved.',
          icon: Icons.hourglass_top_rounded,
          iconColor: Color(0xFFD97706),
          badgeColor: Color(0xFFFEF3C7),
          bgColor: Color(0xFFFFFBEB),
          accentColor: Color(0xFFD97706),
          statusLabel: 'Pending Approval',
        );
      case AccountStatus.approved:
        return const _StatusConfig(
          title: 'Account Approved!',
          subtitle:
              'Congratulations! Your account has been approved.\nYou can now start accepting orders.',
          icon: Icons.check_circle_rounded,
          iconColor: Color(0xFF059669),
          badgeColor: Color(0xFFD1FAE5),
          bgColor: Color(0xFFF0FDF4),
          accentColor: Color(0xFF059669),
          statusLabel: 'Approved',
        );
      case AccountStatus.rejected:
        return const _StatusConfig(
          title: 'Application Rejected',
          subtitle:
              'We were unable to approve your application.\nYou can re-apply below with fresh details.',
          icon: Icons.cancel_rounded,
          iconColor: Color(0xFFDC2626),
          badgeColor: Color(0xFFFEE2E2),
          bgColor: Color(0xFFFFF5F5),
          accentColor: Color(0xFFDC2626),
          statusLabel: 'Rejected',
        );
      case AccountStatus.suspended:
        return const _StatusConfig(
          title: 'Account Suspended',
          subtitle:
              'Your account has been suspended.\nContact support to resolve this issue.',
          icon: Icons.block_rounded,
          iconColor: Color(0xFFEA580C),
          badgeColor: Color(0xFFFFEDD5),
          bgColor: Color(0xFFFFF7ED),
          accentColor: Color(0xFFEA580C),
          statusLabel: 'Suspended',
        );
    }
  }
}

// ── Status models ─────────────────────────────────────────────────────────────

class _StatusConfig {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color badgeColor;
  final Color bgColor;
  final Color accentColor;
  final String statusLabel;

  const _StatusConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.badgeColor,
    required this.bgColor,
    required this.accentColor,
    required this.statusLabel,
  });
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatusIllustration extends StatelessWidget {
  const _StatusIllustration({required this.config});
  final _StatusConfig config;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: config.badgeColor,
        shape: BoxShape.circle,
      ),
      child: Icon(config.icon, size: 64, color: config.iconColor),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.rider, required this.config});
  final RiderEntity rider;
  final _StatusConfig config;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: config.accentColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _Row(label: 'Name', value: rider.fullName),
          const Divider(height: 20),
          _Row(label: 'Mobile', value: '+91 ${rider.phone}'),
          const Divider(height: 20),
          _Row(
            label: 'Status',
            value: config.statusLabel,
            valueStyle: TextStyle(
              fontWeight: FontWeight.bold,
              color: config.iconColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.valueStyle});
  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        Text(
          value,
          style: valueStyle ??
              const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
                fontSize: 13,
              ),
        ),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.rider,
    required this.ref,
    required this.config,
    required this.onManualRefresh,
  });

  final RiderEntity rider;
  final WidgetRef ref;
  final _StatusConfig config;
  final VoidCallback onManualRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (rider.isApproved)
          FilledButton.icon(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context, '/home', (r) => false,
                arguments: rider),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Go to Dashboard'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        if (rider.isPending) ...[
          FilledButton.icon(
            onPressed: onManualRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Check Status Now'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 12),
          // Lets a rider respond to an admin note while still under review by
          // re-submitting their details (which also clears the note).
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RiderRegistrationScreen(phone: rider.phone),
              ),
            ),
            icon: const Icon(Icons.edit_document),
            label: const Text('Update my details'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              foregroundColor: const Color(0xFFD97706),
              side: const BorderSide(color: Color(0xFFD97706)),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (rider.isRejected) ...[
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RiderRegistrationScreen(phone: rider.phone),
              ),
            ),
            icon: const Icon(Icons.assignment_turned_in_rounded),
            label: const Text('Re-apply with fresh details'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: () => _logout(context, ref),
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            foregroundColor: Colors.grey.shade700,
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        if (rider.isRejected || rider.isSuspended) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => showSupportSheet(context),
            child: Text(
              'Contact Support',
              style: TextStyle(color: config.iconColor),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).logout();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
    }
  }
}
