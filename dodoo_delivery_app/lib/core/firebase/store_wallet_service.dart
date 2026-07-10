import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/store/domain/entities/store_wallet_entity.dart';
import 'firebase_refs.dart';

final _db = FirebaseFirestore.instance;

/// Manages store wallets, transactions, and payout requests.
class StoreWalletService {
  static final _instance = StoreWalletService._();
  StoreWalletService._();
  static StoreWalletService get instance => _instance;

  /// Get the store's wallet (balance + earnings).
  Future<StoreWallet> getWallet(String storeId) async {
    try {
      final snap = await Db.stores.doc(storeId).get();
      final data = snap.data() ?? {};
      return StoreWallet(
        storeId: storeId,
        balance: double.tryParse(data['wallet_balance']?.toString() ?? '0') ?? 0,
        totalEarned:
            double.tryParse(data['wallet_total_earned']?.toString() ?? '0') ??
                0,
        totalWithdrawn:
            double.tryParse(data['wallet_total_withdrawn']?.toString() ?? '0') ??
                0,
        lastUpdated: data['wallet_last_updated'] != null
            ? DateTime.parse(data['wallet_last_updated'].toString())
            : null,
      );
    } catch (_) {
      return StoreWallet(
        storeId: storeId,
        balance: 0,
        totalEarned: 0,
        totalWithdrawn: 0,
      );
    }
  }

