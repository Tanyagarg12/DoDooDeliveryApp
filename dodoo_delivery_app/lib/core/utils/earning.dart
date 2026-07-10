/// Helpers for showing how a rider's earning is calculated.
///
/// Earning = base fare + (distance in km × per-km rate). The order stores
/// `distance_in_km`, `per_km_rate`, `base_fare` and `total_earning`, so the
/// breakdown can be shown consistently wherever the earning appears.

num _num(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '') ?? 0);

String _money(num n) =>
    n % 1 == 0 ? n.toStringAsFixed(0) : n.toStringAsFixed(2);

/// A human-readable breakdown, e.g.:
///  • Store:  "2 km × ₹40 = ₹80"  / "₹20 + 2 km × ₹8 = ₹36 → min ₹42"
///  • PDP:    "Pick & Drop = ₹60"
/// Falls back to just the total for older orders with no recorded inputs.
String earningBreakdown(Map<String, dynamic> order) {
  final total = _num(order['total_earning'] ?? order['minimum_fare']);

  final on = (order['order_number'] ?? '').toString().toUpperCase();
  final otype = (order['order_type'] ?? '').toString().toLowerCase();
  if (on.contains('PDP') || otype.contains('pick')) {
    return 'Pick & Drop = ₹${_money(total)}';
  }

  final km = _num(order['distance_in_km']);
  final rate = _num(order['per_km_rate']);
  final base = _num(order['base_fare']);
  if (rate <= 0 && base <= 0) return '₹${_money(total)}';

  final kmStr = km % 1 == 0 ? km.toStringAsFixed(0) : km.toStringAsFixed(1);
  final parts = <String>[];
  if (base > 0) parts.add('₹${_money(base)}');
  if (rate > 0) parts.add('$kmStr km × ₹${_money(rate)}');
  final calc = base + km * rate;
  final calcStr = '${parts.join(' + ')} = ₹${_money(calc)}';
  // If the minimum floor lifted the earning above the computed amount, show it.
  if (total > calc + 0.01) return '$calcStr → min ₹${_money(total)}';
  return calcStr;
}
