import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/fade_in.dart';
import '../../../../core/widgets/support_modal.dart';
import '../controllers/store_auth_controller.dart';
import '../controllers/store_auth_state.dart';
import 'store_account_status_screen.dart';
import 'store_otp_verification_screen.dart';
import 'store_registration_screen.dart';

class StorePhoneInputScreen extends ConsumerStatefulWidget {
  const StorePhoneInputScreen({super.key});

  @override
  ConsumerState<StorePhoneInputScreen> createState() =>
      _StorePhoneInputScreenState();
}

class _StorePhoneInputScreenState extends ConsumerState<StorePhoneInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  bool _agreedToTerms = false;

  late final TapGestureRecognizer _termsTap =
      TapGestureRecognizer()..onTap = _openTerms;
  late final TapGestureRecognizer _privacyTap =
      TapGestureRecognizer()..onTap = _openTerms;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _openTerms() async {
    final uri = Uri.parse('https://www.dodoo.in:5678/DoDooterms.html');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the terms to continue')),
      );
      return;
    }
    final digits = _phoneCtrl.text.trim().replaceAll(RegExp(r'[^\d]'), '');
    ref.read(storeAuthControllerProvider.notifier).checkPhone(digits);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<StoreAuthState>(storeAuthControllerProvider, (_, state) {
      if (state is StoreAuthOtpSent) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoreOtpVerificationScreen(
              phone: state.phone,
              isNewRegistration: state.isNewRegistration,
            ),
          ),
        );
      } else if (state is StoreAuthNeedsRegistration) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoreRegistrationScreen(phone: state.phone),
          ),
        );
      } else if (state is StoreAuthAuthenticated) {
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.onPrimary,
        actions: const [SupportIconButton()],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(36)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
                  child: Column(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        // App logo. To change it, replace the asset file
                        // assets/images/dodoo_logo.png (see pubspec.yaml assets).
                        child: Image.asset(
                          'assets/images/dodoo_logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                              Icons.storefront_rounded,
                              size: 46,
                              color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Partner with',
                        style: TextStyle(
                          color: Color(0xE61C1D00),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Text(
                        'DoDoo Store',
                        style: TextStyle(
                          color: AppColors.onPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Receive orders, prepare, hand off to a rider.',
                        style: TextStyle(
                          color: AppColors.onPrimary.withValues(alpha: 0.7),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            FadeIn(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sign in / Register your store',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text('Enter your mobile number to get started',
                            style: TextStyle(
                                fontSize: 13, color: cs.onSurfaceVariant)),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          onFieldSubmitted: (_) => _submit(),
                          validator: (v) {
                            final d = v?.replaceAll(RegExp(r'[^\d]'), '') ?? '';
                            if (d.isEmpty) return 'Mobile number is required';
                            if (d.length != 10) {
                              return 'Enter a valid 10-digit mobile number';
                            }
                            return null;
                          },
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                          decoration: const InputDecoration(
                            labelText: 'Mobile Number',
                            hintText: 'Enter your 10-digit number',
                            prefixIcon: Padding(
                              padding: EdgeInsets.fromLTRB(14, 14, 8, 14),
                              child: Text('🇮🇳 +91',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                            ),
                            prefixIconConstraints: BoxConstraints(minWidth: 0),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _agreedToTerms,
                                onChanged: (v) =>
                                    setState(() => _agreedToTerms = v ?? false),
                                activeColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  text: 'I agree to the ',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700),
                                  children: [
                                    TextSpan(
                                      text: 'Terms',
                                      style: const TextStyle(
                                          color: AppColors.accent,
                                          fontWeight: FontWeight.w700,
                                          decoration:
                                              TextDecoration.underline),
                                      recognizer: _termsTap,
                                    ),
                                    const TextSpan(text: ' & '),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      style: const TextStyle(
                                          color: AppColors.accent,
                                          fontWeight: FontWeight.w700,
                                          decoration:
                                              TextDecoration.underline),
                                      recognizer: _privacyTap,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: isLoading ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              minimumSize: const Size.fromHeight(52),
                            ),
                            icon: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: AppColors.onPrimary),
                                  )
                                : const Icon(Icons.arrow_forward_rounded,
                                    size: 20),
                            label: Text(isLoading ? 'Sending OTP…' : 'Get OTP',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