  /// Stream transactions for a store (live, newest first). Sorted client-side
  /// so it needs no composite index, and Firestore [Timestamp]s are converted
  /// to ISO strings first (the entity parses strings — a raw Timestamp would
  /// throw and hang the stream).
  Stream<List<StoreWalletTransaction>> streamTransactions(String storeId) {
    return _db
        .collection('store_wallet_transactions')
        .where('store_id', isEqualTo: storeId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => StoreWalletTransaction.fromJson(_normalize(d.data(), d.id)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Copies [data], stamps the doc [id], and converts any Firestore
  /// [Timestamp] to an ISO-8601 string so the entities can parse it.
  Map<String, dynamic> _normalize(Map<String, dynamic> data, String id) {
    final m = Map<String, dynamic>.from(data);
    m['id'] = id;
    for (final key in m.keys.toList()) {
      final v = m[key];
      if (v is Timestamp) m[key] = v.toDate().toIso8601String();
    }
    return m;
  }

  /// Get a single transaction.
  Future<StoreWalletTransaction?> getTransaction(String txnId) async {
    try {
      final snap = await _db
          .collection('store_wallet_transactions')
          .doc(txnId)
          .get();
      if (!snap.exists) return null;
      return StoreWalletTransaction.fromJson({...snap.data()!, 'id': snap.id});
    } catch (_) {
      return null;
    }
  }

  /// Credit the wallet (e.g., order payout). Called internally when an order is ready.
  /// Returns the transaction ID.
  Future<String> creditWallet(
    String storeId, {
    required double amount,
    required String orderId,
    String description = 'Order payout',
  }) async {
    try {
      // Create transaction record
      final txnRef =
          _db.collection('store_wallet_transactions').doc();
      await txnRef.set({
        'store_id': storeId,
        'type': 'credit',
        'amount': amount,
        'order_id': orderId,
        'description': description,
        'created_at': FieldValue.serverTimestamp(),
      });

      // Update store wallet
      await Db.stores.doc(storeId).update({
        'wallet_balance': FieldValue.increment(amount),
        'wallet_total_earned': FieldValue.increment(amount),
        'wallet_last_updated': FieldValue.serverTimestamp(),
      });

      return txnRef.id;
    } catch (e) {
      throw Exception('Failed to credit wallet: $e');
    }
  }

  /// Request a withdrawal (payout).
  Future<String> requestWithdrawal(
    String storeId, {
    required double amount,
    required String bankAccountId,
  }) async {
    try {
      // Validate sufficient balance
      final wallet = await getWallet(storeId);
      if (wallet.balance < amount) {
        throw Exception('Insufficient wallet balance');
      }

      // Create withdrawal request
      final reqRef = _db
          .collection('stores')
          .doc(storeId)
          .collection('withdrawal_requests')
          .doc();
      await reqRef.set({
        'store_id': storeId,
        'amount': amount,
        'status': 'pending',
        'bank_account_id': bankAccountId,
        'requested_at': FieldValue.serverTimestamp(),
      });

      // Deduct from wallet (pending)
      await Db.stores.doc(storeId).update({
        'wallet_balance': FieldValue.increment(-amount),
        'wallet_last_updated': FieldValue.serverTimestamp(),
      });

      return reqRef.id;
    } catch (e) {
      throw Exception('Failed to request withdrawal: $e');
    }
  }

  /// Stream withdrawal requests for a store (live, newest first). Sorted
  /// client-side (no index) with Timestamps normalized to strings.
  Stream<List<StoreWithdrawalRequest>> streamWithdrawalRequests(
      String storeId) {
    return Db.stores
        .doc(storeId)
        .collection('withdrawal_requests')
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) {
        final m = _normalize(d.data(), d.id);
        m['store_id'] = storeId;
        return StoreWithdrawalRequest.fromJson(m);
      }).toList()
        ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      return list;
    });
  }

  /// Get all withdrawal requests across all stores (for admin). Uses a bare
  /// collection-group query (no `where`/`orderBy`) so it needs NO Firestore
  /// index — the [status] filter and sort are applied client-side. (A
  /// `collectionGroup(...).where('status', ...)` needs a collection-group
  /// index; without it the query errors and the screen hangs on loading.)
  Stream<List<StoreWithdrawalRequest>> streamAllWithdrawalRequests(
      {String? status}) {
    return _db.collectionGroup('withdrawal_requests').snapshots().map((snap) {
      var list = snap.docs
          .map((d) => StoreWithdrawalRequest.fromJson(_normalize(d.data(), d.id)))
          .toList();
      if (status != null) {
        list = list.where((r) => r.status == status).toList();
      }
      list.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      return list;
    });
  }

  /// Admin: approve a withdrawal request.
  Future<void> approveWithdrawal(String storeId, String requestId) async {
    try {
      final reqSnap = await Db.stores
          .doc(storeId)
          .collection('withdrawal_requests')
          .doc(requestId)
          .get();
      if (!reqSnap.exists) throw Exception('Request not found');

      final amount = reqSnap.data()?['amount'] as num?;
      if (amount == null) throw Exception('Invalid request');

      // Mark as approved
      await Db.stores
          .doc(storeId)
          .collection('withdrawal_requests')
          .doc(requestId)
          .update({
        'status': 'approved',
        'processed_at': FieldValue.serverTimestamp(),
      });

      // Create debit transaction
      await _db
          .collection('store_wallet_transactions')
          .add({
        'store_id': storeId,
        'type': 'debit',
        'amount': amount,
        'withdrawal_request_id': requestId,
        'description': 'Withdrawal approved',
        'created_at': FieldValue.serverTimestamp(),
      });

      // Deduct from total_withdrawn (already deducted from balance during request)
      await Db.stores.doc(storeId).update({
        'wallet_total_withdrawn': FieldValue.increment(amount.toDouble()),
        'wallet_last_updated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to approve withdrawal: $e');
    }
  }

  /// Admin: reject a withdrawal request (refund the balance).
  Future<void> rejectWithdrawal(
    String storeId,
    String requestId, {
    required String reason,
  }) async {
    try {
      final reqSnap = await Db.stores
          .doc(storeId)
          .collection('withdrawal_requests')
          .doc(requestId)
          .get();
      if (!reqSnap.exists) throw Exception('Request not found');

      final amount = reqSnap.data()?['amount'] as num?;
      if (amount == null) throw Exception('Invalid request');

      // Mark as rejected
      await Db.stores
          .doc(storeId)
          .collection('withdrawal_requests')
          .doc(requestId)
          .update({
        'status': 'rejected',
        'rejection_reason': reason,
        'processed_at': FieldValue.serverTimestamp(),
      });

      // Refund to balance
      await Db.stores.doc(storeId).update({
        'wallet_balance': FieldValue.increment(amount.toDouble()),
        'wallet_last_updated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to reject withdrawal: $e');
    }
  }

  /// Admin: mark a withdrawal as paid.
  Future<void> markWithdrawalPaid(String storeId, String requestId) async {
    try {
      await Db.stores
          .doc(storeId)
          .collection('withdrawal_requests')
          .doc(requestId)
          .update({
        'status': 'paid',
        'processed_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to mark withdrawal as paid: $e');
    }
  }

  /// Add/update a bank account for the store.
  Future<void> saveBankAccount(
    String storeId,
    StoreBankAccount account,
  ) async {
    try {
      final storeSnap = await Db.stores.doc(storeId).get();
      final raw = (storeSnap.data()?['bank_accounts'] as List?) ?? [];
      // Robust against Firestore returning Map<dynamic,dynamic> elements.
      final accounts =
          raw.map((a) => Map<String, dynamic>.from(a as Map)).toList();

      // The very first account is always the default.
      final isFirst = accounts.where((a) => a['id'] != account.id).isEmpty;
      final makeDefault = account.isDefault || isFirst;

      // Only clear other defaults when this one becomes the default.
      if (makeDefault) {
        for (final a in accounts) {
          if (a['id'] != account.id) a['is_default'] = false;
        }
      }

      final saved = account.toJson()..['is_default'] = makeDefault;
      final index = accounts.indexWhere((a) => a['id'] == account.id);
      if (index >= 0) {
        accounts[index] = saved;
      } else {
        accounts.add(saved);
      }

      // set+merge (not update) so it also works if the doc has no such field.
      await Db.stores
          .doc(storeId)
          .set({'bank_accounts': accounts}, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to save bank account: $e');
    }
  }

  /// Removes a bank account and promotes another to default if needed.
  Future<void> deleteBankAccount(String storeId, String accountId) async {
    try {
      final snap = await Db.stores.doc(storeId).get();
      final raw = (snap.data()?['bank_accounts'] as List?) ?? [];
      final accounts =
          raw.map((a) => Map<String, dynamic>.from(a as Map)).toList();
      final wasDefault = accounts
          .any((a) => a['id'] == accountId && a['is_default'] == true);
      accounts.removeWhere((a) => a['id'] == accountId);
      // Always keep one default when accounts remain.
      if (accounts.isNotEmpty &&
          (wasDefault || !accounts.any((a) => a['is_default'] == true))) {
        for (var i = 0; i < accounts.length; i++) {
          accounts[i]['is_default'] = i == 0;
        }
      }
      await Db.stores
          .doc(storeId)
          .set({'bank_accounts': accounts}, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to delete bank account: $e');
    }
  }

  /// Live stream of the store's bank accounts (reflects writes immediately).
  /// Defensive: tolerates a missing/oddly-typed `bank_accounts` field so the
  /// stream never emits an error (which would blank the UI).
  Stream<List<StoreBankAccount>> streamBankAccounts(String storeId) {
    return Db.stores.doc(storeId).snapshots().map((snap) {
      final field = snap.data()?['bank_accounts'];
      if (field is! List) return <StoreBankAccount>[];
      final out = <StoreBankAccount>[];
      for (final a in field) {
        if (a is Map) {
          out.add(StoreBankAccount.fromJson(Map<String, dynamic>.from(a)));
        }
      }
      return out;
    });
  }

  /// Get bank accounts for a store.
  Future<List<StoreBankAccount>> getBankAccounts(String storeId) async {
    try {
      final snap = await Db.stores.doc(storeId).get();
      final raw = (snap.data()?['bank_accounts'] as List?) ?? [];
      // Robust against Firestore returning Map<dynamic,dynamic> elements.
      return raw
          .map((a) =>
              StoreBankAccount.fromJson(Map<String, dynamic>.from(a as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
