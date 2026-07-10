/// A single item on a store's menu. Stored in the `stores/{storeId}/menu`
/// subcollection — one document per item.
class MenuItem {
  final String id;
  final String name;
  final double price;
  final bool available;

  /// Hosted (Cloudinary) photo URL, or null if none.
  final String? photoUrl;

  /// Optional short description shown under the name.
  final String? description;

  /// Offer/discount as a percentage (0–100). 0 means no offer.
  final double discountPercent;

  /// Veg indicator: true = veg, false = non-veg, null = not specified
  /// (e.g. for non-food stores).
  final bool? isVeg;

  /// Featured/recommended item — highlighted in the menu.
  final bool isRecommended;

  /// Optional section/category within the menu (e.g. "Starters", "Beverages").
  final String? category;

  /// The item's id on the DoDoo platform (returned by SaveStoreItem). Null
  /// until the item has been pushed to DoDoo; used to UPDATE rather than
  /// re-insert on the next push.
  final String? dodooItemId;

  const MenuItem({
    required this.id,
    required this.name,
    required this.price,
    this.available = true,
    this.photoUrl,
    this.description,
    this.discountPercent = 0,
    this.isVeg,
    this.isRecommended = false,
    this.category,
    this.dodooItemId,
  });

  /// Whether the item carries an active offer.
  bool get hasDiscount => discountPercent > 0;

  /// Price after applying [discountPercent].
  double get finalPrice =>
      hasDiscount ? price * (1 - discountPercent / 100) : price;

  /// Section label used for grouping (falls back to "Other").
  String get section =>
      (category != null && category!.trim().isNotEmpty) ? category!.trim() : 'Other';

  factory MenuItem.fromDoc(String id, Map<String, dynamic> m) {
    String? nonEmpty(dynamic v) {
      final s = v?.toString().trim() ?? '';
      return s.isEmpty ? null : s;
    }

    return MenuItem(
      id: id,
      name: m['name']?.toString() ?? '',
      price: double.tryParse(m['price']?.toString() ?? '') ?? 0,
      available: m['available'] as bool? ?? true,
      photoUrl: nonEmpty(m['photo_url']),
      description: nonEmpty(m['description']),
      discountPercent:
          double.tryParse(m['discount_percent']?.toString() ?? '') ?? 0,
      isVeg: m['is_veg'] is bool ? m['is_veg'] as bool : null,
      isRecommended: m['is_recommended'] as bool? ?? false,
      category: nonEmpty(m['category']),
      dodooItemId: nonEmpty(m['dodoo_item_id']),
    );
  }
}
