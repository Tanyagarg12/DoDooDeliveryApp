/// Maps our internal store category keys to DoDoo's category ObjectIds.
///
/// DoDoo category ids come from GetCategoriesInfo/0 (stable ObjectIds):
///   Restaurants          5c9b24c2a5cb4a062cb84af9
///   Organic Products     5c9b24c2a5cb4a062cb84afb
///   Sweets and Bakeries  5c9b24c2a5cb4a062cb84afc
///   All Other            5cfa1f61deabd32f543bcf01
///   Medicines            5c9bb3ca5142db0be0388c54
///   Hot Deals            5cfa22f5deabd32f543bcf02
class DodooCategories {
  DodooCategories._();

  static const restaurants = '5c9b24c2a5cb4a062cb84af9';
  static const organicProducts = '5c9b24c2a5cb4a062cb84afb';
  static const sweetsAndBakeries = '5c9b24c2a5cb4a062cb84afc';
  static const allOther = '5cfa1f61deabd32f543bcf01';
  static const medicines = '5c9bb3ca5142db0be0388c54';
  static const hotDeals = '5cfa22f5deabd32f543bcf02';

  /// Our StoreCategory.key → DoDoo category ObjectId (best-fit; falls back to
  /// "All Other"). Keys: restaurant, grocery, bakery, sweets, meat, produce,
  /// pharmacy, cafe, flowers, other.
  static String forStoreKey(String? key) {
    switch (key) {
      case 'restaurant':
      case 'cafe':
        return restaurants;
      case 'bakery':
      case 'sweets':
        return sweetsAndBakeries;
      case 'produce':
      case 'grocery':
        return organicProducts;
      case 'pharmacy':
        return medicines;
      default: // meat, flowers, other
        return allOther;
    }
  }
}
