import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/fade_in.dart';
import '../../../../core/widgets/support_modal.dart';
import '../controllers/rider_dashboard_controller.dart';

class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(riderDashboardProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: cs.primary,
          onRefresh: () =>
              ref.read(riderDashboardProvider.notifier).setHistoryFilter(s.historyFilter),
          child: CustomScrollView(
            slivers: [
              // ── Header ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Order History',
                                style: TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 2),
                            Text(
                              'Your completed & rejected deliveries',
                              style: TextStyle(
                                  fontSize: 12.5, color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      if (s.isHistoryLoading)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          onPressed: () => ref
                              .read(riderDashboardProvider.notifier)
                              .setHistoryFilter(s.historyFilter),
                          icon: const Icon(Icons.refresh_rounded),
                          color: cs.primary,
                        ),
                      const SupportIconButton(),
                    ],
                  ),
                ),
              ),

              // ── Filter chips ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _FilterChips(
                    selected: s.historyFilter,
                    onSelected: (f) => ref
                        .read(riderDashboardProvider.notifier)
                        .setHistoryFilter(f),
                  ),
                ),
              ),

              // ── Summary card ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _SummaryCard(
                    completed: s.historyCompletedCount,
                    earnings: s.historyEarnings,
                    rejected: s.historyRejectedCount,
                    isDark: isDark,
                  ),
                ),
              ),

              // ── Accepted deliveries ──────────────────────────────────────
              if (s.acceptedHistory.isEmpty && s.rejectedHistory.isEmpty && !s.isHistoryLoading)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(filter: s.historyFilter, cs: cs),
                )
              else ...[
                if (s.acceptedHistory.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'Completed Deliveries',
                    count: s.acceptedHistory.length,
                    icon: Icons.check_circle_rounded,
                    color: AppColors.online,
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: FadeIn(
                            index: i,
                            child: _OrderCard(
                                order: s.acceptedHistory[i], isDark: isDark),
                          ),
                        ),
                        childCount: s.acceptedHistory.length,
                      ),
                    ),
                  ),
                ],
                if (s.rejectedHistory.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'Rejected Offers',
                    count: s.rejectedHistory.length,
                    icon: Icons.cancel_rounded,
                    color: AppColors.busy,
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: FadeIn(
                            index: i,
                            child: _RejectedCard(
                                notification: s.rejectedHistory[i],
                                isDark: isDark),
                          ),
                        ),
                        childCount: s.rejectedHistory.length,
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Filter chips ──────────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});
  final String selected;
  final void Function(String) onSelected;

  static const _filters = [
    ('today', 'Today'),
    ('week', 'This Week'),
    ('month', 'This Month'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filters.map((entry) {
          final (value, label) = entry;
          final isSelected = selected == value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => onSelected(value),
              selectedColor: AppColors.primary,
              checkmarkColor: AppColors.onPrimary,
              labelStyle: TextStyle(
                color: isSelected
                    ? AppColors.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.completed,
    required this.earnings,
    required this.rejected,
    required this.isDark,
  });
  final int completed;
  final double earnings;
  final int rejected;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _Stat(value: '$completed', label: 'Completed', icon: Icons.check_circle_rounded),
          _Divider(),
          _Stat(value: '₹${earnings.toStringAsFixed(0)}', label: 'Earnings', icon: Icons.currency_rupee_rounded),
          _Divider(),
          _Stat(value: '$rejected', label: 'Rejected', icon: Icons.cancel_rounded),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: AppColors.onPrimary.withValues(alpha: 0.25),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.icon});
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.onPrimary.withValues(alpha: 0.8)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.onPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: AppColors.onPrimary.withValues(alpha: 0.75),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Completed order card ──────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.isDark});
  final Map<String, dynamic> order;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final orderStatus = order['status']?.toString() ?? 'completed';
    final isCompleted = orderStatus == 'completed';
    final statusColor = isCompleted ? AppColors.online : AppColors.busy;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE8F0EE),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: statusColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${order['order_number'] ?? '—'}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    if (order['created_at'] != null)
                      Text(
                        _formatDate(order['created_at'].toString()),
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  orderStatus.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (order['customer_name'] != null &&
              (order['customer_name'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline, size: 13, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  order['customer_name'].toString(),
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                // Customer phone is intentionally not shown to riders.
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _RoutePreview(order: order, cs: cs),
          const SizedBox(height: 12),
          Row(
            children: [
              _Chip(
                icon: Icons.straighten_rounded,
                label: '${order['distance_in_km'] ?? 0} km',
              ),
              const SizedBox(width: 8),
              _Chip(
                icon: Icons.currency_rupee_rounded,
                label: '₹${order['total_earning'] ?? order['minimum_fare'] ?? '0'}',
                primary: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}

// ── Rejected offer card ───────────────────────────────────────────────────────

class _RejectedCard extends StatelessWidget {
  const _RejectedCard({required this.notification, required this.isDark});
  final Map<String, dynamic> notification;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final order = notification['order'] as Map<String, dynamic>?;
    if (order == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.busy.withValues(alpha: 0.15),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.busy.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.do_not_disturb_rounded, color: AppColors.busy, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${order['order_number'] ?? '—'}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  order['from_address']?.toString().split(',').first ?? '—',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${order['total_earning'] ?? order['minimum_fare'] ?? '0'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.busy,
                ),
              ),
              Text(
                '${order['distance_in_km'] ?? 0} km',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _RoutePreview extends StatelessWidget {
  const _RoutePreview({required this.order, required this.cs});
  final Map<String, dynamic> order;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          children: [
            Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle)),
            Container(
                width: 1.5, height: 24,
                color: AppColors.primary.withValues(alpha: 0.3)),
            Container(
                width: 8, height: 8,
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
                order['from_address']?.toString() ?? '—',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Text(
                order['to_address']?.toString() ?? '—',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
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

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, this.primary = false});
  final IconData icon;
  final String label;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = primary ? AppColors.primary : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: primary
            ? AppColors.primaryContainer
            : isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter, required this.cs});
  final String filter;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final label = switch (filter) {
      'today' => 'today',
      'month' => 'this month',
      _ => 'this week',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: FadeIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primaryContainer,
                      cs.primaryContainer.withValues(alpha: 0.4),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.history_rounded, size: 44, color: cs.primary),
              ),
              const SizedBox(height: 22),
              const Text(
                'Nothing here yet',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'No completed or rejected orders $label.\nPull down to refresh.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: cs.onSurfaceVariant, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
