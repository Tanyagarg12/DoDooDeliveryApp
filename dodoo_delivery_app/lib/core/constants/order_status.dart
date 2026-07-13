import 'package:flutter/material.dart';

/// The admin-facing order-status model.
///
/// Internal statuses stored on the order (`pending`, `accepted`, `picked_up`,
/// `in_transit`, `reached`, `completed`, `cancelled`) are presented in the admin
/// as these sections:
///
///   • Ongoing     (pending)                       – waiting for a rider
///   • Accept      (accepted)                      – a rider accepted the order
///   • In Progress (picked_up/in_transit/reached)  – rider on the way to customer
///   • Completed   (completed = DoDoo "Deliver")   – delivered
///   • Cancel      (cancelled)                     – cancelled
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

  // Admin sections / statuses the admin can set:
  //   Ongoing → InProgress → Accept → Completed → Cancel
  // ('Ongoing' is the open/waiting state; InProgress covers picked-up + on the
  // way; Completed = DoDoo's Deliver.)
  static const ongoing = AdminOrderStatus._(
    'ongoing',
    'Ongoing',
    'Waiting for a rider',
    Color(0xFFD97706),
    ['pending'],
  );
  // Rider ACCEPTED the order — shown under the "In Progress" section.
  static const accept = AdminOrderStatus._(
    'accept',
    'In Progress',
    'Accepted — serving you soon',
    Color(0xFF2563EB),
    ['accepted'],
  );
  // Rider PICKED UP the order — shown under the "Accept" section.
  static const inProgress = AdminOrderStatus._(
    'inprogress',
    'Accept',
    'Picked up by the rider',
    Color(0xFF7C3AED),
    ['picked_up', 'in_transit', 'reached'],
  );
  static const completed = AdminOrderStatus._(
    'completed',
    'Completed',
    'Delivered',
    Color(0xFF059669),
    ['completed'],
  );
  static const cancelled = AdminOrderStatus._(
    'cancel',
    'Cancel',
    'Cancelled',
    Color(0xFFDC2626),
    ['cancelled'],
  );

  /// All statuses, in the order the admin sees them.
  // UI display order only (does not affect status logic):
  // Ongoing → In Progress (accepted) → Accept (picked up) → Completed → Cancel
  static const List<AdminOrderStatus> all = [
    ongoing,
    accept, // label "In Progress" — accepted orders
    inProgress, // label "Accept" — picked-up orders
    completed,
    cancelled,
  ];

  /// Resolves an internal order status to its admin status.
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

  /// Internal status keys, in order: Accepted → Picked Up → Delivered.
  /// (No separate "on the way" step — legacy in_transit/reached count as
  /// picked up.)
  static const steps = ['accepted', 'picked_up', 'completed'];

  /// Rider-facing label for each status.
  static const labels = {
    'accepted': 'Accepted',
    'picked_up': 'Picked Up',
    'in_transit': 'Picked Up', // legacy
    'reached': 'Picked Up', // legacy
    'completed': 'Delivered',
  };

  /// Normalises a stored status onto the 3-step flow.
  static String normalize(String? status) {
    final s = status ?? 'accepted';
    if (s == 'reached' || s == 'in_transit') return 'picked_up';
    return s;
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
