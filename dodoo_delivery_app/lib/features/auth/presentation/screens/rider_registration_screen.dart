import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/fade_in.dart';
import '../../../../core/widgets/support_modal.dart';
import '../../domain/entities/rider_entity.dart';
import '../controllers/auth_controller.dart';
import '../controllers/auth_state.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/document_upload_tile.dart';
import 'account_status_screen.dart';

class RiderRegistrationScreen extends ConsumerStatefulWidget {
  const RiderRegistrationScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<RiderRegistrationScreen> createState() =>
      _RiderRegistrationScreenState();
}

class _RiderRegistrationScreenState
    extends ConsumerState<RiderRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController(); // optional contact email
  final _addressCtrl = TextEditingController();
  final _aadhaarCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();

  File? _profilePic;
  File? _aadhaarFront;
  File? _aadhaarBack;
  File? _licenseImage;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _aadhaarCtrl.dispose();
    _licenseCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    // Aadhaar: a valid number OR an uploaded image is required.
    final hasAadhaarNumber = _aadhaarCtrl.text.trim().isNotEmpty;
    if (!hasAadhaarNumber && _aadhaarFront == null) {
      _showDocWarning('Enter your Aadhaar number or upload the Aadhaar image');
      return;
    }

    // Driving License: a valid number OR an uploaded image is required.
    final hasLicenseNumber = _licenseCtrl.text.trim().isNotEmpty;
    if (!hasLicenseNumber && _licenseImage == null) {
      _showDocWarning('Enter your license number or upload the license image');
      return;
    }

    final data = RegistrationData(
      phone: widget.phone, // E.164 phone number — auth identifier
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      email: _emailCtrl.text.trim(), // optional contact email
      address: _addressCtrl.text.trim(),
      aadhaarNumber: _aadhaarCtrl.text.replaceAll(' ', ''),
      drivingLicenseNumber: _licenseCtrl.text.trim(),
      profilePicturePath: _profilePic?.path,
      aadhaarFrontPath: _aadhaarFront?.path,
      aadhaarBackPath: _aadhaarBack?.path,
      drivingLicenseImagePath: _licenseImage?.path,
    );

    ref.read(authControllerProvider.notifier).registerRider(data);
  }

  void _showDocWarning(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.orange.shade700),
    );
  }

  Future<void> _pickProfilePic(ImageSource source) async {
    final f = await ImageUtils.pickImage(source);
    if (f != null) setState(() => _profilePic = f);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (_, state) {
      if (state is AuthAuthenticated) {
        // OTP was already verified; registration created the account.
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => AccountStatusScreen(rider: state.rider),
          ),
          (r) => false,
        );
      } else if (state is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red.shade700,
          ),
        );
        ref.read(authControllerProvider.notifier).reset();
      }
    });

    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AuthLoading;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1C00),
        title: const Text(
          'Become a Rider',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => showSupportSheet(context),
            icon: const Icon(Icons.support_agent_rounded, size: 18),
            label: const Text('Help'),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              children: [
                // Intro banner
                FadeIn(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.delivery_dining_rounded,
                            size: 38, color: AppColors.onPrimary),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Join DoDoo',
                                  style: TextStyle(
                                      color: AppColors.onPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900)),
                              const SizedBox(height: 2),
                              Text(
                                'Fill in your details — it only takes a minute.',
                                style: TextStyle(
                                    color: AppColors.onPrimary
                                        .withValues(alpha: 0.75),
                                    fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _SectionHeader(label: 'Personal Information'),
                const SizedBox(height: 12),
                _ProfilePicRow(
                  current: _profilePic,
                  onPickSource: _pickProfilePic,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'First Name *',
                        hint: 'Ravi',
                        controller: _firstNameCtrl,
                        validator: Validators.fullName,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        label: 'Last Name',
                        hint: 'Kumar',
                        controller: _lastNameCtrl,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _PhoneReadOnly(phone: widget.phone),
                const SizedBox(height: 14),
                CustomTextField(
                  label: 'Email Address (optional)',
                  hint: 'ravi@example.com',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  label: 'Full Address *',
                  hint: '123, MG Road, Bengaluru, Karnataka 560001',
                  controller: _addressCtrl,
                  validator: (v) => Validators.required(v, field: 'Address'),
                  maxLines: 3,
                  keyboardType: TextInputType.streetAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 24),
                const _SectionHeader(label: 'Aadhaar'),
                const SizedBox(height: 6),
                Text(
                  'Enter your Aadhaar number OR upload the Aadhaar image — either is fine.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Aadhaar Number',
                  hint: '1234 5678 9012',
                  controller: _aadhaarCtrl,
                  validator: Validators.aadhaarFormat,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12),
                    _AadhaarFormatter(),
                  ],
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                DocumentUploadTile(
                  label: 'Aadhaar Card — Front',
                  icon: Icons.credit_card_outlined,
                  isRequired: false,
                  onFilePicked: (f) => setState(() => _aadhaarFront = f),
                ),
                const SizedBox(height: 10),
                DocumentUploadTile(
                  label: 'Aadhaar Card — Back (optional)',
                  icon: Icons.credit_card_outlined,
                  isRequired: false,
                  onFilePicked: (f) => setState(() => _aadhaarBack = f),
                ),
                const SizedBox(height: 24),
                const _SectionHeader(label: 'Driving License'),
                const SizedBox(height: 6),
                Text(
                  'Enter your license number OR upload the license image — either is fine.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Driving License Number',
                  hint: 'KA01 20220012345',
                  controller: _licenseCtrl,
                  validator: Validators.drivingLicenseFormat,
                  keyboardType: TextInputType.text,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 -]')),
                    LengthLimitingTextInputFormatter(16),
                    _UpperCaseFormatter(),
                  ],
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 12),
                DocumentUploadTile(
                  label: 'Driving License Image',
                  icon: Icons.drive_eta_outlined,
                  isRequired: false,
                  onFilePicked: (f) => setState(() => _licenseImage = f),
                ),
                const SizedBox(height: 28),
                const _TermsNote(),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: AppColors.onPrimary),
                        )
                      : const Text('Submit Registration',
                          style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.2),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Uploading documents…'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _ProfilePicRow extends StatelessWidget {
  const _ProfilePicRow({required this.current, required this.onPickSource});
  final File? current;
  final void Function(ImageSource) onPickSource;

  void _pickSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Profile Photo',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                onPickSource(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                onPickSource(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _pickSheet(context),
            child: Stack(
              children: [
                Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryContainer,
                        const Color(0xFFFBFCEB),
                      ],
                    ),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        width: 2),
                  ),
                  child: ClipOval(
                    child: current != null
                        ? Image.file(current!, fit: BoxFit.cover)
                        : Icon(Icons.add_a_photo_rounded,
                            size: 38,
                            color: AppColors.accent.withValues(alpha: 0.8)),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        size: 17, color: AppColors.onPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            current == null ? 'Add profile photo' : 'Change photo',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _PhoneReadOnly extends StatelessWidget {
  const _PhoneReadOnly({required this.phone});
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mobile Number',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: phone,
          readOnly: true,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.phone_outlined),
            fillColor: Colors.grey.shade100,
            suffix: const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

class _TermsNote extends StatelessWidget {
  const _TermsNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryMid),
      ),
      child: Text(
        'By submitting, your account will be reviewed by an admin. You can accept orders once approved.',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
      ),
    );
  }
}

class _AadhaarFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue value) {
    final text = value.text.replaceAll(' ', '');
    final buf = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(text[i]);
    }
    final formatted = buf.toString();
    return value.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Forces driving-license input to upper case (Indian DLs are upper-case).
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue value) {
    return value.copyWith(text: value.text.toUpperCase());
  }
}
