import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/dodoo_cities.dart';
import '../../../../core/constants/store_categories.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/fade_in.dart';
import '../../../../core/widgets/support_modal.dart';
import '../../../auth/presentation/widgets/custom_text_field.dart';
import '../../../auth/presentation/widgets/document_upload_tile.dart';
import '../../domain/entities/store_entity.dart';
import '../controllers/store_auth_controller.dart';
import '../controllers/store_auth_state.dart';
import 'store_account_status_screen.dart';

class StoreRegistrationScreen extends ConsumerStatefulWidget {
  const StoreRegistrationScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<StoreRegistrationScreen> createState() =>
      _StoreRegistrationScreenState();
}

class _StoreRegistrationScreenState
    extends ConsumerState<StoreRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollCtrl = ScrollController();

  final _storeNameCtrl = TextEditingController();
  final _ownerFirstCtrl = TextEditingController();
  final _ownerLastCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _fssaiCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _ownerIdCtrl = TextEditingController();

  String? _category;
  String _cityCode = DodooCities.defaultCity.code;
  String _idType = 'aadhaar'; // 'aadhaar' | 'pan'

  File? _storefront;
  File? _fssaiDoc;
  File? _ownerIdDoc;
  bool _docError = false;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _storeNameCtrl.dispose();
    _ownerFirstCtrl.dispose();
    _ownerLastCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _fssaiCtrl.dispose();
    _gstCtrl.dispose();
    _ownerIdCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null) {
      _warn('Please select your store category');
      return;
    }
    // All documents are mandatory.
    if (_storefront == null) {
      _flagDocs('Please add a storefront photo');
      return;
    }
    if (_fssaiDoc == null) {
      _flagDocs('Please upload the FSSAI license image');
      return;
    }
    if (_ownerIdDoc == null) {
      _flagDocs('Please upload the owner ID image');
      return;
    }

    final data = StoreRegistrationData(
      phone: widget.phone,
      ownerFirstName: _ownerFirstCtrl.text.trim(),
      ownerLastName: _ownerLastCtrl.text.trim(),
      storeName: _storeNameCtrl.text.trim(),
      category: _category!,
      email: _emailCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      cityCode: _cityCode,
      fssaiNumber: _fssaiCtrl.text.trim(),
      gstNumber: _gstCtrl.text.trim().toUpperCase(),
      ownerIdType: _idType,
      ownerIdNumber: _ownerIdCtrl.text.trim().toUpperCase(),
      storefrontPhotoPath: _storefront?.path,
      fssaiDocPath: _fssaiDoc?.path,
      ownerIdPath: _ownerIdDoc?.path,
    );
    ref.read(storeAuthControllerProvider.notifier).registerStore(data);
  }

  void _warn(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.orange.shade700),
    );
  }

  void _flagDocs(String msg) {
    setState(() => _docError = true);
    _warn(msg);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<StoreAuthState>(storeAuthControllerProvider, (_, state) {
      if (state is StoreAuthAuthenticated) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => StoreAccountStatusScreen(store: state.store),
          ),
          (r) => false,
        );
      } else if (state is StoreAuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red.shade700,
          ),
        );
        ref.read(storeAuthControllerProvider.notifier).reset();
      }
    });

    final isLoading = ref.watch(storeAuthControllerProvider) is StoreAuthLoading;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1C00),
        title: const Text('Register your store',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: const [SupportIconButton()],
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                FadeIn(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.storefront_rounded,
                            size: 34, color: AppColors.onPrimary),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Fill in your store details. An admin reviews every '
                            'new store before it goes live.',
                            style: TextStyle(
                                color: AppColors.onPrimary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                _header('Store details'),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Store Name *',
                  hint: 'e.g. Sri Sai Restaurant',
                  controller: _storeNameCtrl,
                  validator: (v) => Validators.required(v, field: 'Store name'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                _CategoryDropdown(
                  value: _category,
                  onChanged: (v) => setState(() => _category = v),
                ),
                const SizedBox(height: 14),
                _CityDropdown(
                  value: _cityCode,
                  onChanged: (v) => setState(() => _cityCode = v),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  label: 'Full Store Address *',
                  hint: 'Shop no, street, area, landmark',
                  controller: _addressCtrl,
                  validator: (v) => Validators.required(v, field: 'Address'),
                  maxLines: 3,
                  keyboardType: TextInputType.streetAddress,
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 24),
                _header('Owner details'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'Owner First Name *',
                        hint: 'First name',
                        controller: _ownerFirstCtrl,
                        validator: Validators.fullName,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        label: 'Last Name',
                        hint: 'Last name',
                        controller: _ownerLastCtrl,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _PhoneReadOnly(phone: widget.phone),
                const SizedBox(height: 14),
                CustomTextField(
                  label: 'Email (optional)',
                  hint: 'store@example.com',
                  controller: _emailCtrl,
                  validator: Validators.email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 24),
                _header('Documents & KYC'),
                const SizedBox(height: 6),
                Text(
                  'All documents are required and reviewed by the admin.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'FSSAI License Number *',
                  hint: '14-digit FSSAI number',
                  controller: _fssaiCtrl,
                  validator: Validators.fssai,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(14),
                  ],
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  label: 'GST Number *',
                  hint: 'e.g. 29ABCDE1234F1Z5',
                  controller: _gstCtrl,
                  validator: Validators.gstin,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    LengthLimitingTextInputFormatter(15),
                    _UpperCaseFormatter(),
                  ],
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 18),
                _label('Owner ID *'),
                const SizedBox(height: 8),
                _IdTypeSelector(
                  value: _idType,
                  onChanged: (v) => setState(() {
                    _idType = v;
                    _ownerIdCtrl.clear(); // format differs per ID type
                  }),
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: _idType == 'aadhaar'
                      ? 'Aadhaar Number *'
                      : 'PAN Number *',
                  hint: _idType == 'aadhaar'
                      ? '12-digit Aadhaar'
                      : 'e.g. ABCDE1234F',
                  controller: _ownerIdCtrl,
                  validator:
                      _idType == 'aadhaar' ? Validators.aadhaar : Validators.pan,
                  keyboardType: _idType == 'aadhaar'
                      ? TextInputType.number
                      : TextInputType.text,
                  inputFormatters: _idType == 'aadhaar'
                      ? [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(12),
                        ]
                      : [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9]')),
                          LengthLimitingTextInputFormatter(10),
                          _UpperCaseFormatter(),
                        ],
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 16),
                DocumentUploadTile(
                  label: 'Storefront Photo',
                  icon: Icons.storefront_outlined,
                  isRequired: true,
                  onFilePicked: (f) => setState(() {
                    _storefront = f;
                    _docError = false;
                  }),
                ),
                const SizedBox(height: 10),
                DocumentUploadTile(
                  label: 'FSSAI License Image',
                  icon: Icons.description_outlined,
                  isRequired: true,
                  onFilePicked: (f) => setState(() {
                    _fssaiDoc = f;
                    _docError = false;
                  }),
                ),
                const SizedBox(height: 10),
                DocumentUploadTile(
                  label: 'Owner ID Image (Aadhaar / PAN)',
                  icon: Icons.badge_outlined,
                  isRequired: true,
                  onFilePicked: (f) => setState(() {
                    _ownerIdDoc = f;
                    _docError = false;
                  }),
                ),
                if (_docError) ...[
                  const SizedBox(height: 8),
                  Text('All three documents are required.',
                      style: TextStyle(
                          color: Colors.red.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],

                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: AppColors.onPrimary),
                        )
                      : const Text('Submit for review',
                          style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 24),
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
                        Text('Submitting your store…'),
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

  Widget _label(String text) => Text(text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600, color: const Color(0xFF374151)));

  Widget _header(String label) => Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      );
}

