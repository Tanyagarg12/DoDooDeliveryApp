import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/firebase/firebase_refs.dart';

/// Performance stats + order/earnings history for a rider, shown on the admin
/// rider-detail page. Queries the rider's orders directly from Firestore.
class RiderPerformanceSection extends StatefulWidget {
  const RiderPerformanceSection({super.key, required this.riderId});
  final String riderId;

  @override
  State<RiderPerformanceSection> createState() =>
      _RiderPerformanceSectionState();
}

class _RiderPerformanceSectionState extends State<RiderPerformanceSection> {
  static const _lime = Color(0xFFBABC2F);

  bool _loading = true;
  String? _error;
  int _total = 0, _completed = 0, _cancelled = 0;
  double _earnings = 0;
  List<Map<String, dynamic>> _orders = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Fetch this rider's orders, then sort newest-first in Dart (avoids
      // needing a dedicated composite index).
      final snap = await Db.orders
          .where('assigned_rider_id', isEqualTo: widget.riderId)
          .get();
      final list = snap.docs.map((d) {
        final m = Map<String, dynamic>.from(d.data());
        m['id'] = d.id;
        for (final k in m.keys.toList()) {
          if (m[k] is Timestamp) {
            m[k] = (m[k] as Timestamp).toDate().toIso8601String();
          }
        }
        return m;
      }).toList()
        ..sort((a, b) => (b['created_at']?.toString() ?? '')
            .compareTo(a['created_at']?.toString() ?? ''));
      int completed = 0, cancelled = 0;
      double earnings = 0;
      for (final o in list) {
        final s = o['status']?.toString();
        if (s == 'completed') {
          completed++;
          earnings += _toDouble(o['total_earning']);
        } else if (s == 'cancelled') {
          cancelled++;
        }
      }
      if (!mounted) return;
      setState(() {
        _orders = list;
        _total = list.length;
        _completed = completed;
        _cancelled = cancelled;
        _earnings = earnings;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights_rounded, size: 18, color: _lime),
              SizedBox(width: 8),
              Text('Performance',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: Color(0xFFDC2626)))
          else ...[
            Row(
              children: [
                _stat('Total', '$_total', Icons.list_alt_rounded),
                _stat('Completed', '$_completed', Icons.check_circle_rounded,
                    color: const Color(0xFF059669)),
                _stat('Cancelled', '$_cancelled', Icons.cancel_rounded,
                    color: const Color(0xFFDC2626)),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _lime.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded,
                      size: 18, color: Color(0xFF6B6E00)),
                  const SizedBox(width: 8),
                  const Text('Total Earnings',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('₹${_earnings.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Color(0xFF6B6E00))),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Icon(Icons.history_rounded, size: 18, color: _lime),
                SizedBox(width: 8),
                Text('Order & Earnings History',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 8),
            if (_orders.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child:
                    Text('No orders yet.', style: TextStyle(color: Colors.black54)),
              )
            else
              ..._orders.take(20).map(_orderRow),

            // Dedicated list of every order this rider has DELIVERED.
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 18, color: Color(0xFF059669)),
                const SizedBox(width: 8),
                Text('Delivered Orders ($_completed)',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 8),
            Builder(builder: (_) {
              final delivered = _orders
                  .where((o) => o['status']?.toString() == 'completed')
                  .toList();
              if (delivered.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No delivered orders yet.',
                      style: TextStyle(color: Colors.black54)),
                );
              }
              return Column(
                children: delivered.take(50).map(_orderRow).toList(),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, {Color? color}) {
    final c = color ?? const Color(0xFF0F172A);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: c),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16, color: c)),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _orderRow(Map<String, dynamic> o) {
    final status = o['status']?.toString() ?? '';
    final color = switch (status) {
      'completed' => const Color(0xFF059669),
      'cancelled' => const Color(0xFFDC2626),
      'pending' => const Color(0xFFD97706),
      _ => const Color(0xFF2563EB),
    };
    final created = o['created_at']?.toString();
    String date = '';
    if (created != null) {
      final dt = DateTime.tryParse(created);
      if (dt != null) {
        final l = dt.toLocal();
        date =
            '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}';
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Text('#${o['order_number'] ?? '—'}',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
          Text(status.replaceAll('_', ' '),
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          Text('₹${o['total_earning'] ?? 0}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          Text(date, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
