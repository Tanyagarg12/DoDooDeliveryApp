import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/fade_in.dart';
import '../../../../core/widgets/support_modal.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/screens/phone_input_screen.dart';
import '../controllers/rider_dashboard_controller.dart';
import '../controllers/rider_dashboard_state.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  // Personal info
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  final _aadhaarCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  bool _editPersonal = false;
  bool _savingPersonal = false;
  // The photo is changed directly (not via the "Edit" mode) and submitted for
  // admin approval on its own — like a document's "Replace".
  bool _uploadingPhoto = false;

  // Document upload loading flags
  bool _uploadingAadharFront = false;
  bool _uploadingAadharBack = false;
  bool _uploadingLicense = false;

  @override
  void initState() {
    super.initState();
    _syncControllers(ref.read(riderDashboardProvider));
  }

  /// Mirrors the live (approved) rider values into the controllers. Used while
  /// the fields are read-only so they always reflect the current profile —
  /// including right after the admin approves a change. Guarded so we don't
  /// clobber the text (and cursor) with an identical value on every rebuild.
  void _syncControllers(RiderDashboardState s) {
    void setIf(TextEditingController c, String v) {
      if (c.text != v) c.text = v;
    }

    setIf(_firstNameCtrl, s.firstName);
    setIf(_lastNameCtrl, s.lastName);
    setIf(_emailCtrl, s.email);
    setIf(_addressCtrl, s.address);
    setIf(_upiCtrl, s.upiNumber);
    setIf(_aadhaarCtrl, s.aadhaarNumber);
    setIf(_licenseCtrl, s.drivingLicenseNumber);
  }

  /// Enters edit mode, prefilling each field with its pending (awaiting-
  /// approval) value if one exists, otherwise the live value — so the rider
  /// continues editing what they already submitted.
  void _enterEdit(RiderDashboardState s) {
    _firstNameCtrl.text = s.pendingValue('first_name') ?? s.firstName;
    _lastNameCtrl.text = s.pendingValue('last_name') ?? s.lastName;
    _emailCtrl.text = s.pendingValue('email') ?? s.email;
    _addressCtrl.text = s.pendingValue('address') ?? s.address;
    _upiCtrl.text = s.pendingValue('upi_number') ?? s.upiNumber;
    _aadhaarCtrl.text = s.pendingValue('aadhar_number') ?? s.aadhaarNumber;
    _licenseCtrl.text =
        s.pendingValue('driving_license_number') ?? s.drivingLicenseNumber;
    setState(() => _editPersonal = true);
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _upiCtrl.dispose();
    _aadhaarCtrl.dispose();
    _licenseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(riderDashboardProvider);
    // While the fields are read-only keep them in step with the live doc, so an
    // admin-approved change shows up here automatically on the next refresh.
    if (!_editPersonal) _syncControllers(state);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDarkMode = ref.watch(themeModeProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── Profile header (normal scroll — no collapse clipping) ────────
          SliverToBoxAdapter(
            child: _ProfileHeader(state: state, isDark: isDark),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                FadeIn(child: _StatsRow(state: state)),
                const SizedBox(height: 20),
                FadeIn(index: 1, child: _AccountStatusCard(state: state)),
                const SizedBox(height: 20),

                // ── Profile photo (its own section) ───────────────────────
                FadeIn(
                  index: 2,
                  child: _PhotoSection(
                    state: state,
                    uploading: _uploadingPhoto,
                    onChange: _uploadingPhoto ? null : _changePhoto,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Personal information ──────────────────────────────────
                _SectionCard(
                  title: 'Personal Information',
                  icon: Icons.person_rounded,
                  trailing: !_editPersonal
                      ? TextButton.icon(
                          onPressed: () => _enterEdit(state),
                          icon:
                              const Icon(Icons.edit_rounded, size: 14),
                          label: const Text('Edit'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: cs.primary,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () {
                                _syncControllers(state);
                                setState(() => _editPersonal = false);
                              },
                              style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: _savingPersonal
                                  ? null
                                  : _savePersonal,
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: cs.primary,
                              ),
                              child: _savingPersonal
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Text('Save',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                  children: [
                    if (state.hasPendingProfileChanges && !_editPersonal)
                      const _PendingApprovalBanner(),
                    _ProfileField(
                      ctrl: _firstNameCtrl,
                      label: 'First Name',
                      icon: Icons.badge_rounded,
                      readOnly: !_editPersonal,
                      pendingValue:
                          _editPersonal ? null : state.pendingValue('first_name'),
                    ),
                    _ProfileField(
                      ctrl: _lastNameCtrl,
                      label: 'Last Name',
                      icon: Icons.badge_outlined,
                      readOnly: !_editPersonal,
                      pendingValue:
                          _editPersonal ? null : state.pendingValue('last_name'),
                    ),
                    _ProfileField(
                      ctrl: _emailCtrl,
                      label: 'Email',
                      icon: Icons.email_rounded,
                      readOnly: !_editPersonal,
                      keyboardType: TextInputType.emailAddress,
                      pendingValue:
                          _editPersonal ? null : state.pendingValue('email'),
                    ),
                    _ProfileField(
                      ctrl: _addressCtrl,
                      label: 'Address',
                      icon: Icons.home_rounded,
                      readOnly: !_editPersonal,
                      maxLines: 2,
                      pendingValue:
                          _editPersonal ? null : state.pendingValue('address'),
                    ),
                    _ProfileField(
                      ctrl: _upiCtrl,
                      label: 'GPay / PhonePe number',
                      icon: Icons.account_balance_wallet_rounded,
                      readOnly: !_editPersonal,
                      keyboardType: TextInputType.phone,
                      pendingValue:
                          _editPersonal ? null : state.pendingValue('upi_number'),
                    ),
                    _ProfileField(
                      ctrl: _aadhaarCtrl,
                      label: 'Aadhaar Number',
                      icon: Icons.credit_card_rounded,
                      readOnly: !_editPersonal,
                      keyboardType: TextInputType.number,
                      pendingValue: _editPersonal
                          ? null
                          : state.pendingValue('aadhar_number'),
                    ),
                    _ProfileField(
                      ctrl: _licenseCtrl,
                      label: 'Driving License Number',
                      icon: Icons.drive_eta_rounded,
                      readOnly: !_editPersonal,
                      pendingValue: _editPersonal
                          ? null
                          : state.pendingValue('driving_license_number'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Documents ─────────────────────────────────────────────
                FadeIn(
                  index: 3,
                  child: _DocumentsCard(
                    state: state,
                    uploadingAadharFront: _uploadingAadharFront,
                    uploadingAadharBack: _uploadingAadharBack,
                    uploadingLicense: _uploadingLicense,
                    onReplaceAadharFront: () => _replaceDoc('aadhar_front'),
                    onReplaceAadharBack: () => _replaceDoc('aadhar_back'),
                    onReplaceLicense: () => _replaceDoc('license'),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Settings ─────────────────────────────────────────────
                _SectionCard(
                  title: 'Settings',
                  icon: Icons.settings_rounded,
                  children: [
                    _SettingsTile(
                      icon: isDarkMode
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      title: 'Dark Mode',
                      trailing: Switch(
                        value: isDarkMode,
                        onChanged: (v) =>
                            ref.read(themeModeProvider.notifier).state = v,
                        activeThumbColor: cs.primary,
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: 'App Version',
                      trailing: Text('v1.3.5',
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 13)),
                    ),
                    const Divider(height: 8, indent: 16, endIndent: 16),
                    _SettingsTile(
                      icon: Icons.support_agent_rounded,
                      title: 'Help & Support',
                      onTap: () => showSupportSheet(context),
                      trailing: Icon(Icons.chevron_right_rounded,
                          size: 18, color: cs.onSurfaceVariant),
                    ),
                    const Divider(height: 8, indent: 16, endIndent: 16),
                    _SettingsTile(
                      icon: Icons.logout_rounded,
                      title: 'Logout',
                      color: AppColors.error,
                      onTap: () => _logout(context),
                      trailing: Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppColors.error),
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  /// Picks a new profile photo and submits it straight to the admin-approval
  /// queue (like a document's "Replace"). The live photo stays until approved.
  Future<void> _changePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    final ok = await ref.read(riderDashboardProvider.notifier).saveProfile(
          fields: const <String, String>{},
          photo: picked,
        );
    if (!mounted) return;
    setState(() => _uploadingPhoto = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Photo submitted — pending admin approval.'
            : 'Upload failed. Please try again.'),
        backgroundColor: ok ? null : Colors.red.shade700,
      ),
    );
  }

  Future<void> _savePersonal() async {
    setState(() => _savingPersonal = true);
    final ok = await ref.read(riderDashboardProvider.notifier).saveProfile(
      fields: {
        'first_name': _firstNameCtrl.text.trim(),
        'last_name': _lastNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'upi_number': _upiCtrl.text.trim(),
        'aadhar_number': _aadhaarCtrl.text.trim(),
        'driving_license_number': _licenseCtrl.text.trim(),
      },
    );
    if (!mounted) return;
    setState(() {
      _savingPersonal = false;
      if (ok) _editPersonal = false;
    });
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Changes submitted for admin approval. Your current details '
              'stay active until they\'re approved.'),
        ),
      );
    }
  }

  Future<void> _replaceDoc(String docType) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    setState(() {
      if (docType == 'aadhar_front') _uploadingAadharFront = true;
      if (docType == 'aadhar_back') _uploadingAadharBack = true;
      if (docType == 'license') _uploadingLicense = true;
    });

    final ok = await ref.read(riderDashboardProvider.notifier).saveDocument(
          docType: docType,
          image: picked,
        );

    if (!mounted) return;
    setState(() {
      _uploadingAadharFront = false;
      _uploadingAadharBack = false;
      _uploadingLicense = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Document uploaded — pending admin approval.'
            : 'Upload failed. Please try again.'),
        backgroundColor: ok ? null : Colors.red.shade700,
      ),
    );
  }

  Future<void> _logout(BuildContext ctx) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm != true || !ctx.mounted) return;
    await ref.read(authControllerProvider.notifier).logout();
    if (!ctx.mounted) return;
    Navigator.pushAndRemoveUntil(
      ctx,
      MaterialPageRoute(builder: (_) => const PhoneInputScreen()),
      (_) => false,
    );
  }
}

// ── Profile header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.state,
    required this.isDark,
  });

  final RiderDashboardState state;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const textColor = AppColors.onPrimary;
    const textMuted = Color(0xFF3A3D00);

    // Show the pending (submitted) photo if there is one, else the live photo.
    // Editing happens in the dedicated Profile Photo section below.
    final pendingPhoto = state.pendingValue('profile_picture_url');
    final displayUrl = (pendingPhoto != null && pendingPhoto.isNotEmpty)
        ? pendingPhoto
        : state.profilePictureUrl;

    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.brandSplash,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, topInset + 20, 20, 22),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.onPrimary.withValues(alpha: 0.3), width: 3),
              image: displayUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(displayUrl), fit: BoxFit.cover)
                  : null,
              color: AppColors.onPrimary.withValues(alpha: 0.12),
            ),
            child: displayUrl.isEmpty
                ? Center(
                    child: Text(
                      state.firstName.isNotEmpty
                          ? state.firstName[0].toUpperCase()
                          : 'R',
                      style: const TextStyle(
                          color: textColor,
                          fontSize: 32,
                          fontWeight: FontWeight.w800),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(state.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('+91 ${state.phone}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: textMuted, fontSize: 13)),
                const SizedBox(height: 6),
                // While the rider has changes awaiting review, show a pending
                // status instead of "Verified" — it flips back to verified once
                // the admin approves.
                if (state.hasPendingReview)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.onPrimary.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.hourglass_top_rounded,
                            size: 12, color: Color(0xFFB45309)),
                        SizedBox(width: 4),
                        Text('Updates pending review',
                            style: TextStyle(
                                color: Color(0xFF92400E),
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  )
                else
                  _VerifiedBadge(
                      isVerified: state.isVerified,
                      isDocVerified: state.isDocumentVerified),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dedicated "Profile Photo" section — a clear, separate place to view and
/// change the photo (independent of the Personal Information edit mode). A new
/// photo is submitted for admin approval and shows a pending status until then.
class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.state,
    required this.uploading,
    required this.onChange,
  });
  final RiderDashboardState state;
  final bool uploading;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pending = state.pendingValue('profile_picture_url');
    final hasPending = pending != null && pending.isNotEmpty;
    final displayUrl = hasPending ? pending : state.profilePictureUrl;

    return _SectionCard(
      title: 'Profile Photo',
      icon: Icons.photo_camera_rounded,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              ClipOval(
                child: displayUrl.isNotEmpty
                    ? Image.network(
                        displayUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholder(cs),
                      )
                    : _placeholder(cs),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasPending)
                      _status(Icons.hourglass_top_rounded, AppColors.amber,
                          'Pending admin approval')
                    else if (displayUrl.isNotEmpty)
                      _status(Icons.check_circle_rounded, AppColors.online,
                          'Photo added')
                    else
                      _status(Icons.info_outline_rounded,
                          cs.onSurfaceVariant, 'No photo yet'),
                    const SizedBox(height: 4),
                    Text(
                      'A new photo stays pending until the admin approves it.',
                      style:
                          TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              uploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : OutlinedButton.icon(
                      onPressed: onChange,
                      icon: const Icon(Icons.photo_camera_rounded, size: 16),
                      label: const Text('Change'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        side:
                            BorderSide(color: cs.primary.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _placeholder(ColorScheme cs) => Container(
        width: 60,
        height: 60,
        color: cs.surfaceContainerHighest,
        child: Icon(Icons.person_rounded, color: cs.onSurfaceVariant),
      );

  Widget _status(IconData icon, Color color, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12.5,
                    color: color,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      );
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge(
      {required this.isVerified, required this.isDocVerified});
  final bool isVerified;
  final bool isDocVerified;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (isVerified) _Badge(Icons.verified_rounded, 'Verified', AppColors.online),
        if (isVerified && isDocVerified) const SizedBox(width: 6),
        if (isDocVerified)
          _Badge(Icons.description_rounded, 'Docs OK', AppColors.amber),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.onPrimary),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.state});
  final RiderDashboardState state;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE8F0EE),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatCell(
                value: state.totalOrders.toString(),
                label: 'Total Orders',
                icon: Icons.local_shipping_rounded,
                color: AppColors.primary),
          ),
          _Divider(),
          Expanded(
            child: _StatCell(
                value: state.rating.toStringAsFixed(1),
                label: 'Rating',
                icon: Icons.star_rounded,
                color: AppColors.amber),
          ),
          _Divider(),
          Expanded(
            child: _StatCell(
                value: '₹${state.walletBalance.toStringAsFixed(0)}',
                label: 'Wallet',
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.online),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1, height: 40, color: Theme.of(context).dividerColor);
}

class _StatCell extends StatelessWidget {
  const _StatCell(
      {required this.value,
      required this.label,
      required this.icon,
      required this.color});
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 6),
        Text(value,
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text(label,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ],
    );
  }
}

