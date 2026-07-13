import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/payout_policy.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/fade_in.dart';
import '../../../../core/widgets/support_modal.dart';
import '../controllers/rider_dashboard_controller.dart';
import '../controllers/rider_dashboard_state.dart';

class EarningsTab extends ConsumerStatefulWidget {
  const EarningsTab({super.key});

  @override
  ConsumerState<EarningsTab> createState() => _EarningsTabState();
}

class _EarningsTabState extends ConsumerState<EarningsTab> {
  static const _commissionPrefsKey = 'earnings_commission_dismissed';
  double? _totalEarnings;
  bool _commissionDismissed = true; // hidden until we've checked prefs

  @override
  void initState() {
    super.initState();
    _loadTotal();
    _loadCommissionFlag();
  }

  Future<void> _loadTotal() async {
    try {
      final total = await ref.read(riderApiProvider).totalEarnings();
      if (mounted) setState(() => _totalEarnings = total);
    } catch (_) {/* best-effort */}
  }

  Future<void> _loadCommissionFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getBool(_commissionPrefsKey) ?? false;
      if (mounted) setState(() => _commissionDismissed = dismissed);
    } catch (_) {
      if (mounted) setState(() => _commissionDismissed = false);
    }
  }

  Future<void> _dismissCommission() async {
    setState(() => _commissionDismissed = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_commissionPrefsKey, true);
    } catch (_) {/* best-effort */}
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(riderDashboardProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(riderDashboardProvider.notifier).refresh(showLoading: true),
        color: cs.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Earnings',
                                style: TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 2),
                            Text(
                              'Your wallet, payouts & history',
                              style: TextStyle(
                                  fontSize: 12.5, color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SupportIconButton(),
                    ],
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── 0% commission highlight (dismissible) ─────────────────
                  if (!_commissionDismissed) ...[
                    _CommissionHighlight(onClose: _dismissCommission),
                    const SizedBox(height: 14),
                  ],

                  // ── Wallet card ───────────────────────────────────────────
                  FadeIn(child: _WalletCard(state: state, isDark: isDark)),
                  const SizedBox(height: 16),

                  // ── Earnings grid ─────────────────────────────────────────
                  FadeIn(
                    index: 1,
                    child: _EarningsGrid(
                        state: state, isDark: isDark, total: _totalEarnings),
                  ),
                  const SizedBox(height: 20),

                  // ── Auto-payout policy ────────────────────────────────────
                  FadeIn(index: 2, child: const _AutoPayoutBanner()),
                  const SizedBox(height: 14),

                  // ── Withdraw ──────────────────────────────────────────────
                  FadeIn(
                    index: 3,
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _openWithdrawSheet(state),
                        icon: const Icon(Icons.account_balance_rounded, size: 18),
                        label: Text(
                            'Withdraw  •  ₹${PayoutPolicy.withdrawable(state.walletBalance).toStringAsFixed(0)} available',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          textStyle: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Withdrawal history ────────────────────────────────────
                  _SectionLabel(
                      label: 'Transaction History',
                      icon: Icons.receipt_long_rounded),
                  const SizedBox(height: 10),
                  if (state.withdrawalRequests.isEmpty)
                    _EmptySection(
                      icon: Icons.receipt_long_outlined,
                      text: 'No transactions yet.',
                    )
                  else
                    ...state.withdrawalRequests.indexed.map(
                      (e) => FadeIn(
                        index: e.$1,
                        child: _TransactionTile(item: e.$2, isDark: isDark),
                      ),
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWithdrawSheet(RiderDashboardState state) async {
    final available = PayoutPolicy.withdrawable(state.walletBalance);
    if (available <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '₹${PayoutPolicy.minMaintenanceBalance.toStringAsFixed(0)} maintenance balance is kept in your wallet. Earn more to withdraw.'),
        ),
      );
      return;
    }
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WithdrawSheet(balance: available),
    );
    if (submitted == true) {
      _loadTotal();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Withdrawal request submitted.')),
        );
      }
    }
  }
}

// ── 0% commission highlight (small, dismissible) ────────────────────────────

class _CommissionHighlight extends StatelessWidget {
  const _CommissionHighlight({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B8043).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0B8043).withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.savings_rounded, size: 18, color: Color(0xFF0B8043)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '0% commission — you keep 100% of every rupee you earn.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0B8043),
              ),
            ),
          ),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded,
                  size: 16, color: Color(0xFF0B8043)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Auto-payout policy banner ───────────────────────────────────────────────

