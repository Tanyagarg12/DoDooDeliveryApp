import 'package:flutter/material.dart';

import '../../../../core/firebase/firebase_refs.dart';
import '../../../../core/firebase/store_wallet_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/support_modal.dart';
import '../../../store/domain/entities/store_wallet_entity.dart';

/// Admin withdrawal request management for store payouts.
class AdminWithdrawalsScreen extends StatefulWidget {
  const AdminWithdrawalsScreen({super.key});

  @override
  State<AdminWithdrawalsScreen> createState() => _AdminWithdrawalsScreenState();
}

class _AdminWithdrawalsScreenState extends State<AdminWithdrawalsScreen> {
  final _svc = StoreWalletService.instance;
  String _filter = 'pending'; // pending | approved | paid | rejected

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        title: const Text('Withdrawal Requests',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: const [SupportIconButton()],
      ),
      body: Column(
        children: [
          // Filter tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: ['pending', 'approved', 'paid', 'rejected']
                  .map((f) {
                    final isActive = _filter == f;
                    return GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFFBABC2F)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${f[0].toUpperCase()}${f.substring(1)}',
                          style: TextStyle(
                            color: isActive
                                ? Colors.white
                                : Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(),
            ),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child: StreamBuilder<List<StoreWithdrawalRequest>>(
              stream: _svc.streamAllWithdrawalRequests(status: _filter),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text('Couldn’t load requests. Pull to retry.',
                        style: TextStyle(color: Colors.grey.shade600)),
                  );
                }
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final requests = snap.data ?? [];
                if (requests.isEmpty) {
                  return Center(
                    child: Text('No $_filter requests',
                        style: TextStyle(color: Colors.grey.shade600)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: requests.length,
                  itemBuilder: (ctx, i) =>
                      _requestTile(context, requests[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestTile(BuildContext context, StoreWithdrawalRequest req) {
    final statusColor = req.status == 'pending'
        ? const Color(0xFFD97706)
        : req.status == 'approved'
            ? const Color(0xFFEA580C)
            : req.status == 'paid'
                ? const Color(0xFF059669)
                : const Color(0xFFDC2626);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8F0EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<({String name, StoreBankAccount? bank})>(
            future: _storeInfo(req),
            builder: (ctx, snap) {
              final info = snap.data;
              final name = info?.name ?? 'Store ${req.storeId}';
              final bank = info?.bank;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                            Text('₹${req.amount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.accent)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          req.status.toUpperCase(),
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  if (bank != null) _bankBlock(bank),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
              'Requested: ${_formatDate(req.requestedAt)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          if (req.processedAt != null) ...[
            const SizedBox(height: 2),
            Text('Processed: ${_formatDate(req.processedAt!)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
          if (req.rejectionReason != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Reason: ${req.rejectionReason}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF7F1D1D)),
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (req.status == 'pending')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _approveRequest(context, req),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF059669))),
                    child: const Text('Approve',
                        style: TextStyle(
                            color: Color(0xFF059669),
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectRequest(context, req),
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: AppColors.error.withValues(alpha: 0.5))),
                    child: Text('Reject',
                        style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5)),
                  ),
                ),
              ],
            )
          else if (req.status == 'approved')
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _markPaid(context, req),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                ),
                child: const Text('Mark as Paid'),
              ),
            ),
        ],
      ),
    );
  }

  /// Loads the store name + the bank account the payout should go to (the one
  /// matching the request's bankAccountId, else the default / first).
  Future<({String name, StoreBankAccount? bank})> _storeInfo(
      StoreWithdrawalRequest req) async {
    var name = 'Store ${req.storeId}';
    StoreBankAccount? bank;
    try {
      final snap = await Db.stores.doc(req.storeId).get();
      final data = snap.data();
      name = data?['store_name']?.toString() ?? name;
      final accounts = ((data?['bank_accounts'] as List?) ?? [])
          .whereType<Map>()
          .map((a) => StoreBankAccount.fromJson(Map<String, dynamic>.from(a)))
          .toList();
      if (accounts.isNotEmpty) {
        bank = accounts.firstWhere(
          (a) => a.id == req.bankAccountId,
          orElse: () => accounts.firstWhere(
            (a) => a.isDefault,
            orElse: () => accounts.first,
          ),
        );
      }
    } catch (_) {/* fall back to id */}
    return (name: name, bank: bank);
  }

  Widget _bankBlock(StoreBankAccount b) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_rounded,
                  size: 14, color: Colors.grey.shade700),
              const SizedBox(width: 6),
              Text('Pay to',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: Colors.grey.shade700)),
            ],
          ),
          const SizedBox(height: 6),
          _kv('Holder', b.holderName),
          _kv('A/C No.', b.accountNumber),
          _kv('IFSC', b.ifscCode),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 58,
              child: Text(k,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
            ),
            Expanded(
              child: SelectableText(v,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _approveRequest(
      BuildContext context, StoreWithdrawalRequest req) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _svc.approveWithdrawal(req.storeId, req.id);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Withdrawal approved')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Failed to approve'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _rejectRequest(
      BuildContext context, StoreWithdrawalRequest req) async {
    final reasonCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Reject withdrawal'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Reason for rejection',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dCtx);
              try {
                await _svc.rejectWithdrawal(
                  req.storeId,
                  req.id,
                  reason: reasonCtrl.text.trim(),
                );
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(content: Text('Withdrawal rejected')),
                );
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('Failed to reject'),
                    backgroundColor: Colors.red.shade700,
                  ),
                );
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _markPaid(
      BuildContext context, StoreWithdrawalRequest req) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _svc.markWithdrawalPaid(req.storeId, req.id);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Marked as paid')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Failed to update'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }
}
