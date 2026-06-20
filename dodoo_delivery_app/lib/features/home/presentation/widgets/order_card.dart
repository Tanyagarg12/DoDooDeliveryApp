import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/support_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../tracking/presentation/screens/live_tracking_screen.dart';
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

  static const _flow = [
    'accepted',
    'picked_up',
    'in_transit',
    'reached',
    'completed',
  ];

  static const _flowLabels = {
    'accepted': 'Accepted',
    'picked_up': 'Picked Up',
    'in_transit': 'In Transit',
    'reached': 'Reached',
    'completed': 'Delivered',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final status = order['status']?.toString() ?? 'accepted';
    final currentStep = _flow.indexOf(status);
    final nextStatus =
        currentStep >= 0 && currentStep < _flow.length - 1
            ? _flow[currentStep + 1]
            : null;

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
                  label: _flowLabels[status] ?? status,
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

                // Info chips
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _InfoChip(
                      icon: Icons.straighten_rounded,
                      label: '${order['distance_in_km'] ?? 0} km',
                    ),
                    _InfoChip(
                      icon: Icons.schedule_rounded,
                      label: '${order['estimated_time_minutes'] ?? 30} min',
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
                _OrderStepper(currentStep: currentStep, flow: _flow, labels: _flowLabels),
                const SizedBox(height: 14),

                // Live tracking — full-width primary action
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openLiveTracking(context, ref),
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: const Text('Open Live Tracking'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Secondary actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openMaps(order),
                        icon: const Icon(Icons.navigation_rounded, size: 16),
                        label: const Text('Navigate'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(color: cs.primary),
                          foregroundColor: cs.primary,
                        ),
                      ),
                    ),
                    if (nextStatus != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isLoading
                              ? null
                              : () => ref
                                  .read(riderDashboardProvider.notifier)
                                  .advanceOrderStatus(order, nextStatus),
                          icon: const Icon(Icons.arrow_forward_rounded,
                              size: 16),
                          label: Text(
                            'Mark ${_flowLabels[nextStatus] ?? nextStatus}',
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
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

  Future<void> _openMaps(Map<String, dynamic> o) async {
    final lat = o['to_latitude'];
    final lng = o['to_longitude'];
    if (lat == null || lng == null) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openLiveTracking(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LiveTrackingScreen(order: order)),
    );
    // Status may have advanced inside the tracking screen — refresh the list.
    ref.read(riderDashboardProvider.notifier).refresh();
  }

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
    final items =
        (order['items_description'] ?? order['items'])?.toString() ?? '';
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
            if (customer.isNotEmpty) const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.inventory_2_rounded, size: 15, color: cs.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(items,
                      style: TextStyle(
                          fontSize: 12.5, color: cs.onSurfaceVariant)),
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
