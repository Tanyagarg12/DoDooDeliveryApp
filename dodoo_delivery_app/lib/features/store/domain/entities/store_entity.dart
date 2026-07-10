/// A store/merchant on the DoDoo platform. Identified by the owner's phone
/// number (also the Firestore `stores` doc id). Mirrors the rider model: an
/// account moves through pending → approved (or rejected / suspended), and the
/// store can be open/closed for orders once approved.
class StoreEntity {
  final String id; // == phone number
  final String phone;
  final String ownerFirstName;
  final String ownerLastName;
  final String storeName;
  final String category; // StoreCategory.key
  final String? email;
  final String address;
  final String cityCode;

  // Documents / KYC
  final String? storefrontPhotoUrl;
  final String fssaiNumber;
  final String? fssaiDocUrl;
  final String gstNumber;
  final String ownerIdNumber;
  final String? ownerIdUrl;

  final String accountStatus; // pending | approved | rejected | suspended
  final String currentStatus; // open | closed
  final bool isVerified;
  final bool isDocumentVerified;
  final String? adminComment;
  final double rating;
  final int totalOrders;

  /// True once the store has tapped "Start" on the approval screen — i.e. it
  /// has entered the app at least once. Used to show the one-time
  /// "Store Approved!" welcome only on the first approved entry.
  final bool hasStarted;

  /// The store's id on the DoDoo platform (set by admin via SaveStore /
  /// manual link). Empty/null until linked. Used to push menu items & fetch
  /// orders from DoDoo.
  final String? dodooStoreId;

  const StoreEntity({
    required this.id,
    required this.phone,
    required this.ownerFirstName,
    required this.ownerLastName,
    required this.storeName,
    required this.category,
    this.email,
    required this.address,
    required this.cityCode,
    this.storefrontPhotoUrl,
    required this.fssaiNumber,
    this.fssaiDocUrl,
    required this.gstNumber,
    required this.ownerIdNumber,
    this.ownerIdUrl,
    required this.accountStatus,
    required this.currentStatus,
    required this.isVerified,
    required this.isDocumentVerified,
    this.adminComment,
    required this.rating,
    required this.totalOrders,
    this.hasStarted = false,
    this.dodooStoreId,
  });

  String get ownerName => '$ownerFirstName $ownerLastName'.trim();

  bool get isPending => accountStatus == 'pending';
  bool get isApproved => accountStatus == 'approved';
  bool get isRejected => accountStatus == 'rejected';
  bool get isSuspended => accountStatus == 'suspended';
  bool get isOpen => currentStatus == 'open';

  StoreEntity copyWith({
    String? accountStatus,
    String? currentStatus,
    bool? isVerified,
    bool? isDocumentVerified,
    String? adminComment,
    String? ownerFirstName,
    String? ownerLastName,
    String? storeName,
    String? category,
    String? email,
    String? address,
    bool? hasStarted,
    String? dodooStoreId,
  }) {
    return StoreEntity(
      id: id,
      phone: phone,
      ownerFirstName: ownerFirstName ?? this.ownerFirstName,
      ownerLastName: ownerLastName ?? this.ownerLastName,
      storeName: storeName ?? this.storeName,
      category: category ?? this.category,
      email: email ?? this.email,
      address: address ?? this.address,
      cityCode: cityCode,
      storefrontPhotoUrl: storefrontPhotoUrl,
      fssaiNumber: fssaiNumber,
      fssaiDocUrl: fssaiDocUrl,
      gstNumber: gstNumber,
      ownerIdNumber: ownerIdNumber,
      ownerIdUrl: ownerIdUrl,
      accountStatus: accountStatus ?? this.accountStatus,
      currentStatus: currentStatus ?? this.currentStatus,
      isVerified: isVerified ?? this.isVerified,
      isDocumentVerified: isDocumentVerified ?? this.isDocumentVerified,
      adminComment: adminComment ?? this.adminComment,
      rating: rating,
      totalOrders: totalOrders,
      hasStarted: hasStarted ?? this.hasStarted,
      dodooStoreId: dodooStoreId ?? this.dodooStoreId,
    );
  }
}

/// Result of the phone-existence check before sending an OTP.
class StoreCheckPhoneResult {
  final bool exists;
  final String phone;
  final String? accountStatus;

  const StoreCheckPhoneResult({
    required this.exists,
    required this.phone,
    this.accountStatus,
  });
}

/// Everything collected on the store registration screen. Image paths are
/// local files uploaded to Cloudinary during registration.
class StoreRegistrationData {
  final String phone;
  final String ownerFirstName;
  final String ownerLastName;
  final String storeName;
  final String category;
  final String? email;
  final String address;
  final String cityCode;
  final String fssaiNumber;
  final String gstNumber;
  final String ownerIdType; // 'aadhaar' | 'pan'
  final String ownerIdNumber;
  final String? storefrontPhotoPath;
  final String? fssaiDocPath;
  final String? ownerIdPath;

  const StoreRegistrationData({
    required this.phone,
    required this.ownerFirstName,
    required this.ownerLastName,
    required this.storeName,
    required this.category,
    this.email,
    required this.address,
    required this.cityCode,
    required this.fssaiNumber,
    required this.gstNumber,
    this.ownerIdType = 'aadhaar',
    required this.ownerIdNumber,
    this.storefrontPhotoPath,
    this.fssaiDocPath,
    this.ownerIdPath,
  });
}
