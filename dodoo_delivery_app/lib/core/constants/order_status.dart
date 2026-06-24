import 'package:flutter/material.dart';

/// The admin-facing order-status model.
///
/// The app stores granular internal statuses on the Supabase `orders` row
/// (`pending`, `accepted`, `picked_up`, `in_transit`, `reached`, `completed`,
/// `cancelled`). The admin portal presents them as five business statuses:
///
///   • Ongoing    – order is active, waiting for a rider (todo)
///   • InProgress – order is assigned to a rider
///   • Accepted   – order picked up by the rider
///   • Completed  – order delivered
///   • Cancelled  – order cancelled
///
/// This is the single source of truth for the label, description and colour of
/// each status across the admin screens.
class AdminOrderStatus {
  const AdminOrderStatus._(
    this.key,
    this.label,
    this.description,
    this.color,
    this.internal,
  );

  /// Stable key used for filter chips.
  final String key;

  /// Display label shown on badges/chips.
  final String label;

  /// One-line meaning shown on the order detail screen.
  final String description;

  /// Badge/chip colour.
  final Color color;

  /// Internal Supabase statuses that roll up into this business status.
  final List<String> internal;

  static const ongoing = AdminOrderStatus._(
    'ongoing',
    'Ongoing',
    'Order is active',
    Color(0xFFD97706),
    ['pending'],
  );
  static const inProgress = AdminOrderStatus._(
    'inprogress',
    'InProgress',
    'Order is assigned to rider',
    Color(0xFF2563EB),
    ['accepted'],
  );
  static const accepted = AdminOrderStatus._(
    'accepted',
    'Accepted',
    'Order picked up by rider',
    Color(0xFF7C3AED),
    ['picked_up', 'in_transit', 'reached'],
  );
  static const completed = AdminOrderStatus._(
    'completed',
    'Completed',
    'Order delivered',
    Color(0xFF059669),
    ['completed'],
  );
  static const cancelled = AdminOrderStatus._(
    'cancelled',
    'Cancelled',
    'Order cancelled',
    Color(0xFFDC2626),
    ['cancelled'],
  );

  /// All statuses, in workflow order.
  static const List<AdminOrderStatus> all = [
    ongoing,
    inProgress,
    accepted,
    completed,
    cancelled,
  ];

  /// Resolves an internal Supabase status to its admin business status.
  /// Unknown/empty statuses fall back to [ongoing].
  static AdminOrderStatus fromInternal(String? status) {
    for (final s in all) {
      if (s.internal.contains(status)) return s;
    }
    return ongoing;
  }
}

/// The delivery progress a rider moves an order through, with the SAME labels
/// everywhere they appear (order card + live-tracking screen) so the status
/// wording is consistent across the app. We deliberately use a single,
/// simple 4-step flow — no separate "in transit" vs "reached" — to avoid
/// confusing riders.
class RiderOrderFlow {
  RiderOrderFlow._();

  /// Internal status keys, in order. ('reached' is treated as 'in_transit'.)
  static const steps = ['accepted', 'picked_up', 'in_transit', 'completed'];

  /// Rider-facing label for each status. Older 'reached' rows map to 'On the Way'.
  static const labels = {
    'accepted': 'Accepted',
    'picked_up': 'Picked Up',
    'in_transit': 'On the Way',
    'reached': 'On the Way',
    'completed': 'Delivered',
  };

  /// Normalises a stored status onto the 4-step flow ('reached' → 'in_transit').
  static String normalize(String? status) {
    final s = status ?? 'accepted';
    return s == 'reached' ? 'in_transit' : s;
  }

  /// The step the order is currently on (index into [steps]).
  static int stepIndex(String? status) => steps.indexOf(normalize(status));

  /// The next status to advance to, or null when delivered.
  static String? next(String? status) {
    final i = stepIndex(status);
    if (i < 0 || i >= steps.length - 1) return null;
    return steps[i + 1];
  }

  static String label(String? status) => labels[normalize(status)] ?? (status ?? '');
}
