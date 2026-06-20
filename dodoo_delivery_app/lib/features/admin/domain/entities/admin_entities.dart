class AdminUser {
  final String id;
  final String username;
  final String name;
  final String email;

  const AdminUser({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
  });
}

class ApprovalLog {
  final String id;
  final String action;
  final String? reason;
  final DateTime timestamp;
  final String adminName;
  final String adminUsername;

  const ApprovalLog({
    required this.id,
    required this.action,
    this.reason,
    required this.timestamp,
    required this.adminName,
    required this.adminUsername,
  });

  String get actionLabel {
    switch (action) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'suspended':
        return 'Suspended';
      case 'reactivated':
        return 'Reactivated';
      case 'registered':
        return 'Registered';
      default:
        return action;
    }
  }
}

class AdminRider {
  final String id;
  final String phone;
  final String fullName;
  final String firstName;
  final String lastName;
  final String? email;
  final String? address;
  final String accountStatus;
  final String currentStatus;
  final bool isVerified;
  final bool isDocumentVerified;
  final String? profilePictureUrl;
  final String? aadhaarNumber;
  final String? aadhaarFrontUrl;
  final String? aadhaarBackUrl;
  final String? drivingLicenseNumber;
  final String? drivingLicenseImageUrl;
  final DateTime joinedDate;
  final List<ApprovalLog> approvalLogs;
  final double rating;
  final int totalOrders;

  const AdminRider({
    required this.id,
    required this.phone,
    required this.fullName,
    required this.firstName,
    required this.lastName,
    this.email,
    this.address,
    required this.accountStatus,
    required this.currentStatus,
    required this.isVerified,
    required this.isDocumentVerified,
    this.profilePictureUrl,
    this.aadhaarNumber,
    this.aadhaarFrontUrl,
    this.aadhaarBackUrl,
    this.drivingLicenseNumber,
    this.drivingLicenseImageUrl,
    required this.joinedDate,
    required this.approvalLogs,
    required this.rating,
    required this.totalOrders,
  });

  bool get isPending => accountStatus == 'pending';
  bool get isApproved => accountStatus == 'approved';
  bool get isRejected => accountStatus == 'rejected';
  bool get isSuspended => accountStatus == 'suspended';
}

class DashboardStats {
  final int total;
  final int pending;
  final int approved;
  final int rejected;
  final int suspended;
  final int onlineNow;

  const DashboardStats({
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.suspended,
    required this.onlineNow,
  });
}

class RiderListResult {
  final List<AdminRider> riders;
  final Map<String, int> counts;

  const RiderListResult({required this.riders, required this.counts});
}
