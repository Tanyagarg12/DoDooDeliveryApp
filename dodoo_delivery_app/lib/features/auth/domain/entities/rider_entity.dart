enum AccountStatus {
  pending,
  approved,
  rejected,
  suspended;

  static AccountStatus fromString(String? value) {
    return AccountStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AccountStatus.pending,
    );
  }

  bool get canAccessOrders => this == AccountStatus.approved;
}

class RiderEntity {
  final String id;
  final String phone;
  final String firstName;
  final String lastName;
  final String? email;
  final String? address;
  final String? profilePictureUrl;
  final String? drivingLicenseNumber;
  final String? aadhaarNumber;
  final AccountStatus accountStatus;
  final String currentStatus;
  final double walletBalance;
  final double rating;
  final int totalOrders;
  final bool isVerified;
  final bool isDocumentVerified;
  final String? adminComment;

  const RiderEntity({
    required this.id,
    required this.phone,
    required this.firstName,
    required this.lastName,
    this.email,
    this.address,
    this.profilePictureUrl,
    this.drivingLicenseNumber,
    this.aadhaarNumber,
    required this.accountStatus,
    required this.currentStatus,
    required this.walletBalance,
    required this.rating,
    required this.totalOrders,
    required this.isVerified,
    required this.isDocumentVerified,
    this.adminComment,
  });

  String get fullName => '$firstName $lastName'.trim();

  bool get isPending => accountStatus == AccountStatus.pending;
  bool get isApproved => accountStatus == AccountStatus.approved;
  bool get isRejected => accountStatus == AccountStatus.rejected;
  bool get isSuspended => accountStatus == AccountStatus.suspended;

  RiderEntity copyWith({
    String? id,
    String? phone,
    String? firstName,
    String? lastName,
    String? email,
    String? address,
    String? profilePictureUrl,
    String? drivingLicenseNumber,
    String? aadhaarNumber,
    AccountStatus? accountStatus,
    String? currentStatus,
    double? walletBalance,
    double? rating,
    int? totalOrders,
    bool? isVerified,
    bool? isDocumentVerified,
    String? adminComment,
  }) {
    return RiderEntity(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      address: address ?? this.address,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      drivingLicenseNumber: drivingLicenseNumber ?? this.drivingLicenseNumber,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      accountStatus: accountStatus ?? this.accountStatus,
      currentStatus: currentStatus ?? this.currentStatus,
      walletBalance: walletBalance ?? this.walletBalance,
      rating: rating ?? this.rating,
      totalOrders: totalOrders ?? this.totalOrders,
      isVerified: isVerified ?? this.isVerified,
      isDocumentVerified: isDocumentVerified ?? this.isDocumentVerified,
      adminComment: adminComment ?? this.adminComment,
    );
  }
}

class CheckPhoneResult {
  final bool exists;
  final String phone;
  final AccountStatus? accountStatus;
  final String? riderId;

  const CheckPhoneResult({
    required this.exists,
    required this.phone,
    this.accountStatus,
    this.riderId,
  });
}

class RegistrationData {
  final String phone;
  final String firstName;
  final String lastName;
  final String? email;
  final String? address;
  final String? aadhaarNumber;
  final String? drivingLicenseNumber;
  final String? profilePicturePath;
  final String? aadhaarFrontPath;
  final String? aadhaarBackPath;
  final String? drivingLicenseImagePath;

  const RegistrationData({
    required this.phone,
    required this.firstName,
    required this.lastName,
    this.email,
    this.address,
    this.aadhaarNumber,
    this.drivingLicenseNumber,
    this.profilePicturePath,
    this.aadhaarFrontPath,
    this.aadhaarBackPath,
    this.drivingLicenseImagePath,
  });
}
