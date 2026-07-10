import 'package:flutter/material.dart';

/// The store types a merchant can pick at signup. A store belongs to exactly
/// one category (see the store registration screen). [key] is what's stored on
/// the store doc; [label]/[icon] are for display.
class StoreCategory {
  const StoreCategory(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
}

class StoreCategories {
  StoreCategories._();

  static const restaurant =
      StoreCategory('restaurant', 'Restaurant', Icons.restaurant_rounded);
  static const grocery =
      StoreCategory('grocery', 'Grocery / Kirana', Icons.local_grocery_store_rounded);
  static const bakery =
      StoreCategory('bakery', 'Bakery', Icons.cake_rounded);
  static const sweets =
      StoreCategory('sweets', 'Sweets & Namkeen', Icons.icecream_rounded);
  static const meat =
      StoreCategory('meat', 'Meat & Fish', Icons.set_meal_rounded);
  static const produce =
      StoreCategory('produce', 'Fruits & Vegetables', Icons.eco_rounded);
  static const pharmacy =
      StoreCategory('pharmacy', 'Pharmacy', Icons.local_pharmacy_rounded);
  static const cafe =
      StoreCategory('cafe', 'Café / Beverages', Icons.local_cafe_rounded);
  static const flowers =
      StoreCategory('flowers', 'Flowers & Gifts', Icons.local_florist_rounded);
  static const other =
      StoreCategory('other', 'Other', Icons.storefront_rounded);

  /// All categories, in the order shown in the signup dropdown.
  static const List<StoreCategory> all = [
    restaurant,
    grocery,
    bakery,
    sweets,
    meat,
    produce,
    pharmacy,
    cafe,
    flowers,
    other,
  ];

  /// Resolves a stored category key to its definition (falls back to [other]).
  static StoreCategory byKey(String? key) {
    for (final c in all) {
      if (c.key == key) return c;
    }
    return other;
  }

  /// Display label for a stored key (falls back to the key, then '—').
  static String labelFor(String? key) {
    if (key == null || key.isEmpty) return '—';
    for (final c in all) {
      if (c.key == key) return c.label;
    }
    return key;
  }
}
