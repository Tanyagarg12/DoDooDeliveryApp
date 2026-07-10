import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/store_categories.dart';
import '../../../../core/firebase/store_firestore_service.dart';
import '../../../../core/firebase/store_wallet_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/support_modal.dart';
import '../../domain/entities/store_entity.dart';
import '../../domain/entities/store_wallet_entity.dart';
import '../controllers/store_auth_controller.dart';
import 'store_phone_input_screen.dart';

/// Store version shown in the About row (kept in sync with pubspec).
const String _kStoreAppVersion = 'v1.3.5';

/// Store settings & profile — editable store details, bank accounts, app
/// preferences (dark mode), help and logout.
class StoreSettingsScreen extends ConsumerStatefulWidget {
  const StoreSettingsScreen({super.key, required this.store});
  final StoreEntity store;

  @override
  ConsumerState<StoreSettingsScreen> createState() =>
      _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends ConsumerState<StoreSettingsScreen> {
  final _svc = StoreWalletService.instance;
  final _storeSvc = StoreFirestoreService.instance;
  late StoreEntity _store = widget.store; // local, updated on edit
  List<StoreBankAccount>? _accounts; // null = still loading

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    if (mounted) setState(() => _accounts = null);
    final list = await _svc.getBankAccounts(widget.store.id);
    if (!mounted) return;
    setState(() => _accounts = list);
  }

