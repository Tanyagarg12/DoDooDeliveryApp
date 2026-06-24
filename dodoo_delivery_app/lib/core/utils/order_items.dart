/// Turns an order's items into a clean list of one-per-line strings, e.g.
/// `["Chicken Biryani ×2", "Coke"]`, so a rider with 10 items sees them listed
/// line by line instead of one long run-on string.
///
/// Prefers the structured `cart_items` list; falls back to splitting the
/// joined `items_description` ("a • b • c").
List<String> orderItemLines(Map<String, dynamic> order) {
  final cart = order['cart_items'];
  if (cart is List && cart.isNotEmpty) {
    final lines = <String>[];
    for (final raw in cart) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final title =
          (m['Title'] ?? m['title'] ?? m['name'] ?? 'Item').toString().trim();
      final qty =
          (m['Qty'] ?? m['qty'] ?? m['quantity'] ?? '1').toString().trim();
      if (title.isEmpty) continue;
      lines.add((qty.isEmpty || qty == '1' || qty == '0') ? title : '$title ×$qty');
    }
    if (lines.isNotEmpty) return lines;
  }

  final desc = (order['items_description'] ?? order['items'])?.toString() ?? '';
  if (desc.trim().isEmpty) return const [];
  return desc
      .split(' • ')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}