class _AutoPayoutBanner extends StatelessWidget {
  const _AutoPayoutBanner();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.12)
            : const Color(0xFFF2F5A0).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.schedule_send_rounded,
                size: 18, color: Color(0xFF6B6E00)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Daily auto-payout',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 3),
                Text(
                  'Your wallet is automatically transferred to your bank every '
                  'morning at ${PayoutPolicy.payoutTimeLabel}. '
                  '₹${PayoutPolicy.minMaintenanceBalance.toStringAsFixed(0)} is '
                  'kept in your wallet for maintenance.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Withdraw sheet — collects bank details at withdrawal time ───────────────

class _WithdrawSheet extends ConsumerStatefulWidget {
  const _WithdrawSheet({required this.balance});
  final double balance;

  @override
  ConsumerState<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends ConsumerState<_WithdrawSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _holder = TextEditingController();
  final _bank = TextEditingController();
  final _account = TextEditingController();
  final _ifsc = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _amount.dispose();
    _holder.dispose();
    _bank.dispose();
    _account.dispose();
    _ifsc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final ok = await ref.read(riderDashboardProvider.notifier).requestWithdrawal(
          amount: _amount.text.trim(),
          bankAccount: _account.text.replaceAll(RegExp(r'\s'), ''),
          bankIfsc: _ifsc.text.trim().toUpperCase(),
          accountHolderName: _holder.text.trim(),
          bankName: _bank.text.trim(),
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit withdrawal. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Withdraw Earnings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('Available: ₹${widget.balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: AppColors.online, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                '₹${PayoutPolicy.minMaintenanceBalance.toStringAsFixed(0)} is kept in your wallet for maintenance.',
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixIcon: Icon(Icons.currency_rupee_rounded),
                ),
                validator: (v) {
                  final amt = double.tryParse(v?.trim() ?? '') ?? 0;
                  if (amt <= 0) return 'Enter a valid amount';
                  if (amt > widget.balance) return 'Amount exceeds your balance';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _holder,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Account holder name',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bank,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Bank name',
                  prefixIcon: Icon(Icons.account_balance_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _account,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Account number',
                  prefixIcon: Icon(Icons.numbers_rounded),
                ),
                validator: Validators.bankAccountNumber,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ifsc,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'IFSC code',
                  prefixIcon: Icon(Icons.confirmation_number_rounded),
                ),
                validator: Validators.ifsc,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.onPrimary))
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(_submitting ? 'Submitting…' : 'Request Withdrawal'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Wallet card ───────────────────────────────────────────────────────────────

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.state, required this.isDark});
  final RiderDashboardState state;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.brandSplash,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLight.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded,
                  color: AppColors.onPrimary.withValues(alpha: 0.7), size: 20),
              const SizedBox(width: 8),
              Text(
                'Wallet Balance',
                style: TextStyle(
                    color: AppColors.onPrimary.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.onPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  state.accountStatus.toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '₹${state.walletBalance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppColors.onPrimary,
              fontSize: 38,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Available for withdrawal',
            style: TextStyle(
                color: AppColors.onPrimary.withValues(alpha: 0.65),
                fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                    label: 'Today',
                    value: '₹${state.todayEarnings.toStringAsFixed(0)}'),
              ),
              Expanded(
                child: _MiniStat(
                    label: 'This Week',
                    value: '₹${state.weekEarnings.toStringAsFixed(0)}'),
              ),
              Expanded(
                child: _MiniStat(
                    label: 'Orders', value: '${state.completedOrders}'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: AppColors.onPrimary.withValues(alpha: 0.6),
                fontSize: 11)),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15)),
      ],
    );
  }
}

// ── Earnings grid ─────────────────────────────────────────────────────────────

class _EarningsGrid extends StatelessWidget {
  const _EarningsGrid(
      {required this.state, required this.isDark, this.total});
  final RiderDashboardState state;
  final bool isDark;
  final double? total;

  @override
  Widget build(BuildContext context) {
    final items = [
      _EarningsItem(
        label: 'Total Earnings',
        value: total == null
            ? '…'
            : '₹${total!.toStringAsFixed(2)}',
        icon: Icons.savings_rounded,
        color: AppColors.accent,
        bg: isDark
            ? AppColors.accent.withValues(alpha: 0.12)
            : AppColors.accentContainer,
      ),
      _EarningsItem(
        label: "Today's Earnings",
        value: '₹${state.todayEarnings.toStringAsFixed(2)}',
        icon: Icons.today_rounded,
        color: AppColors.online,
        bg: isDark
            ? AppColors.online.withValues(alpha: 0.1)
            : AppColors.onlineBg,
      ),
      _EarningsItem(
        label: "This Week",
        value: '₹${state.weekEarnings.toStringAsFixed(2)}',
        icon: Icons.calendar_view_week_rounded,
        color: AppColors.primary,
        bg: isDark
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.primaryContainer,
      ),
      _EarningsItem(
        label: "This Month",
        value: '₹${state.monthEarnings.toStringAsFixed(2)}',
        icon: Icons.calendar_month_rounded,
        color: AppColors.amber,
        bg: isDark
            ? AppColors.amber.withValues(alpha: 0.1)
            : AppColors.amberContainer,
      ),
      _EarningsItem(
        label: "Completed Orders",
        value: '${state.completedOrders}',
        icon: Icons.task_alt_rounded,
        color: AppColors.busy,
        bg: isDark
            ? AppColors.busy.withValues(alpha: 0.1)
            : AppColors.busyBg,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.45,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final it = items[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFE8F0EE),
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: it.color.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: it.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(it.icon, size: 16, color: it.color),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      it.value,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  Text(
                    it.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EarningsItem {
  const _EarningsItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bg,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bg;
}

// ── Transaction tile ──────────────────────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.item, required this.isDark});
  final Map<String, dynamic> item;
  final bool isDark;

  /// Bank account shown masked — only the last 2 digits are visible.
  String get _maskedAccount {
    final acc = (item['bank_account'] ?? '').toString().replaceAll(RegExp(r'\s'), '');
    if (acc.isEmpty) return '';
    final last2 = acc.length <= 2 ? acc : acc.substring(acc.length - 2);
    final masked = '${'•' * (acc.length <= 2 ? 4 : (acc.length - 2).clamp(4, 12))}$last2';
    final bank = (item['bank_name'] ?? '').toString().trim();
    return bank.isEmpty ? 'A/C $masked' : '$bank • $masked';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = item['status']?.toString() ?? 'pending';
    final statusColor = status == 'completed'
        ? AppColors.online
        : status == 'rejected'
            ? AppColors.error
            : AppColors.amber;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE8F0EE),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.receipt_long_rounded,
                size: 16, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹${item['amount'] ?? '0.00'}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                if (_maskedAccount.isNotEmpty)
                  Text(
                    _maskedAccount,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5),
                  ),
                Text(
                  item['requested_at']?.toString() ?? '—',
                  style: TextStyle(
                      fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared ────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
                color:
                    Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
