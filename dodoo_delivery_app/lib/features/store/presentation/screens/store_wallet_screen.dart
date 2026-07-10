import 'package:flutter/material.dart';

import '../../../../core/firebase/store_wallet_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/support_modal.dart';
import '../../domain/entities/store_entity.dart';
import '../../domain/entities/store_wallet_entity.dart';

/// Which transactions the list is filtered to (driven by the stat cards).
enum _TxnFilter { all, credit, debit }

/// Store wallet & earnings — balance, payouts, and transaction history.
/// Styled to match the rider "My Orders" look (clean header, premium cards).
class StoreWalletScreen extends StatefulWidget {
  const StoreWalletScreen({super.key, required this.store});
  final StoreEntity store;

  @override
  State<StoreWalletScreen> createState() => _StoreWalletScreenState();
}

class _StoreWalletScreenState extends State<StoreWalletScreen> {
  late final _svc = StoreWalletService.instance;
  late Future<StoreWallet> _walletFut;
  _TxnFilter _txnFilter = _TxnFilter.all;

  @override
  void initState() {
    super.initState();
    _walletFut = _svc.getWallet(widget.store.id);
  }

  void _reload() {
    setState(() {
      _walletFut = _svc.getWallet(widget.store.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: FutureBuilder<StoreWallet>(
                future: _walletFut,
                builder: (context, walletSnap) {
                  if (!walletSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final wallet = walletSnap.data!;
                  return RefreshIndicator(
                    onRefresh: () async => _reload(),
                    color: AppColors.primary,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      children: [
                        _balanceCard(wallet),
                        const SizedBox(height: 20),
                        _statsRow(wallet),
                        const SizedBox(height: 24),
                        _transactionsHeader(),
                        const SizedBox(height: 10),
                        _transactions(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Wallet',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text('Your earnings & payouts',
                    style: TextStyle(
                        fontSize: 12.5, color: Colors.grey.shade600)),
              ],
            ),
          ),
          const SupportIconButton(),
        ],
      ),
    );
  }

  // ── Balance card ──────────────────────────────────────────────────────────

  Widget _balanceCard(StoreWallet wallet) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text('Available Balance',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          Text('₹${wallet.balance.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _requestWithdrawal(wallet),
              icon: const Icon(Icons.north_east_rounded, size: 18),
              label: const Text('Request Payout',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.accent,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow(StoreWallet wallet) {
    return Row(
      children: [
        _stat(Icons.trending_up_rounded, const Color(0xFF059669),
            'Total Earned', '₹${wallet.totalEarned.toStringAsFixed(0)}',
            _TxnFilter.credit),
        const SizedBox(width: 12),
        _stat(Icons.north_east_rounded, const Color(0xFF2563EB),
            'Total Withdrawn', '₹${wallet.totalWithdrawn.toStringAsFixed(0)}',
            _TxnFilter.debit),
      ],
    );
  }

  Widget _stat(IconData icon, Color color, String label, String value,
      _TxnFilter mode) {
    final selected = _txnFilter == mode;
    return Expanded(
      child: GestureDetector(
        // Tapping filters the transaction list; tapping the active one clears.
        onTap: () => setState(
            () => _txnFilter = selected ? _TxnFilter.all : mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? 0.16 : 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: color.withValues(alpha: selected ? 0.9 : 0.22),
                width: selected ? 1.6 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  const Spacer(),
                  Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.filter_alt_outlined,
                      size: 15,
                      color: color.withValues(alpha: selected ? 1 : 0.4)),
                ],
              ),
              const SizedBox(height: 10),
              Text(value,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900, color: color)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Transactions ──────────────────────────────────────────────────────────

  Widget _transactionsHeader() {
    final title = switch (_txnFilter) {
      _TxnFilter.credit => 'Earnings',
      _TxnFilter.debit => 'Payouts',
      _TxnFilter.all => 'Recent Transactions',
    };
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade700)),
          ),
          if (_txnFilter != _TxnFilter.all)
            GestureDetector(
              onTap: () => setState(() => _txnFilter = _TxnFilter.all),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.close_rounded,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 3),
                  Text('Show all',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _transactions() {
    return StreamBuilder<List<StoreWalletTransaction>>(
      stream: _svc.streamTransactions(widget.store.id),
      builder: (context, txnSnap) {
        if (txnSnap.hasError) {
          return _txnNotice(Icons.error_outline_rounded,
              'Couldn’t load transactions', 'Pull down to refresh.');
        }
        if (txnSnap.connectionState == ConnectionState.waiting &&
            !txnSnap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        }
        final all = txnSnap.data ?? [];
        final txns = switch (_txnFilter) {
          _TxnFilter.credit => all.where((t) => t.type == 'credit').toList(),
          _TxnFilter.debit => all.where((t) => t.type != 'credit').toList(),
          _TxnFilter.all => all,
        };
        if (txns.isEmpty) {
          final (title, sub) = switch (_txnFilter) {
            _TxnFilter.credit => ('No earnings yet', 'Order payouts will appear here.'),
            _TxnFilter.debit => ('No payouts yet', 'Withdrawals will appear here.'),
            _TxnFilter.all => (
                'No transactions yet',
                'Earnings and payouts will appear here.'
              ),
          };
          return _txnNotice(Icons.receipt_long_rounded, title, sub);
        }
        return Column(children: txns.map(_transactionTile).toList());
      },
    );
  }

  Widget _txnNotice(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEFE0)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(title,
              style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _transactionTile(StoreWalletTransaction t) {
    final isCredit = t.type == 'credit';
    final color =
        isCredit ? const Color(0xFF059669) : const Color(0xFFDC2626);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEFE0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
                isCredit
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                size: 18,
                color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.description,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text(_formatDate(t.createdAt),
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Text('${isCredit ? '+' : '−'}₹${t.amount.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yest = today.subtract(const Duration(days: 1));
    final dtDate = DateTime(dt.year, dt.month, dt.day);
    if (dtDate == today) {
      return 'Today ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (dtDate == yest) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // ── Request payout ──────────────────────────────────────────────────────────

  Future<void> _requestWithdrawal(StoreWallet wallet) async {
    final messenger = ScaffoldMessenger.of(context);
    if (wallet.balance <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Insufficient balance')),
      );
      return;
    }

    final bankAccounts = await _svc.getBankAccounts(widget.store.id);
    if (!mounted) return;
    if (bankAccounts.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Add a bank account in Settings first')),
      );
      return;
    }

    final amountCtrl =
        TextEditingController(text: wallet.balance.toStringAsFixed(0));
    String selectedBankId = bankAccounts
        .firstWhere((b) => b.isDefault, orElse: () => bankAccounts.first)
        .id;
    bool requesting = false;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setBState) => AlertDialog(
          title: const Text('Request Payout'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedBankId,
                    decoration:
                        const InputDecoration(labelText: 'Select bank account'),
                    items: bankAccounts
                        .map((b) => DropdownMenuItem(
                              value: b.id,
                              child: Text(
                                  '${b.holderName} • ****${b.accountNumber.substring(b.accountNumber.length - 4)}'),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setBState(() => selectedBankId = v ?? selectedBankId),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount (₹)',
                      hintText: 'Enter amount to withdraw',
                    ),
                    validator: (v) {
                      final a = double.tryParse(v?.trim() ?? '');
                      if (a == null || a <= 0) return 'Enter a valid amount';
                      if (a > wallet.balance) return 'Amount exceeds balance';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your request will be reviewed by the admin and processed within 3–5 business days.',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: requesting ? null : () => Navigator.pop(dCtx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: requesting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setBState(() => requesting = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(dCtx);
                      try {
                        final amount = double.parse(amountCtrl.text.trim());
                        await _svc.requestWithdrawal(
                          widget.store.id,
                          amount: amount,
                          bankAccountId: selectedBankId,
                        );
                        if (!mounted) return;
                        navigator.pop();
                        _reload();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Payout requested. Admin will review shortly.'),
                          ),
                        );
                      } catch (e) {
                        setBState(() => requesting = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                                'Failed: ${e.toString().split(':').last}'),
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                      }
                    },
              child: requesting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Request'),
            ),
          ],
        ),
      ),
    );
  }
}
