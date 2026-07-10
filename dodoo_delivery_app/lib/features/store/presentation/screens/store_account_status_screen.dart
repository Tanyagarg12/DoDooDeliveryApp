import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/store_categories.dart';
import '../../../../core/widgets/support_modal.dart';
import '../../domain/entities/store_entity.dart';
import '../controllers/store_auth_controller.dart';
import '../controllers/store_auth_state.dart';
import 'store_home_shell.dart';
import 'store_phone_input_screen.dart';
import 'store_registration_screen.dart';

/// Shown while a store is pending / rejected / suspended. Refreshes on resume
/// and via the manual button; reacts live to status changes (e.g. admin
/// approval → dashboard, or pending → rejected → re-apply).
class StoreAccountStatusScreen extends ConsumerStatefulWidget {
  const StoreAccountStatusScreen({super.key, required this.store});

  final StoreEntity store;

  @override
  ConsumerState<StoreAccountStatusScreen> createState() =>
      _StoreAccountStatusScreenState();
}

class _StoreAccountStatusScreenState
    extends ConsumerState<StoreAccountStatusScreen>
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
          .read(storeAuthControllerProvider.notifier)
          .refreshStatus(widget.store);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  ({Color color, Color bg, IconData icon, String title, String msg}) _cfg(
      String status) {
    switch (status) {
      case 'approved':
        return (
          color: const Color(0xFF059669),
          bg: const Color(0xFFF0FDF4),
          icon: Icons.check_circle_rounded,
          title: 'Store Approved!',
          msg: 'Your store is live. You can start receiving orders.'
        );
      case 'rejected':
        return (
          color: const Color(0xFFDC2626),
          bg: const Color(0xFFFFF5F5),
          icon: Icons.cancel_rounded,
          title: 'Application Rejected',
          msg: 'We couldn\'t approve your store. You can re-apply with fresh '
              'details below.'
        );
      case 'suspended':
        return (
          color: const Color(0xFFEA580C),
          bg: const Color(0xFFFFF7ED),
          icon: Icons.block_rounded,
          title: 'Store Suspended',
          msg: 'Your store is suspended. Contact support to resolve this.'
        );
      default:
        return (
          color: const Color(0xFFD97706),
          bg: const Color(0xFFFFFBEB),
          icon: Icons.hourglass_top_rounded,
          title: 'Under Review',
          msg: 'Your store is being reviewed by our team. We\'ll notify you '
              'once it\'s approved.'
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<StoreAuthState>(storeAuthControllerProvider, (_, next) {
      if (next is! StoreAuthAuthenticated || !mounted) return;
      // Already-onboarded store → straight to home. A first-time approval
      // (hasStarted == false) instead re-renders this screen as approved so
      // the one-time "Store Approved! → Start" welcome shows.
      if (next.store.isApproved && next.store.hasStarted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => StoreHomeShell(store: next.store)),
          (r) => false,
        );
      } else if (next.store.accountStatus != widget.store.accountStatus) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StoreAccountStatusScreen(store: next.store),
          ),
        );
      }
    });

    final store = widget.store;
    final cfg = _cfg(store.accountStatus);

    return Scaffold(
      backgroundColor: cfg.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1C00),
        actions: const [SupportIconButton()],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
              Container(
                width: 120,
                height: 120,
                decoration:
                    BoxDecoration(color: cfg.bg, shape: BoxShape.circle),
                child: Icon(cfg.icon, size: 64, color: cfg.color),
              ),
              const SizedBox(height: 28),
              Text(cfg.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 25, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(cfg.msg,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15, color: Colors.grey.shade700, height: 1.5)),
              if (_refreshing) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 2,
                  child: LinearProgressIndicator(
                    backgroundColor: cfg.color.withValues(alpha: 0.1),
                    color: cfg.color,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if ((store.adminComment ?? '').trim().isNotEmpty)
                _CommentBox(text: store.adminComment!.trim()),
              _DetailCard(store: store, color: cfg.color),
              const Spacer(flex: 3),
              _Actions(
                store: store,
                color: cfg.color,
                refreshing: _refreshing,
                onRefresh: _refresh,
              ),
              const SizedBox(height: 16),
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

class _CommentBox extends StatelessWidget {
  const _CommentBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
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
              Icon(Icons.campaign_rounded, size: 16, color: Color(0xFFB45309)),
              SizedBox(width: 6),
              Text('Message from DoDoo',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF92400E))),
            ],
          ),
          const SizedBox(height: 6),
          Text(text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF92400E))),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.store, required this.color});
  final StoreEntity store;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          _row('Store', store.storeName.isEmpty ? '—' : store.storeName),
          const Divider(height: 20),
          _row('Category', StoreCategories.labelFor(store.category)),
          const Divider(height: 20),
          _row('Owner', store.ownerName.isEmpty ? '—' : store.ownerName),
          const Divider(height: 20),
          _row('Mobile', '+91 ${store.phone}'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      );
}

class _Actions extends ConsumerWidget {
  const _Actions({
    required this.store,
    required this.color,
    required this.refreshing,
    required this.onRefresh,
  });
  final StoreEntity store;
  final Color color;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        if (store.isApproved) ...[
          FilledButton.icon(
            onPressed: () async {
              final navigator = Navigator.of(context);
              // Record the one-time welcome as seen, then enter the app.
              await ref
                  .read(storeAuthControllerProvider.notifier)
                  .markStarted(store);
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(
                    builder: (_) =>
                        StoreHomeShell(store: store.copyWith(hasStarted: true))),
                (r) => false,
              );
            },
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Start'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (store.isPending) ...[
          FilledButton.icon(
            onPressed: refreshing ? null : onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Check Status Now'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _openRegistration(context),
            icon: const Icon(Icons.edit_document),
            label: const Text('Update my details'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: const Color(0xFFD97706),
              side: const BorderSide(color: Color(0xFFD97706)),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (store.isRejected) ...[
          FilledButton.icon(
            onPressed: () => _openRegistration(context),
            icon: const Icon(Icons.assignment_turned_in_rounded),
            label: const Text('Re-apply with fresh details'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              minimumSize: const Size.fromHeight(50),
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
            foregroundColor: Colors.grey.shade700,
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => showSupportSheet(context),
          child: Text('Contact Support', style: TextStyle(color: color)),
        ),
      ],
    );
  }

  void _openRegistration(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoreRegistrationScreen(phone: store.phone),
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(storeAuthControllerProvider.notifier).logout();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const StorePhoneInputScreen()),
        (r) => false,
      );
    }
  }
}