/// Aadhaar / PAN toggle for the owner's ID. Changing it clears + re-validates
/// the number field per the selected type.
class _IdTypeSelector extends StatelessWidget {
  const _IdTypeSelector({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _chip('aadhaar', 'Aadhaar', Icons.credit_card_rounded)),
        const SizedBox(width: 10),
        Expanded(child: _chip('pan', 'PAN', Icons.badge_rounded)),
      ],
    );
  }

  Widget _chip(String key, String label, IconData icon) {
    final selected = value == key;
    return InkWell(
      onTap: () => onChanged(key),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryContainer : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? AppColors.primary : Colors.grey.shade300,
              width: selected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? AppColors.accent : Colors.grey),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.accent : Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}

/// Forces input to upper case (for GST + PAN).
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Store Category *',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(hintText: 'Select a category'),
          items: StoreCategories.all
              .map((c) => DropdownMenuItem(
                    value: c.key,
                    child: Row(
                      children: [
                        Icon(c.icon, size: 18, color: AppColors.accent),
                        const SizedBox(width: 10),
                        Text(c.label),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _CityDropdown extends StatelessWidget {
  const _CityDropdown({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('City *',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
          items: DodooCities.all
              .map((c) => DropdownMenuItem(
                    value: c.code,
                    child: Text('${c.name}  ·  ${c.code}'),
                  ))
              .toList(),
          onChanged: (v) => onChanged(v ?? value),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.info_outline, size: 13, color: Color(0xFF6B7280)),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'We currently serve Anantapur, Kurnool & Tadipatri.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280), fontSize: 11.5),
              ),
            ),
          ],
        ),
      ],
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
        Text('Mobile Number',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600)),
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