// ── Account status card ───────────────────────────────────────────────────────

class _AccountStatusCard extends StatelessWidget {
  const _AccountStatusCard({required this.state});
  final RiderDashboardState state;

  static const _configs = {
    'approved': (
      color: AppColors.online,
      bg: AppColors.onlineBg,
      icon: Icons.verified_rounded,
      label: 'Account Approved',
      msg: 'Your account is active. You can accept orders.'
    ),
    'pending': (
      color: AppColors.amber,
      bg: AppColors.amberContainer,
      icon: Icons.hourglass_top_rounded,
      label: 'Pending Approval',
      msg: 'Your account is under review by our admin team.'
    ),
    'rejected': (
      color: AppColors.error,
      bg: AppColors.errorBg,
      icon: Icons.cancel_rounded,
      label: 'Application Rejected',
      msg: 'Your application was rejected. Contact support.'
    ),
    'suspended': (
      color: AppColors.busy,
      bg: AppColors.busyBg,
      icon: Icons.block_rounded,
      label: 'Account Suspended',
      msg: 'Your account is suspended. Contact support.'
    ),
  };

  @override
  Widget build(BuildContext context) {
    final cfg = _configs[state.accountStatus] ?? _configs['pending']!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? cfg.color.withValues(alpha: 0.1) : cfg.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cfg.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cfg.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(cfg.icon, color: cfg.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cfg.label,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: cfg.color)),
                const SizedBox(height: 2),
                Text(cfg.msg,
                    style: TextStyle(
                        fontSize: 12,
                        color: cfg.color.withValues(alpha: 0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Documents card ────────────────────────────────────────────────────────────

class _DocumentsCard extends StatelessWidget {
  const _DocumentsCard({
    required this.state,
    required this.uploadingAadharFront,
    required this.uploadingAadharBack,
    required this.uploadingLicense,
    required this.onReplaceAadharFront,
    required this.onReplaceAadharBack,
    required this.onReplaceLicense,
  });

  final RiderDashboardState state;
  final bool uploadingAadharFront;
  final bool uploadingAadharBack;
  final bool uploadingLicense;
  final VoidCallback onReplaceAadharFront;
  final VoidCallback onReplaceAadharBack;
  final VoidCallback onReplaceLicense;

  /// Effective per-document status: once the admin has marked the rider's docs
  /// verified (is_document_verified), show each as Verified — unless that
  /// specific doc was rejected (then it still needs a re-upload).
  String _effStatus(String key) {
    final raw = state.docStatus(key);
    if (raw == 'rejected') return 'rejected';
    if (state.isDocumentVerified) return 'verified';
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE8F0EE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(Icons.folder_copy_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 8),
                const Text('Documents',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
          ),

          // Message from the admin (e.g. "Aadhaar is blurry, please re-upload").
          if (state.adminComment.trim().isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.campaign_rounded,
                      size: 16, color: Color(0xFFB45309)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Message from DoDoo',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF92400E))),
                        const SizedBox(height: 2),
                        Text(state.adminComment.trim(),
                            style: const TextStyle(
                                fontSize: 12.5, color: Color(0xFF92400E))),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Replacing a document will require admin re-approval.',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 8),

          _DocTile(
            label: 'Aadhaar Card — Front',
            icon: Icons.credit_card_outlined,
            imageUrl: state.aadhaarFrontUrl,
            status: _effStatus('aadhar_front'),
            uploading: uploadingAadharFront,
            onReplace: onReplaceAadharFront,
          ),
          _DocTile(
            label: 'Aadhaar Card — Back',
            icon: Icons.credit_card_outlined,
            imageUrl: state.aadhaarBackUrl,
            status: _effStatus('aadhar_back'),
            uploading: uploadingAadharBack,
            onReplace: onReplaceAadharBack,
          ),
          _DocTile(
            label: 'Driving License',
            icon: Icons.drive_eta_outlined,
            imageUrl: state.licenseImageUrl,
            status: _effStatus('license'),
            uploading: uploadingLicense,
            onReplace: onReplaceLicense,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({
    required this.label,
    required this.icon,
    required this.imageUrl,
    required this.status,
    required this.uploading,
    required this.onReplace,
  });

  final String label;
  final IconData icon;
  final String imageUrl;
  final String status; // 'verified' | 'rejected' | 'pending'
  final bool uploading;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasImage = imageUrl.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          // Thumbnail or placeholder
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: hasImage
                ? Image.network(
                    imageUrl,
                    width: 56,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(cs),
                  )
                : _placeholder(cs),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                if (!hasImage)
                  Text('Not uploaded',
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant))
                else
                  _StatusPill(status: status),
              ],
            ),
          ),
          uploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : OutlinedButton(
                  onPressed: onReplace,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    // Finite min-size — overrides the theme's Size.fromHeight
                    // (infinite width) so the button fits inside this Row.
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    side: BorderSide(
                        color: cs.primary.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Replace', style: TextStyle(fontSize: 12)),
                ),
        ],
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) {
    return Container(
      width: 56,
      height: 44,
      color: cs.surfaceContainerHighest,
      child: Icon(icon, size: 22, color: cs.onSurfaceVariant),
    );
  }
}

/// Per-document verification chip. Reflects the admin's decision and updates
/// automatically (the dashboard refreshes the rider doc), so once the admin
/// approves/rejects, the "Pending review" line is replaced here on its own.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon, String label) = switch (status) {
      'verified' => (AppColors.online, Icons.verified_rounded, 'Verified'),
      'rejected' => (
          AppColors.error,
          Icons.cancel_rounded,
          'Rejected — please re-upload'
        ),
      _ => (AppColors.amber, Icons.hourglass_top_rounded, 'Pending review'),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE8F0EE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
            child: Row(
              children: [
                Icon(icon, size: 16, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...children,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.readOnly = false,
    this.keyboardType,
    this.maxLines = 1,
    this.pendingValue,
  });
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  /// When true the field is visible and shows its value but cannot be edited.
  final bool readOnly;
  final TextInputType? keyboardType;
  final int maxLines;

  /// A not-yet-approved value for this field. When set, shows an amber note
  /// under the (current) value so the rider knows an edit is under review.
  final String? pendingValue;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showPending = pendingValue != null && pendingValue!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: ctrl,
            readOnly: readOnly,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: readOnly
                ? TextStyle(color: cs.onSurface.withValues(alpha: 0.7))
                : null,
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon, size: 18),
              filled: true,
              fillColor: readOnly
                  ? cs.surfaceContainerHighest.withValues(alpha: 0.4)
                  : null,
              enabledBorder: readOnly
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.5)),
                    )
                  : null,
            ),
          ),
          if (showPending)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded,
                      size: 12, color: AppColors.amber),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Pending approval: ${pendingValue!}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.amber,
                          fontWeight: FontWeight.w600),
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

/// Small banner shown at the top of the Personal Information card when the
/// rider has profile edits waiting for admin approval.
class _PendingApprovalBanner extends StatelessWidget {
  const _PendingApprovalBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.hourglass_top_rounded, size: 16, color: Color(0xFFB45309)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Your edits are awaiting admin approval. Your current details '
              'stay active everywhere until they\'re approved.',
              style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.trailing,
    this.onTap,
    this.color,
  });
  final IconData icon;
  final String title;
  final Widget trailing;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = color ?? cs.onSurfaceVariant;
    final tile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: effectiveColor),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: color))),
          trailing,
        ],
      ),
    );
    if (onTap == null) return tile;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: tile,
    );
  }
}
