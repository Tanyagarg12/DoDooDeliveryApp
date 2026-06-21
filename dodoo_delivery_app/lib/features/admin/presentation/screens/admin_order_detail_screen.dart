import 'package:flutter/material.dart';

import '../../../../core/constants/order_status.dart';
import '../../../../core/firebase/admin_firestore_service.dart';
import '../../../../core/widgets/support_modal.dart';
import '../../../orders_api/data/dodoo_order_api.dart';

/// Admin order detail — full order info plus management actions:
/// cancel, reassign to a specific rider, or re-broadcast to all riders.
class AdminOrderDetailScreen extends StatefulWidget {
  const AdminOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  static const _teal = Color(0xFFBABC2F);

  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _riders = [];
  final Map<String, Map<String, dynamic>> _riderById = {};
  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool _changed = false; // whether to tell the list to refresh on pop

  final _admin = AdminFirestoreService.instance;
  final _dodoo = DodooOrderApi();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final order = await _admin.getOrder(widget.orderId);
      _riders = await _admin.ridersForPicker();
      _riderById
        ..clear()
        ..addEntries(_riders.map((r) => MapEntry(r['id'].toString(), r)));
      _order = order;
      _error = _order == null ? 'Order not found' : null;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  String _riderName(String? id) {
    if (id == null) return 'Unassigned';
    final r = _riderById[id];
    if (r == null) return 'Rider';
    final n = '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim();
    return n.isEmpty ? 'Rider' : n;
  }

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> _update(Map<String, dynamic> patch, String successMsg) async {
    setState(() => _busy = true);
    try {
      await _admin.updateOrder(widget.orderId, patch);
      // Push the status change back to DoDoo (no-op until endpoint configured).
      final newStatus = patch['status']?.toString();
      if (newStatus != null) {
        _dodoo
            .pushStatus(
              orderId: _order?['order_number']?.toString() ?? '',
              internalStatus: newStatus,
              riderId: patch['assigned_rider_id']?.toString(),
            )
            .ignore();
      }
      _changed = true;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMsg), backgroundColor: _teal),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel order?'),
        content: const Text(
            'This marks the order as cancelled. The rider can no longer act on it.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _update({'status': 'cancelled', 'assigned_rider_id': null},
          'Order cancelled.');
    }
  }

  Future<void> _reassign() async {
    final approved =
        _riders.where((r) => r['account_status'] == 'approved').toList();
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => _RiderPickerSheet(riders: approved),
    );
    if (picked != null) {
      await _update(
        {'assigned_rider_id': picked, 'status': 'accepted'},
        'Reassigned to ${_riderName(picked)}.',
      );
    }
  }

  Future<void> _rebroadcast() async {
    setState(() => _busy = true);
    try {
      final approvedIds = _riders
          .where((r) => r['account_status'] == 'approved')
          .map((r) => r['id'].toString())
          .toList();
      // Reset to pending + unassigned, then clear & re-send offers.
      await _admin.updateOrder(widget.orderId, {
        'status': 'pending',
        'assigned_rider_id': null,
      });
      await _admin.rebroadcast(widget.orderId, approvedIds);
      _changed = true;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Re-broadcast to ${approvedIds.length} rider(s).'),
            backgroundColor: _teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7E8),
        appBar: AppBar(
          backgroundColor: _teal,
          foregroundColor: const Color(0xFF1C1D00),
          title: const Text('Order Detail',
              style: TextStyle(fontWeight: FontWeight.w700)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _changed),
          ),
          actions: const [SupportIconButton()],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _content(),
      ),
    );
  }

  Widget _content() {
    final o = _order!;
    final status = o['status']?.toString() ?? 'pending';
    final statusInfo = AdminOrderStatus.fromInternal(status);
    final assignedId = o['assigned_rider_id']?.toString();
    final canCancel = status != 'completed' && status != 'cancelled';
    final phone = o['customer_phone']?.toString() ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('#${o['order_number'] ?? '—'}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            _StatusBadge(status: status),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.circle, size: 9, color: statusInfo.color),
            const SizedBox(width: 6),
            Text(statusInfo.description,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: statusInfo.color)),
          ],
        ),
        const SizedBox(height: 16),

        _card('Route', [
          _line(Icons.store_rounded, _teal, 'Pickup',
              o['from_address']?.toString() ?? '—'),
          const SizedBox(height: 10),
          _line(Icons.location_on_rounded, const Color(0xFFDC2626), 'Drop',
              o['to_address']?.toString() ?? '—'),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(
                  child: _kv('Distance', '${o['distance_in_km'] ?? 0} km')),
              Expanded(
                  child: _kv('ETA', '${o['estimated_time_minutes'] ?? '—'} min')),
              Expanded(
                  child: _kv('Earning',
                      '₹${o['total_earning'] ?? o['minimum_fare'] ?? 0}')),
            ],
          ),
        ]),
        const SizedBox(height: 12),

        _card('Customer', [
          _kv('Name', o['customer_name']?.toString() ?? '—'),
          const SizedBox(height: 8),
          _kv('Phone (admin only)', phone.isEmpty ? '—' : phone),
          if ((o['store_name']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _kv('Store', o['store_name'].toString()),
          ],
          if ((o['payment_mode']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _kv('Payment', o['payment_mode'].toString()),
          ],
          if ((o['validation_code']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _kv('Delivery code', o['validation_code'].toString()),
          ],
        ]),
        const SizedBox(height: 12),

        _ItemsCard(order: o),
        const SizedBox(height: 12),

        _card('Assignment', [
          _kv('Assigned rider', _riderName(assignedId)),
          const SizedBox(height: 8),
          _kv('Updated',
              _fmt(o['status_updated_at']) ?? _fmt(o['created_at']) ?? '—'),
        ]),
        const SizedBox(height: 24),

        // Actions — only for orders that are still in progress.
        if (!canCancel)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: status == 'completed'
                  ? const Color(0xFFD1FAE5)
                  : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  status == 'completed'
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: status == 'completed'
                      ? const Color(0xFF059669)
                      : const Color(0xFFDC2626),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status == 'completed'
                        ? 'Completed — order delivered. No further action needed.'
                        : 'This order is cancelled.',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          )
        else ...[
          FilledButton.icon(
            onPressed: _busy ? null : _reassign,
            icon: const Icon(Icons.person_search_rounded),
            label: const Text('Reassign to a rider'),
            style: FilledButton.styleFrom(
                backgroundColor: _teal, minimumSize: const Size.fromHeight(50)),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _rebroadcast,
            icon: const Icon(Icons.campaign_rounded),
            label: const Text('Re-broadcast to all riders'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _teal,
              side: const BorderSide(color: _teal),
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _cancel,
            icon: const Icon(Icons.cancel_rounded),
            label: const Text('Cancel order'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              side: BorderSide(color: Colors.red.shade300),
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
        if (_busy) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Small builders ────────────────────────────────────────────────────

  Widget _card(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD7E3E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14, color: _teal)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _line(IconData icon, Color color, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 10, color: Colors.black54)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        const SizedBox(height: 2),
        Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  String? _fmt(dynamic ts) {
    if (ts == null) return null;
    final dt = DateTime.tryParse(ts.toString());
    if (dt == null) return null;
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)} ${two(l.hour)}:${two(l.minute)}';
  }
}

// ── Items + pricing card ──────────────────────────────────────────────────────

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.order});
  final Map<String, dynamic> order;

  static const _teal = Color(0xFFBABC2F);

  @override
  Widget build(BuildContext context) {
    final cart = (order['cart_items'] as List?) ?? const [];
    final desc = (order['items_description'] ?? '').toString();
    final hasPricing = order['items_subtotal'] != null ||
        order['delivery_charge'] != null ||
        order['tax'] != null ||
        order['order_total'] != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD7E3E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Items',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14, color: _teal)),
          const SizedBox(height: 12),
          if (cart.isEmpty && desc.isEmpty)
            const Text('—', style: TextStyle(fontSize: 13))
          else if (cart.isEmpty)
            Text(desc, style: const TextStyle(fontSize: 13))
          else
            ...cart.map((raw) {
              final i = Map<String, dynamic>.from(raw as Map);
              final t = (i['Title'] ?? 'Item').toString();
              final q = (i['Qty'] ?? '1').toString();
              final p = (i['Price'] ?? '').toString();
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('$t   ×$q',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    if (p.isNotEmpty)
                      Text('₹$p',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            }),
          if (hasPricing) ...[
            const Divider(height: 20),
            _priceRow('Items subtotal', order['items_subtotal']),
            _priceRow('Delivery charge', order['delivery_charge']),
            _priceRow('Tax', order['tax']),
            _priceRow('Total', order['order_total'], bold: true),
          ],
        ],
      ),
    );
  }

  Widget _priceRow(String label, dynamic value, {bool bold = false}) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: bold ? 14 : 12.5,
                    color: bold ? const Color(0xFF1C1D00) : Colors.black54,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
          ),
          Text('₹$value',
              style: TextStyle(
                  fontSize: bold ? 15 : 13,
                  fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
                  color: bold ? _teal : const Color(0xFF1C1D00))),
        ],
      ),
    );
  }
}

// ── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final info = AdminOrderStatus.fromInternal(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        info.label.toUpperCase(),
        style: TextStyle(
            color: info.color, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

// ── Rider picker sheet ───────────────────────────────────────────────────────

class _RiderPickerSheet extends StatelessWidget {
  const _RiderPickerSheet({required this.riders});
  final List<Map<String, dynamic>> riders;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('Select a rider',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          if (riders.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No approved riders available.')),
            ),
          ...riders.map((r) {
            final name =
                '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim();
            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFBABC2F),
                child: Icon(Icons.person, color: Color(0xFF1C1D00), size: 20),
              ),
              title: Text(name.isEmpty ? 'Rider' : name),
              subtitle: Text(r['phone']?.toString() ?? ''),
              onTap: () => Navigator.pop(context, r['id'].toString()),
            );
          }),
        ],
      ),
    );
  }
}
