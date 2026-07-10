/// A quick-add menu suggestion tailored to a store's category. Lets a store
/// bootstrap its menu with common items in one tap (they can edit prices/photos
/// afterwards).
class MenuSuggestion {
  const MenuSuggestion(this.name, this.price, {this.isVeg, this.category});
  final String name;
  final double price;
  final bool? isVeg;
  final String? category;
}

/// Category-appropriate starter items, keyed by [StoreCategory.key].
class MenuSuggestions {
  MenuSuggestions._();

  static const _restaurant = [
    MenuSuggestion('Paneer Butter Masala', 220, isVeg: true, category: 'Main Course'),
    MenuSuggestion('Butter Naan', 40, isVeg: true, category: 'Breads'),
    MenuSuggestion('Veg Biryani', 180, isVeg: true, category: 'Rice'),
    MenuSuggestion('Chicken Biryani', 240, isVeg: false, category: 'Rice'),
    MenuSuggestion('Gulab Jamun', 60, isVeg: true, category: 'Desserts'),
    MenuSuggestion('Masala Dosa', 120, isVeg: true, category: 'Starters'),
  ];

  static const _grocery = [
    MenuSuggestion('Rice (1 kg)', 60, isVeg: true, category: 'Staples'),
    MenuSuggestion('Wheat Flour (1 kg)', 45, isVeg: true, category: 'Staples'),
    MenuSuggestion('Sugar (1 kg)', 45, isVeg: true, category: 'Staples'),
    MenuSuggestion('Cooking Oil (1 L)', 140, isVeg: true, category: 'Staples'),
    MenuSuggestion('Toor Dal (1 kg)', 150, isVeg: true, category: 'Pulses'),
    MenuSuggestion('Milk (1 L)', 60, isVeg: true, category: 'Dairy'),
  ];

  static const _bakery = [
    MenuSuggestion('Chocolate Cake (500g)', 350, isVeg: true, category: 'Cakes'),
    MenuSuggestion('Vanilla Pastry', 60, isVeg: true, category: 'Pastries'),
    MenuSuggestion('Croissant', 50, isVeg: true, category: 'Breads'),
    MenuSuggestion('Veg Puff', 30, isVeg: true, category: 'Savoury'),
    MenuSuggestion('Brownie', 70, isVeg: true, category: 'Desserts'),
  ];

  static const _sweets = [
    MenuSuggestion('Kaju Katli (250g)', 250, isVeg: true, category: 'Sweets'),
    MenuSuggestion('Motichoor Ladoo (250g)', 150, isVeg: true, category: 'Sweets'),
    MenuSuggestion('Rasgulla (500g)', 180, isVeg: true, category: 'Sweets'),
    MenuSuggestion('Samosa', 20, isVeg: true, category: 'Namkeen'),
    MenuSuggestion('Mixture (250g)', 90, isVeg: true, category: 'Namkeen'),
  ];

  static const _meat = [
    MenuSuggestion('Chicken Curry Cut (1 kg)', 240, isVeg: false, category: 'Chicken'),
    MenuSuggestion('Boneless Chicken (1 kg)', 320, isVeg: false, category: 'Chicken'),
    MenuSuggestion('Mutton (1 kg)', 720, isVeg: false, category: 'Mutton'),
    MenuSuggestion('Fish - Rohu (1 kg)', 260, isVeg: false, category: 'Fish'),
    MenuSuggestion('Prawns (500g)', 350, isVeg: false, category: 'Seafood'),
  ];

  static const _produce = [
    MenuSuggestion('Tomato (1 kg)', 40, isVeg: true, category: 'Vegetables'),
    MenuSuggestion('Onion (1 kg)', 35, isVeg: true, category: 'Vegetables'),
    MenuSuggestion('Potato (1 kg)', 30, isVeg: true, category: 'Vegetables'),
    MenuSuggestion('Banana (1 dozen)', 50, isVeg: true, category: 'Fruits'),
    MenuSuggestion('Apple (1 kg)', 160, isVeg: true, category: 'Fruits'),
  ];

  static const _pharmacy = [
    MenuSuggestion('Paracetamol Strip', 25, category: 'Medicines'),
    MenuSuggestion('Hand Sanitizer (200ml)', 90, category: 'Personal Care'),
    MenuSuggestion('Face Mask (10 pcs)', 50, category: 'Personal Care'),
    MenuSuggestion('Digital Thermometer', 180, category: 'Devices'),
    MenuSuggestion('Antiseptic Liquid', 120, category: 'First Aid'),
  ];

  static const _cafe = [
    MenuSuggestion('Cappuccino', 120, isVeg: true, category: 'Coffee'),
    MenuSuggestion('Cold Coffee', 140, isVeg: true, category: 'Coffee'),
    MenuSuggestion('Masala Chai', 40, isVeg: true, category: 'Tea'),
    MenuSuggestion('Veg Sandwich', 90, isVeg: true, category: 'Snacks'),
    MenuSuggestion('Chocolate Shake', 150, isVeg: true, category: 'Shakes'),
  ];

  static const _flowers = [
    MenuSuggestion('Rose Bouquet', 350, category: 'Bouquets'),
    MenuSuggestion('Mixed Flower Bunch', 250, category: 'Bouquets'),
    MenuSuggestion('Birthday Gift Combo', 600, category: 'Gifts'),
    MenuSuggestion('Greeting Card', 80, category: 'Gifts'),
    MenuSuggestion('Chocolate Box', 400, category: 'Gifts'),
  ];

  static const _other = [
    MenuSuggestion('Item 1', 100),
    MenuSuggestion('Item 2', 150),
    MenuSuggestion('Item 3', 200),
  ];

  /// Suggested starter items for the given store category key.
  static List<MenuSuggestion> forCategory(String? key) {
    switch (key) {
      case 'restaurant':
        return _restaurant;
      case 'grocery':
        return _grocery;
      case 'bakery':
        return _bakery;
      case 'sweets':
        return _sweets;
      case 'meat':
        return _meat;
      case 'produce':
        return _produce;
      case 'pharmacy':
        return _pharmacy;
      case 'cafe':
        return _cafe;
      case 'flowers':
        return _flowers;
      default:
        return _other;
    }
  }
}
