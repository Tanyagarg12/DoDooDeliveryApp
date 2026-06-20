import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class IncomingOrderSheet extends StatefulWidget {
  const IncomingOrderSheet({
    super.key,
    required this.offer,
    required this.onAccept,
    required this.onReject,
  });

  final Map<String, dynamic> offer;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  State<IncomingOrderSheet> createState() => _IncomingOrderSheetState();
}

class _IncomingOrderSheetState extends State<IncomingOrderSheet>
    with SingleTickerProviderStateMixin {
  // 30-second auto-reject countdown
  static const _timeout = 30;
  int _remaining = _timeout;
  Timer? _timer;
  late AnimationController _bounceCtrl;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _timer?.cancel();
        widget.onReject();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bounceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order =
        Map<String, dynamic>.from(widget.offer['order'] ?? widget.offer);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Row(
            children: [
              AnimatedBuilder(
                animation: _bounceCtrl,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, -2 * _bounceCtrl.value),
                  child: child,
                ),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppGradients.statusGradient('online', isDark),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications_active_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'New Delivery Request!',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '#${order['order_number'] ?? '—'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Countdown ring
              _CountdownRing(remaining: _remaining, total: _timeout),
            ],
          ),
          const SizedBox(height: 20),

          // Order info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : const Color(0xFFF8FAFB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.store_rounded,
                  iconColor: AppColors.primary,
                  label: 'Pickup',
                  value: order['from_address']?.toString() ?? '—',
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.location_on_rounded,
                  iconColor: AppColors.busy,
                  label: 'Drop',
                  value: order['to_address']?.toString() ?? '—',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCell(
                        icon: Icons.straighten_rounded,
                        label: 'Distance',
                        value: '${order['distance_in_km'] ?? 0} km',
                      ),
                    ),
                    Expanded(
                      child: _MetricCell(
                        icon: Icons.schedule_rounded,
                        label: 'ETA',
                        value:
                            '${order['estimated_time_minutes'] ?? 30} min',
                      ),
                    ),
                    Expanded(
                      child: _MetricCell(
                        icon: Icons.currency_rupee_rounded,
                        label: 'Earning',
                        value:
                            '₹${order['total_earning'] ?? order['minimum_fare'] ?? '0'}',
                        highlight: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Buttons — reject is icon-only to stay compact; accept is the
          // wide primary. Neither label can wrap now.
          Row(
            children: [
              SizedBox(
                width: 56,
                height: 52,
                child: OutlinedButton(
                  onPressed: widget.onReject,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  child: const Icon(Icons.close_rounded, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: widget.onAccept,
                  icon: const Icon(Icons.check_circle_rounded, size: 20),
                  label: const Text('Accept Order',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.online,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w800),
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

// ── Countdown ring ────────────────────────────────────────────────────────────

class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.remaining, required this.total});
  final int remaining;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = remaining / total;
    final color = remaining > 10 ? AppColors.online : AppColors.busy;
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 3.5,
            backgroundColor:
                Theme.of(context).colorScheme.outlineVariant,
            color: color,
          ),
          Text(
            '$remaining',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

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
              Text(value,
                  style: TextStyle(
                      fontSize: 16.5,
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

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color =
        highlight ? AppColors.primary : Theme.of(context).colorScheme.onSurface;
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: highlight ? 22 : 19,
              fontWeight: FontWeight.w900,
              height: 1.0,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.3,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
