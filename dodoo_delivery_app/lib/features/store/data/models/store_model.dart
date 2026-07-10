import 'dart:convert';

import '../../domain/entities/store_entity.dart';

class StoreModel extends StoreEntity {
  const StoreModel({
    required super.id,
    required super.phone,
    required super.ownerFirstName,
    required super.ownerLastName,
    required super.storeName,
    required super.category,
    super.email,
    required super.address,
    required super.cityCode,
    super.storefrontPhotoUrl,
    required super.fssaiNumber,
    super.fssaiDocUrl,
    required super.gstNumber,
    required super.ownerIdNumber,
    super.ownerIdUrl,
    required super.accountStatus,
    required super.currentStatus,
    required super.isVerified,
    required super.isDocumentVerified,
    super.adminComment,
    required super.rating,
    required super.totalOrders,
    super.hasStarted,
    super.dodooStoreId,
  });

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    return StoreModel(
      id: json['id']?.toString() ?? json['phone']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      ownerFirstName: json['owner_first_name']?.toString() ?? '',
      ownerLastName: json['owner_last_name']?.toString() ?? '',
      storeName: json['store_name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'other',
      email: json['email']?.toString(),
      address: json['address']?.toString() ?? '',
      cityCode: json['city_code']?.toString() ?? 'ATP',
      storefrontPhotoUrl: json['storefront_photo_url']?.toString(),
      fssaiNumber: json['fssai_number']?.toString() ?? '',
      fssaiDocUrl: json['fssai_doc_url']?.toString(),
      gstNumber: json['gst_number']?.toString() ?? '',
      ownerIdNumber: json['owner_id_number']?.toString() ?? '',
      ownerIdUrl: json['owner_id_url']?.toString(),
      accountStatus: json['account_status']?.toString() ?? 'pending',
      currentStatus: json['current_status']?.toString() ?? 'closed',
      isVerified: json['is_verified'] as bool? ?? false,
      isDocumentVerified: json['is_document_verified'] as bool? ?? false,
      adminComment: json['admin_comment']?.toString(),
      rating: _toDouble(json['rating'], fallback: 5.0),
      totalOrders: (json['total_orders'] as num?)?.toInt() ?? 0,
      hasStarted: json['has_started'] as bool? ?? false,
      dodooStoreId: json['dodoo_store_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'owner_first_name': ownerFirstName,
        'owner_last_name': ownerLastName,
        'store_name': storeName,
        'category': category,
        'email': email,
        'address': address,
        'city_code': cityCode,
        'storefront_photo_url': storefrontPhotoUrl,
        'fssai_number': fssaiNumber,
        'fssai_doc_url': fssaiDocUrl,
        'gst_number': gstNumber,
        'owner_id_number': ownerIdNumber,
        'owner_id_url': ownerIdUrl,
        'account_status': accountStatus,
        'current_status': currentStatus,
        'is_verified': isVerified,
        'is_document_verified': isDocumentVerified,
        'admin_comment': adminComment,
        'rating': rating,
        'total_orders': totalOrders,
        'has_started': hasStarted,
        'dodoo_store_id': dodooStoreId,
      };

  String toJsonString() => jsonEncode(toJson());

  static StoreModel fromJsonString(String jsonString) =>
      StoreModel.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  static double _toDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    return double.tryParse(value.toString()) ?? fallback;
  }
}
