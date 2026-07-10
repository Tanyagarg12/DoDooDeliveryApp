/// Store wallet — earnings, transactions, and payout requests.
class StoreWallet {
  final String storeId;
  final double balance;
  final double totalEarned;
  final double totalWithdrawn;
  final DateTime? lastUpdated;

  const StoreWallet({
    required this.storeId,
    required this.balance,
    required this.totalEarned,
    required this.totalWithdrawn,
    this.lastUpdated,
  });

  StoreWallet copyWith({
    double? balance,
    double? totalEarned,
    double? totalWithdrawn,
  }) =>
      StoreWallet(
        storeId: storeId,
        balance: balance ?? this.balance,
        totalEarned: totalEarned ?? this.totalEarned,
        totalWithdrawn: totalWithdrawn ?? this.totalWithdrawn,
        lastUpdated: DateTime.now(),
      );
}

/// A wallet transaction (credit/debit) — order payout, withdrawal, etc.
class StoreWalletTransaction {
  final String id;
  final String storeId;
  final String type; // 'credit' (order) | 'debit' (withdrawal)
  final double amount;
  final String? orderId; // if type='credit'
  final String? withdrawalRequestId; // if type='debit'
  final String description;
  final DateTime createdAt;

  const StoreWalletTransaction({
    required this.id,
    required this.storeId,
    required this.type,
    required this.amount,
    this.orderId,
    this.withdrawalRequestId,
    required this.description,
    required this.createdAt,
  });

  factory StoreWalletTransaction.fromJson(Map<String, dynamic> json) =>
      StoreWalletTransaction(
        id: json['id']?.toString() ?? '',
        storeId: json['store_id']?.toString() ?? '',
        type: json['type']?.toString() ?? 'credit',
        amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
        orderId: json['order_id']?.toString(),
        withdrawalRequestId: json['withdrawal_request_id']?.toString(),
        description: json['description']?.toString() ?? '',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'].toString())
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'store_id': storeId,
        'type': type,
        'amount': amount,
        'order_id': orderId,
        'withdrawal_request_id': withdrawalRequestId,
        'description': description,
        'created_at': createdAt.toIso8601String(),
      };
}

/// A payout/withdrawal request.
class StoreWithdrawalRequest {
  final String id;
  final String storeId;
  final double amount;
  final String status; // 'pending' | 'approved' | 'paid' | 'rejected'
  final String? bankAccountId; // reference to the bank account used
  final String? rejectionReason;
  final DateTime requestedAt;
  final DateTime? processedAt;

  const StoreWithdrawalRequest({
    required this.id,
    required this.storeId,
    required this.amount,
    required this.status,
    this.bankAccountId,
    this.rejectionReason,
    required this.requestedAt,
    this.processedAt,
  });

  factory StoreWithdrawalRequest.fromJson(Map<String, dynamic> json) =>
      StoreWithdrawalRequest(
        id: json['id']?.toString() ?? '',
        storeId: json['store_id']?.toString() ?? '',
        amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
        status: json['status']?.toString() ?? 'pending',
        bankAccountId: json['bank_account_id']?.toString(),
        rejectionReason: json['rejection_reason']?.toString(),
        requestedAt: json['requested_at'] != null
            ? DateTime.parse(json['requested_at'].toString())
            : DateTime.now(),
        processedAt: json['processed_at'] != null
            ? DateTime.parse(json['processed_at'].toString())
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'store_id': storeId,
        'amount': amount,
        'status': status,
        'bank_account_id': bankAccountId,
        'rejection_reason': rejectionReason,
        'requested_at': requestedAt.toIso8601String(),
        'processed_at': processedAt?.toIso8601String(),
      };
}

/// Bank account for payout (stored in store doc under bank_accounts array).
class StoreBankAccount {
  final String id;
  final String holderName;
  final String accountNumber;
  final String ifscCode;
  final bool isDefault;

  const StoreBankAccount({
    required this.id,
    required this.holderName,
    required this.accountNumber,
    required this.ifscCode,
    required this.isDefault,
  });

  factory StoreBankAccount.fromJson(Map<String, dynamic> json) =>
      StoreBankAccount(
        id: json['id']?.toString() ?? '',
        holderName: json['holder_name']?.toString() ?? '',
        accountNumber: json['account_number']?.toString() ?? '',
        ifscCode: json['ifsc_code']?.toString() ?? '',
        isDefault: json['is_default'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'holder_name': holderName,
        'account_number': accountNumber,
        'ifsc_code': ifscCode,
        'is_default': isDefault,
      };
}