  /// Optimistically reflect a saved account in the list so it shows instantly,
  /// independent of any read-after-write delay.
  void _onAccountSaved(StoreBankAccount acc) {
    final current = [...?_accounts];
    final becomesDefault =
        acc.isDefault || current.where((a) => a.id != acc.id).isEmpty;

    StoreBankAccount withDefault(StoreBankAccount a, bool d) =>
        StoreBankAccount(
          id: a.id,
          holderName: a.holderName,
          accountNumber: a.accountNumber,
          ifscCode: a.ifscCode,
          isDefault: d,
        );

    var list = becomesDefault
        ? current
              .map((a) => a.id == acc.id ? a : withDefault(a, false))
              .toList()
        : current;
    final display = withDefault(acc, becomesDefault);
    final idx = list.indexWhere((a) => a.id == acc.id);
    if (idx >= 0) {
      list[idx] = display;
    } else {
      list = [...list, display];
    }
    setState(() => _accounts = list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: const [SupportIconButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editAccount(null),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Add bank account'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _profileHero(),
          const SizedBox(height: 14),
          _storeStatsRow(),
          const SizedBox(height: 20),
          _storeDetailsCard(),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _sectionTitle('Bank Accounts')),
              if (_accounts != null && _accounts!.isNotEmpty)
                GestureDetector(
                  onTap: _loadAccounts,
                  child: const Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _bankSection(),
          const SizedBox(height: 20),
          _actionsCard(),
          const SizedBox(height: 18),
          _versionFooter(),
        ],
      ),
    );
  }

  // ── Profile hero (with edit) ────────────────────────────────────────────────

  Widget _profileHero() {
    final store = _store;
    final cat = StoreCategories.byKey(store.category);
    final photo = store.storefrontPhotoUrl ?? '';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
            child: photo.isEmpty
                ? Icon(cat.icon, color: AppColors.onPrimary, size: 32)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.storeName.isEmpty ? 'My Store' : store.storeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    cat.label,
                    style: const TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '+91 ${store.phone}',
                  style: TextStyle(
                    color: AppColors.onPrimary.withValues(alpha: 0.85),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit details',
            onPressed: _editStoreDetails,
            icon: const Icon(Icons.edit_rounded, color: AppColors.onPrimary),
          ),
        ],
      ),
    );
  }

  Widget _storeStatsRow() {
    final store = _store;
    return Row(
      children: [
        _miniStat(
          Icons.star_rounded,
          const Color(0xFFF59E0B),
          'Rating',
          store.rating.toStringAsFixed(1),
        ),
        const SizedBox(width: 12),
        _miniStat(
          Icons.receipt_long_rounded,
          AppColors.primary,
          'Orders',
          '${store.totalOrders}',
        ),
        const SizedBox(width: 12),
        _miniStat(
          store.isApproved
              ? Icons.verified_rounded
              : Icons.hourglass_top_rounded,
          store.isApproved ? const Color(0xFF059669) : const Color(0xFFD97706),
          'Status',
          store.isApproved ? 'Active' : 'Pending',
        ),
      ],
    );
  }

  Widget _miniStat(IconData icon, Color color, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _storeDetailsCard() {
    final store = _store;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8F0EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Store details',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              GestureDetector(
                onTap: _editStoreDetails,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.edit_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _detailRow(Icons.person_rounded, 'Owner', store.ownerName),
          _detailRow(Icons.location_on_rounded, 'Address', store.address),
          if ((store.email ?? '').isNotEmpty)
            _detailRow(Icons.email_rounded, 'Email', store.email!),
          _detailRow(Icons.verified_user_rounded, 'FSSAI', store.fssaiNumber),
          _detailRow(Icons.receipt_rounded, 'GST', store.gstNumber, last: true),
        ],
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    bool last = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 62,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions (help / logout) ─────────────────────────────────────────────────

  Widget _actionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8F0EE)),
      ),
      clipBehavior: Clip.antiAlias,
      // Transparent Material so ListTile ink/splash renders in front of the
      // white background (otherwise Flutter warns it may be invisible).
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(
                Icons.support_agent_rounded,
                color: AppColors.primary,
              ),
              title: const Text('Help & Support'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showSupportSheet(context),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.error),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _versionFooter() => Center(
    child: Text(
      'DoDoo Store · $_kStoreAppVersion',
      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
    ),
  );

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(storeAuthControllerProvider.notifier).logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const StorePhoneInputScreen()),
      (_) => false,
    );
  }

  // ── Edit store details ──────────────────────────────────────────────────────

  Future<void> _editStoreDetails() async {
    final updated = await showModalBottomSheet<StoreEntity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _StoreDetailsEditor(store: _store, storeSvc: _storeSvc),
    );
    if (updated != null && mounted) setState(() => _store = updated);
  }

  // ── Bank accounts ────────────────────────────────────────────────────────

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: Colors.grey.shade700,
      ),
    ),
  );

  Widget _bankSection() {
    final accounts = _accounts;
    if (accounts == null) {
      // Bounded size — a bare CircularProgressIndicator inside a ListView
      // (unbounded height) throws "RenderBox was not laid out".
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
    if (accounts.isEmpty) return _bankEmpty();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: accounts.map(_accountTile).toList(),
    );
  }

  Widget _bankEmpty() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE8F0EE)),
    ),
    child: Column(
      children: [
        Icon(
          Icons.account_balance_rounded,
          size: 40,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 10),
        Text(
          'No bank accounts yet',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Add one to receive payouts to your bank.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _editAccount(null),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add bank account'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _accountTile(StoreBankAccount acc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: acc.isDefault ? AppColors.primary : const Color(0xFFE8F0EE),
          width: acc.isDefault ? 1.5 : 1,
        ),
        boxShadow: acc.isDefault
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  size: 18,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      acc.holderName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${acc.accountNumber.substring(acc.accountNumber.length - 4).padLeft(acc.accountNumber.length, '*')} • ${acc.ifscCode}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (acc.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Default',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _editAccount(acc),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmDelete(acc),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editAccount(StoreBankAccount? existing) async {
    final nameCtrl = TextEditingController(text: existing?.holderName ?? '');
    final accountCtrl = TextEditingController(
      text: existing?.accountNumber ?? '',
    );
    final ifscCtrl = TextEditingController(text: existing?.ifscCode ?? '');
    bool isDefault = existing?.isDefault ?? false;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(
          existing == null ? 'Add bank account' : 'Edit bank account',
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Account holder name',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: accountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Account number',
                    ),
                    validator: (v) {
                      final a = v?.trim() ?? '';
                      if (a.isEmpty) return 'Enter account number';
                      if (a.length < 9 || a.length > 18) {
                        return 'Invalid account number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: ifscCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'IFSC code'),
                    validator: (v) {
                      final code = v?.trim() ?? '';
                      if (code.isEmpty) return 'Enter IFSC code';
                      if (code.length != 11) {
                        return 'IFSC must be 11 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  StatefulBuilder(
                    builder: (bCtx, setBState) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: isDefault,
                          onChanged: (v) =>
                              setBState(() => isDefault = v ?? false),
                        ),
                        const Text(
                          'Set as default',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final navigator = Navigator.of(dCtx);
              final messenger = ScaffoldMessenger.of(context);
              final newAccount = StoreBankAccount(
                id:
                    existing?.id ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                holderName: nameCtrl.text.trim(),
                accountNumber: accountCtrl.text.trim(),
                ifscCode: ifscCtrl.text.trim().toUpperCase(),
                isDefault: isDefault,
              );
              try {
                await _svc.saveBankAccount(widget.store.id, newAccount);
                if (!mounted) return;
                navigator.pop();
                _onAccountSaved(newAccount); // optimistic — show immediately
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      existing == null
                          ? 'Bank account added'
                          : 'Bank account updated',
                    ),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Failed to save: ${e.toString()}'),
                    backgroundColor: Colors.red.shade700,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            },
            child: Text(existing == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(StoreBankAccount acc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text('Remove ${acc.holderName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _svc.deleteBankAccount(widget.store.id, acc.id);
      if (!mounted) return;
      setState(
        () =>
            _accounts = (_accounts ?? []).where((a) => a.id != acc.id).toList(),
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Bank account deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to delete: ${e.toString()}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }
}

// ── Store details editor sheet ──────────────────────────────────────────────

class _StoreDetailsEditor extends StatefulWidget {
  const _StoreDetailsEditor({required this.store, required this.storeSvc});
  final StoreEntity store;
  final StoreFirestoreService storeSvc;

  @override
  State<_StoreDetailsEditor> createState() => _StoreDetailsEditorState();
}

class _StoreDetailsEditorState extends State<_StoreDetailsEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.store.storeName);
  late final _firstCtrl = TextEditingController(
    text: widget.store.ownerFirstName,
  );
  late final _lastCtrl = TextEditingController(
    text: widget.store.ownerLastName,
  );
  late final _addressCtrl = TextEditingController(text: widget.store.address);
  late final _emailCtrl = TextEditingController(text: widget.store.email ?? '');
  late String _category = widget.store.category;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _addressCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final email = _emailCtrl.text.trim();
    try {
      await widget.storeSvc.updateStore({
        'store_name': _nameCtrl.text.trim(),
        'owner_first_name': _firstCtrl.text.trim(),
        'owner_last_name': _lastCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'category': _category,
        'email': email.isEmpty ? null : email,
      }, widget.store.id);
      final updated = widget.store.copyWith(
        storeName: _nameCtrl.text.trim(),
        ownerFirstName: _firstCtrl.text.trim(),
        ownerLastName: _lastCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        category: _category,
        email: email,
      );
      navigator.pop(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Could not save. Check your connection.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Edit store details',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Your phone, FSSAI and GST can’t be changed here.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Store name',
                  prefixIcon: Icon(Icons.storefront_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter store name' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Owner first name',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Owner last name',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: StoreCategories.all
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.key,
                        child: Row(
                          children: [
                            Icon(c.icon, size: 16, color: AppColors.accent),
                            const SizedBox(width: 8),
                            Text(c.label),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.location_on_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter address' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  prefixIcon: Icon(Icons.email_rounded),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save changes',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
