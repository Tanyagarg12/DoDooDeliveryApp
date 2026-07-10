import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/store/domain/entities/menu_item.dart';
import 'firebase_refs.dart';

/// CRUD for a store's menu (subcollection `stores/{storeId}/menu`).
class StoreMenuService {
  StoreMenuService._();
  static final StoreMenuService instance = StoreMenuService._();

  CollectionReference<Map<String, dynamic>> _col(String storeId) =>
      Db.stores.doc(storeId).collection('menu');

  /// Live menu, sorted by name (client-side to avoid an index).
  Stream<List<MenuItem>> streamMenu(String storeId) {
    return _col(storeId).snapshots().map((snap) {
      final items =
          snap.docs.map((d) => MenuItem.fromDoc(d.id, d.data())).toList()
            ..sort((a, b) =>
                a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return items;
    });
  }

  /// One-shot fetch (used by the order form).
  Future<List<MenuItem>> getMenu(String storeId) async {
    final snap = await _col(storeId).get();
    return snap.docs.map((d) => MenuItem.fromDoc(d.id, d.data())).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Adds an item and returns the new document id.
  Future<String> addItem(
    String storeId, {
    required String name,
    required double price,
    String? photoUrl,
    String? description,
    double discountPercent = 0,
    bool? isVeg,
    bool isRecommended = false,
    String? category,
  }) async {
    final ref = await _col(storeId).add({
      'name': name,
      'price': price,
      'available': true,
      'photo_url': photoUrl,
      'description': description,
      'discount_percent': discountPercent,
      'is_veg': isVeg,
      'is_recommended': isRecommended,
      'category': category,
      'created_at': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateItem(
    String storeId,
    String itemId, {
    required String name,
    required double price,
    String? photoUrl,
    String? description,
    double discountPercent = 0,
    bool? isVeg,
    bool isRecommended = false,
    String? category,
  }) async {
    await _col(storeId).doc(itemId).update({
      'name': name,
      'price': price,
      'photo_url': photoUrl,
      'description': description,
      'discount_percent': discountPercent,
      'is_veg': isVeg,
      'is_recommended': isRecommended,
      'category': category,
    });
  }

  Future<void> setAvailable(String storeId, String itemId, bool available) async {
    await _col(storeId).doc(itemId).update({'available': available});
  }

  Future<void> setRecommended(
      String storeId, String itemId, bool recommended) async {
    await _col(storeId).doc(itemId).update({'is_recommended': recommended});
  }

  /// Records the DoDoo item id returned by SaveStoreItem, so future edits
  /// update that same item instead of creating a duplicate.
  Future<void> setDodooItemId(
      String storeId, String itemId, String dodooItemId) async {
    await _col(storeId).doc(itemId).update({'dodoo_item_id': dodooItemId});
  }

  Future<void> deleteItem(String storeId, String itemId) async {
    await _col(storeId).doc(itemId).delete();
  }
}
