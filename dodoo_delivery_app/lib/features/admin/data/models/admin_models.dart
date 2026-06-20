import '../../domain/entities/admin_entities.dart';

class AdminUserModel extends AdminUser {
  const AdminUserModel({
    required super.id,
    required super.username,
    required super.name,
    required super.email,
  });

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    return AdminUserModel(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      name: json['name']?.toString() ??
          '${json['first_name'] ?? ''} ${json['last_name'] ?? ''}'.trim(),
      email: json['email']?.toString() ?? '',
    );
  }
}

class ApprovalLogModel extends ApprovalLog {
  const ApprovalLogModel({
    required super.id,
    required super.action,
    super.reason,
    required super.timestamp,
    required super.adminName,
    required super.adminUsername,
  });

  factory ApprovalLogModel.fromJson(Map<String, dynamic> json) {
    return ApprovalLogModel(
      id: json['id']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      reason: json['reason']?.toString(),
      timestamp: _parseDate(json['timestamp']),
      adminName: json['admin_name']?.toString() ?? 'System',
      adminUsername: json['admin_username']?.toString() ?? '',
    );
  }

  static DateTime _parseDate(dynamic raw) {
    if (raw == null) return DateTime.now();
    try {
      return DateTime.parse(raw.toString());
    } catch (_) {
      return DateTime.now();
    }
  }
}

class AdminRiderModel extends AdminRider {
  const AdminRiderModel({
    required super.id,
    required super.phone,
    required super.fullName,
    required super.firstName,
    required super.lastName,
    super.email,
    super.address,
    required super.accountStatus,
    required super.currentStatus,
    required super.isVerified,
    required super.isDocumentVerified,
    super.profilePictureUrl,
    super.aadhaarNumber,
    super.aadhaarFrontUrl,
    super.aadhaarBackUrl,
    super.drivingLicenseNumber,
    super.drivingLicenseImageUrl,
    required super.joinedDate,
    required super.approvalLogs,
    required super.rating,
    required super.totalOrders,
  });

  factory AdminRiderModel.fromJson(Map<String, dynamic> json) {
    final logs = (json['approval_logs'] as List? ?? [])
        .map((e) => ApprovalLogModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final firstName = json['first_name']?.toString() ?? '';
    final lastName = json['last_name']?.toString() ?? '';

    return AdminRiderModel(
      id: json['id']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      fullName: json['full_name']?.toString() ??
          '$firstName $lastName'.trim(),
      firstName: firstName,
      lastName: lastName,
      email: json['email']?.toString(),
      address: json['address']?.toString(),
      accountStatus: json['account_status']?.toString() ?? 'pending',
      currentStatus: json['current_status']?.toString() ?? 'offline',
      isVerified: json['is_verified'] as bool? ?? false,
      isDocumentVerified: json['is_document_verified'] as bool? ?? false,
      profilePictureUrl: json['profile_picture_url']?.toString(),
      aadhaarNumber: json['aadhar_number']?.toString(),
      aadhaarFrontUrl: json['aadhar_front_url']?.toString(),
      aadhaarBackUrl: json['aadhar_back_url']?.toString(),
      drivingLicenseNumber: json['driving_license_number']?.toString(),
      drivingLicenseImageUrl: json['driving_license_image_url']?.toString(),
      joinedDate: _parseDate(json['joined_date'] ?? json['date_joined']),
      approvalLogs: logs,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      totalOrders: (json['total_orders'] as num?)?.toInt() ?? 0,
    );
  }

  static DateTime _parseDate(dynamic raw) {
    if (raw == null) return DateTime.now();
    try {
      return DateTime.parse(raw.toString());
    } catch (_) {
      return DateTime.now();
    }
  }
}

class DashboardStatsModel extends DashboardStats {
  const DashboardStatsModel({
    required super.total,
    required super.pending,
    required super.approved,
    required super.rejected,
    required super.suspended,
    required super.onlineNow,
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) {
    return DashboardStatsModel(
      total: (json['total'] as num?)?.toInt() ?? 0,
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      approved: (json['approved'] as num?)?.toInt() ?? 0,
      rejected: (json['rejected'] as num?)?.toInt() ?? 0,
      suspended: (json['suspended'] as num?)?.toInt() ?? 0,
      onlineNow: (json['online_now'] as num?)?.toInt() ?? 0,
    );
  }
}
