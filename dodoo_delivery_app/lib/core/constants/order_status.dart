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
