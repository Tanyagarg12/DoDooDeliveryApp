import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/firebase/store_order_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/support_modal.dart';

class StoreOrderDetailScreen extends StatefulWidget {
  const StoreOrderDetailScreen({
    super.key,
    required this.orderId,
    this.orderData,
  });
  final String orderId;
  final Map<String, dynamic>? orderData;

  @override
  State<StoreOrderDetailScreen> createState() => _StoreOrderDetailScreenState();
}

class _StoreOrderDetailScreenState extends State<StoreOrderDetailScreen> {
  final _svc = StoreOrderService.instance;
  bool _busy = false;
  Map<String, dynamic>? _order;

  @override
  void initState() {
    super.initState();
    _order = widget.orderData;
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text('Something went wrong. Try again.'),
              backgroundColor: Colors.red.shade700),
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _confirmCancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Cancel order?'),
        content: const Text('This order will be cancelled.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _run(
        () => _svc.updateDodooOrderStatus(
          orderId: widget.orderId,
          newStatus: 'cancelled',
          orderType: _order?['order_type']?.toString(),
        ),
        'Order cancelled.',
      );
    }
  }

  Future<void> _dial(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return;
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        title: const Text('Order Details',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: const [SupportIconButton()],
      ),
      body: _order == null
          ? const Center(child: CircularProgressIndicator())
          : _body(_order!),
    );
  }

  Widget _body(Map<String, dynamic> data) {
    final status = data['status']?.toString() ?? '';
    final phone = data['customer_phone']?.toString() ?? '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _statusHero(data, status),
        const SizedBox(height: 16),
        _sectionTitle('Customer'),
        const SizedBox(height: 10),
        _card([
          _iconRow(Icons.person_rounded, 'Name',
              data['customer_name']?.toString() ?? '—'),
          const SizedBox(height: 12),
          _iconRow(Icons.location_on_rounded, 'Deliver to',
              data['to_address']?.toString() ?? '—'),
          if (phone.trim().isNotEmpty && phone.trim() != '—') ...[
            const SizedBox(height: 14),
            _callButton(phone),
          ],
        ]),
        const SizedBox(height: 16),
        _sectionTitle('Order summary'),
        const SizedBox(height: 10),
        _card([
          _kv('Order #', '#${data['order_number'] ?? '—'}'),
          const SizedBox(height: 10),
          _kv('Items', data['items_summary']?.toString() ?? '—'),
          if (data['order_amount'] != null ||
              data['store_earning'] != null ||
              data['total_earning'] != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFEDEFE0)),
            const SizedBox(height: 12),
            if (data['order_amount'] != null)
              _kv('Bill amount', '₹${data['order_amount']}'),
            if (data['store_earning'] != null) ...[
              const SizedBox(height: 8),
              _kv('You earn', '₹${data['store_earning']}', highlight: true),
            ],
            if (data['total_earning'] != null) ...[
              const SizedBox(height: 8),
              _kv('Rider payout', '₹${data['total_earning']}'),
            ],
          ],
        ]),
        const SizedBox(height: 22),
        _actions(status),
      ],
    );
  }

  // ── Status hero ─────────────────────────────────────────────────────────────

  Widget _statusHero(Map<String, dynamic> data, String status) {
    final color = StoreOrderStatus.color(status);
    final dark = Color.lerp(color, Colors.black, 0.18)!;
    final earn = data['store_earning'] ?? data['order_amount'];
    final lower = status.toLowerCase();
    final cancelled = lower == 'cancel' || lower == 'cancelled';
    final finished = StoreOrderStatus.isFinished(status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, dark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                    finished
                        ? (cancelled
                            ? Icons.cancel_rounded
                            : Icons.check_circle_rounded)
                        : Icons.receipt_long_rounded,
                    color: Colors.white,
                    size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(StoreOrderStatus.label(status),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text('#${data['order_number'] ?? ''}',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.85))),
                  ],
                ),
              ),
            ],
          ),
          if (earn != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Text('Your earning',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('₹$earn',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Actions (logic preserved) ───────────────────────────────────────────────

  Widget _actions(String status) {
    if (_busy) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
    }
    // DoDoo order statuses: open, accept, inprogress, deliver, cancel
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'open':
        return Column(
          children: [
            _primary('Accept order', Icons.check_circle_rounded,
                const Color(0xFF059669), () {
              _run(
                () => _svc.updateDodooOrderStatus(
                  orderId: widget.orderId,
                  newStatus: 'accepted',
                  orderType: _order?['order_type']?.toString(),
                ),
                'Order accepted.',
              );
            }),
            const SizedBox(height: 10),
            _outlinedCancel(),
          ],
        );
      case 'accept':
        return Column(
          children: [
            _primary('Mark In Progress', Icons.hourglass_bottom_rounded,
                AppColors.primary, () {
              _run(
                () => _svc.updateDodooOrderStatus(
                  orderId: widget.orderId,
                  newStatus: 'in_progress',
                  orderType: _order?['order_type']?.toString(),
                ),
                'Marked in progress.',
              );
            }),
            const SizedBox(height: 10),
            _outlinedCancel(),
          ],
        );
      case 'inprogress':
      case 'deliver':
        return _infoBanner('Order is being delivered.');
      case 'cancel':
        return _infoBanner('This order has been cancelled.');
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _primary(String label, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _outlinedCancel() => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _confirmCancel,
          icon: const Icon(Icons.close_rounded, size: 18),
          label: const Text('Cancel order',
              style: TextStyle(fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
            minimumSize: const Size.fromHeight(50),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );

  Widget _infoBanner(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: Color(0xFF2563EB), size: 18),
            const SizedBox(width: 10),
            Expanded(
                child: Text(text,
                    style: const TextStyle(
                        color: Color(0xFF1E40AF),
                        fontSize: 13,
                        fontWeight: FontWeight.w600))),
          ],
        ),
      );

  // ── Building blocks ───────────────────────────────────────────────────────

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade700)),
      );

  Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEDEFE0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  Widget _iconRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: AppColors.accent),
        ),
        const SizedBox(width: 12),
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
              Text(value,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _callButton(String phone) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _dial(phone),
        icon: const Icon(Icons.call_rounded, size: 18),
        label: Text('Call $phone',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF2563EB),
          side: const BorderSide(color: Color(0xFF2563EB)),
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _kv(String label, String value, {bool highlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
                  fontSize: highlight ? 15 : 13.5,
                  color: highlight ? AppColors.accent : Colors.black87)),
        ),
      ],
    );
  }
}
