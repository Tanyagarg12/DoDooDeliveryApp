import 'dart:convert';

import '../../domain/entities/rider_entity.dart';

class RiderModel extends RiderEntity {
  const RiderModel({
    required super.id,
    required super.phone,
    required super.firstName,
    required super.lastName,
    super.email,
    super.address,
    super.profilePictureUrl,
    super.drivingLicenseNumber,
    super.aadhaarNumber,
    required super.accountStatus,
    required super.currentStatus,
    required super.walletBalance,
    required super.rating,
    required super.totalOrders,
    required super.isVerified,
    required super.isDocumentVerified,
    super.adminComment,
  });

  factory RiderModel.fromJson(Map<String, dynamic> json) {
    return RiderModel(
      id: json['id']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      email: json['email']?.toString(),
      address: json['address']?.toString(),
      profilePictureUrl: json['profile_picture_url']?.toString(),
      drivingLicenseNumber: json['driving_license_number']?.toString(),
      aadhaarNumber: json['aadhar_number']?.toString(),
      accountStatus: AccountStatus.fromString(json['account_status']?.toString()),
      currentStatus: json['current_status']?.toString() ?? 'offline',
      walletBalance: _toDouble(json['wallet_balance']),
      rating: _toDouble(json['rating'], fallback: 5.0),
      totalOrders: (json['total_orders'] as num?)?.toInt() ?? 0,
      isVerified: json['is_verified'] as bool? ?? false,
      isDocumentVerified: json['is_document_verified'] as bool? ?? false,
      adminComment: json['admin_comment']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'address': address,
        'profile_picture_url': profilePictureUrl,
        'driving_license_number': drivingLicenseNumber,
        'aadhar_number': aadhaarNumber,
        'account_status': accountStatus.name,
        'current_status': currentStatus,
        'wallet_balance': walletBalance,
        'rating': rating,
        'total_orders': totalOrders,
        'is_verified': isVerified,
        'is_document_verified': isDocumentVerified,
        'admin_comment': adminComment,
      };

  String toJsonString() => jsonEncode(toJson());

  static RiderModel fromJsonString(String jsonString) =>
      RiderModel.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  static double _toDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    return double.tryParse(value.toString()) ?? fallback;
  }
}
