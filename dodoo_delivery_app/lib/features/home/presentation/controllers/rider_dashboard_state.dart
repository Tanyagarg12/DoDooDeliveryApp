class RiderDashboardState {
  final Map<String, dynamic> rider;
  final Map<String, dynamic> earnings;
  final List<Map<String, dynamic>> activeOrders;
  final List<Map<String, dynamic>> orderHistory;
  final List<Map<String, dynamic>> pendingOffers;
  final List<Map<String, dynamic>> withdrawalRequests;
  final bool isLoading;
  final bool isStatusLoading;
  final String? error;
  final String? newOfferId; // non-null triggers the incoming-order sheet
  final bool offlineReminder; // true triggers the "go online?" dialog

  // History tab state
  final String historyFilter; // 'today' | 'week' | 'month'
  final List<Map<String, dynamic>> acceptedHistory;
  final List<Map<String, dynamic>> rejectedHistory;
  final Map<String, dynamic> historySummary;
  final bool isHistoryLoading;

  const RiderDashboardState({
    required this.rider,
    this.earnings = const {},
    this.activeOrders = const [],
    this.orderHistory = const [],
    this.pendingOffers = const [],
    this.withdrawalRequests = const [],
    this.isLoading = false,
    this.isStatusLoading = false,
    this.error,
    this.newOfferId,
    this.offlineReminder = false,
    this.historyFilter = 'week',
    this.acceptedHistory = const [],
    this.rejectedHistory = const [],
    this.historySummary = const {},
    this.isHistoryLoading = false,
  });

  // ── Convenience getters ───────────────────────────────────────────────────

  String get currentStatus =>
      rider['current_status']?.toString() ?? 'offline';
  String get firstName => rider['first_name']?.toString() ?? 'Rider';
  String get lastName => rider['last_name']?.toString() ?? '';
  String get fullName {
    final n = '$firstName $lastName'.trim();
    return n.isEmpty ? 'Rider' : n;
  }

  String get phone => rider['phone']?.toString() ?? '';
  String get email => rider['email']?.toString() ?? '';
  String get address => rider['address']?.toString() ?? '';

  /// The rider's GPay / PhonePe (UPI) number for payouts.
  String get upiNumber => rider['upi_number']?.toString() ?? '';
  String get profilePictureUrl =>
      rider['profile_picture_url']?.toString() ?? '';
  String get accountStatus =>
      rider['account_status']?.toString() ?? 'pending';
  String get bankAccount =>
      rider['bank_account_number']?.toString() ?? '';
  String get bankIfsc => rider['bank_ifsc_code']?.toString() ?? '';
  bool get isVerified => rider['is_verified'] == true;
  bool get isDocumentVerified => rider['is_document_verified'] == true;

  /// KYC identifiers (misspelled `aadhar_*` key kept to match the DB).
  String get aadhaarNumber => rider['aadhar_number']?.toString() ?? '';
  String get drivingLicenseNumber =>
      rider['driving_license_number']?.toString() ?? '';

  String get aadhaarFrontUrl => rider['aadhar_front_url']?.toString() ?? '';
  String get aadhaarBackUrl => rider['aadhar_back_url']?.toString() ?? '';
  String get licenseImageUrl => rider['driving_license_image_url']?.toString() ?? '';

  /// Per-document verification status set by the admin
  /// (keys: 'profile' | 'aadhar_front' | 'aadhar_back' | 'license').
  Map<String, dynamic> get documentStatus => rider['document_status'] is Map
      ? Map<String, dynamic>.from(rider['document_status'] as Map)
      : const {};

  /// Status of a single document: 'verified' | 'rejected' | 'pending'.
  String docStatus(String key) =>
      documentStatus[key]?.toString() ?? 'pending';

  /// Free-text message the admin sent to this rider (e.g. "Aadhaar is blurry").
  String get adminComment => rider['admin_comment']?.toString() ?? '';

  /// Profile edits the rider has submitted that are awaiting admin approval.
  /// The live fields above stay unchanged until the admin approves, so the
  /// rider keeps working with their current details in the meantime.
  /// (keys: 'first_name' | 'last_name' | 'email' | 'address' | 'upi_number'
  ///  | 'aadhar_number' | 'driving_license_number' | 'profile_picture_url')
  Map<String, dynamic> get pendingProfileChanges =>
      rider['pending_profile_changes'] is Map
          ? Map<String, dynamic>.from(rider['pending_profile_changes'] as Map)
          : const {};

  bool get hasPendingProfileChanges => pendingProfileChanges.isNotEmpty;

  /// The pending (not-yet-approved) value for a field, or null if none.
  String? pendingValue(String key) =>
      pendingProfileChanges[key]?.toString();

  /// True when the rider has changes awaiting admin review — profile/photo
  /// edits (pending_profile_changes) or a document still marked pending. While
  /// true the profile shows a "pending review" status instead of "verified".
  bool get hasPendingReview {
    if (hasPendingProfileChanges) return true;
    return documentStatus.values.any((v) => v.toString() == 'pending');
  }

  double get walletBalance =>
      double.tryParse(rider['wallet_balance']?.toString() ?? '0') ?? 0;
  double get rating =>
      double.tryParse(rider['rating']?.toString() ?? '5.0') ?? 5.0;
  int get totalOrders =>
      int.tryParse(rider['total_orders']?.toString() ?? '0') ?? 0;

  double get todayEarnings =>
      double.tryParse(earnings['today']?.toString() ?? '0') ?? 0;
  double get weekEarnings =>
      double.tryParse(earnings['week']?.toString() ?? '0') ?? 0;
  double get monthEarnings =>
      double.tryParse(earnings['month']?.toString() ?? '0') ?? 0;
  int get completedOrders =>
      int.tryParse(earnings['completed_orders']?.toString() ?? '0') ?? 0;
  int get todayOrders =>
      int.tryParse(earnings['today_orders']?.toString() ?? '0') ?? 0;

  bool get hasActiveOrder => activeOrders.isNotEmpty;
  bool get hasPendingOffers => pendingOffers.isNotEmpty;

  /// A profile photo is mandatory. True when the rider has neither a live photo
  /// nor one already submitted (awaiting approval) — used to require existing
  /// riders to add a photo before they can go online. A submitted (pending)
  /// photo satisfies this so the rider isn't stuck offline waiting on approval.
  bool get needsProfilePhoto =>
      profilePictureUrl.isEmpty && pendingValue('profile_picture_url') == null;

  // History summary helpers
  int get historyCompletedCount =>
      int.tryParse(historySummary['total_completed']?.toString() ?? '0') ?? 0;
  double get historyEarnings =>
      double.tryParse(historySummary['total_earnings']?.toString() ?? '0') ?? 0;
  int get historyRejectedCount =>
      int.tryParse(historySummary['total_rejected']?.toString() ?? '0') ?? 0;

  // ── copyWith ──────────────────────────────────────────────────────────────

  RiderDashboardState copyWith({
    Map<String, dynamic>? rider,
    Map<String, dynamic>? earnings,
    List<Map<String, dynamic>>? activeOrders,
    List<Map<String, dynamic>>? orderHistory,
    List<Map<String, dynamic>>? pendingOffers,
    List<Map<String, dynamic>>? withdrawalRequests,
    bool? isLoading,
    bool? isStatusLoading,
    String? error,
    String? newOfferId,
    bool? offlineReminder,
    bool clearError = false,
    bool clearNewOffer = false,
    String? historyFilter,
    List<Map<String, dynamic>>? acceptedHistory,
    List<Map<String, dynamic>>? rejectedHistory,
    Map<String, dynamic>? historySummary,
    bool? isHistoryLoading,
  }) {
    return RiderDashboardState(
      rider: rider ?? this.rider,
      earnings: earnings ?? this.earnings,
      activeOrders: activeOrders ?? this.activeOrders,
      orderHistory: orderHistory ?? this.orderHistory,
      pendingOffers: pendingOffers ?? this.pendingOffers,
      withdrawalRequests: withdrawalRequests ?? this.withdrawalRequests,
      isLoading: isLoading ?? this.isLoading,
      isStatusLoading: isStatusLoading ?? this.isStatusLoading,
      error: clearError ? null : (error ?? this.error),
      newOfferId: clearNewOffer ? null : (newOfferId ?? this.newOfferId),
      offlineReminder: offlineReminder ?? this.offlineReminder,
      historyFilter: historyFilter ?? this.historyFilter,
      acceptedHistory: acceptedHistory ?? this.acceptedHistory,
      rejectedHistory: rejectedHistory ?? this.rejectedHistory,
      historySummary: historySummary ?? this.historySummary,
      isHistoryLoading: isHistoryLoading ?? this.isHistoryLoading,
    );
  }
}
