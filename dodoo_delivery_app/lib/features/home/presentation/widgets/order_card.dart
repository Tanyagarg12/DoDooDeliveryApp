import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/order_status.dart';
import '../../../../core/constants/support_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/maps_launcher.dart';
import '../../../../core/utils/order_items.dart';
import '../controllers/rider_dashboard_controller.dart';

// ── Active Order Card ─────────────────────────────────────────────────────────

class ActiveOrderCard extends ConsumerWidget {
  const ActiveOrderCard({
    super.key,
    required this.order,
    required this.isLoading,
  });
  final Map<String, dynamic> order;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final status = RiderOrderFlow.normalize(order['status']?.toString());
    final currentStep = RiderOrderFlow.stepIndex(status);
    final nextStatus = RiderOrderFlow.next(status);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? AppColors.primaryLight.withValues(alpha: 0.2)
              : AppColors.primaryContainer,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              gradient: AppGradients.brandSplash,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                const Icon(Icons.delivery_dining_rounded,
                    color: AppColors.onPrimary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '#${order['order_number'] ?? '—'}',
                    style: const TextStyle(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                _BadgeChip(
                  label: RiderOrderFlow.label(status),
                  color: AppColors.onPrimary.withValues(alpha: 0.18),
                  textColor: AppColors.onPrimary,
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route
                _RouteTimeline(order: order),
                const SizedBox(height: 14),

                // Info chips. Distance/ETA only show when the order actually
                // carries them (DoDoo store orders often don't) — a missing
                // value is hidden rather than shown as a misleading "0 km".
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (_km(order) != null)
                      _InfoChip(
                        icon: Icons.straighten_rounded,
                        label: '${_km(order)} km',
                      ),
                    if (_eta(order) != null)
                      _InfoChip(
                        icon: Icons.schedule_rounded,
                        label: '${_eta(order)} min',
                      ),
                    _InfoChip(
                      icon: Icons.currency_rupee_rounded,
                      label: '${order['total_earning'] ?? order['minimum_fare'] ?? '0'}',
                      highlight: true,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Customer + items (no phone number — privacy)
                _CustomerItems(order: order),

                // Progress stepper
                _OrderStepper(
                  currentStep: currentStep,
                  flow: RiderOrderFlow.steps,
                  labels: RiderOrderFlow.labels,
                ),
                const SizedBox(height: 14),

                // Navigate — full-width primary action (opens Google Maps with
                // turn-by-turn directions to the pickup/drop).
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openMaps(order),
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: const Text('Navigate'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                if (nextStatus != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () => ref
                              .read(riderDashboardProvider.notifier)
                              .advanceOrderStatus(order, nextStatus),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: Text(
                        'Mark ${RiderOrderFlow.label(nextStatus)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: cs.primary),
                        foregroundColor: cs.primary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: _callSupport,
                    icon: const Icon(Icons.support_agent_rounded, size: 16),
                    label: const Text('Call Support'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.online),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Distance (km) only if the order actually has it. Null → hide the chip.
  static num? _km(Map<String, dynamic> o) {
    final v = o['distance_in_km'];
    final n = v is num ? v : num.tryParse(v?.toString() ?? '');
    return (n != null && n > 0) ? n : null;
  }

  /// ETA (minutes) only if present. Null → hide the chip.
  static num? _eta(Map<String, dynamic> o) {
    final v = o['estimated_time_minutes'];
    final n = v is num ? v : num.tryParse(v?.toString() ?? '');
    return (n != null && n > 0) ? n : null;
  }

  /// Opens external Google Maps directions. Routes to the drop address; uses
  /// the address text when there are no coordinates (DoDoo store orders).
  Future<void> _openMaps(Map<String, dynamic> o) =>
      openOrderDirections(o, toPickup: false);

  /// Riders never get the customer's number — calls go to support instead.
  Future<void> _callSupport() async {
    final uri = Uri.parse('tel:${SupportConfig.supportPhone}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

/// Customer name + item details shown on an active order. Deliberately omits
/// the customer's phone number.
class _CustomerItems extends StatelessWidget {
  const _CustomerItems({required this.order});
  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final customer = order['customer_name']?.toString() ?? '';
    final items = orderItemLines(order);
    if (customer.isEmpty && items.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surfaceDark
            : const Color(0xFFF8FAF0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (customer.isNotEmpty)
            Row(
              children: [
                Icon(Icons.person_rounded, size: 15, color: cs.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(customer,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          if (items.isNotEmpty) ...[
            if (customer.isNotEmpty) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.inventory_2_rounded, size: 15, color: cs.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Items (${items.length})',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      // One item per line — clearer than a run-on string.
                      for (final line in items)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('• $line',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.3,
                                  color: cs.onSurface)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteTimeline extends StatelessWidget {
  const _RouteTimeline({required this.order});
  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 2,
              height: 30,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.5),
                    AppColors.busy.withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.busy, width: 2),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.store_rounded,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order['from_address']?.toString() ?? '—',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      size: 14, color: AppColors.busy),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order['to_address']?.toString() ?? '—',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderStepper extends StatelessWidget {
  const _OrderStepper({
    required this.currentStep,
    required this.flow,
    required this.labels,
  });
  final int currentStep;
  final List<String> flow;
  final Map<String, String> labels;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(flow.length, (i) {
        final done = i <= currentStep;
        final active = i == currentStep;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: active ? 28 : 20,
                      height: active ? 28 : 20,
                      decoration: BoxDecoration(
                        color: done ? AppColors.primary : Colors.transparent,
                        border: Border.all(
                          color: done
                              ? AppColors.primary
                              : AppColors.offline,
                          width: active ? 2.5 : 1.5,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: done
                          ? Icon(Icons.check_rounded,
                              size: active ? 14 : 11,
                              color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[flow[i]] ?? flow[i],
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: active
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: done
                            ? AppColors.primary
                            : AppColors.offline,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (i < flow.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 20),
                    color: i < currentStep
                        ? AppColors.primary
                        : AppColors.offline.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({
    required this.label,
    required this.color,
    required this.textColor,
  });
  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, this.highlight = false});
  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = highlight
        ? AppColors.primaryContainer
        : isDark
            ? AppColors.surfaceDark
            : const Color(0xFFF1F5F9);
    final color = highlight ? AppColors.primary : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
