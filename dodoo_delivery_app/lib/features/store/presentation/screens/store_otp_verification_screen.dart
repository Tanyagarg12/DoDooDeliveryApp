import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/support_modal.dart';
import '../controllers/store_auth_controller.dart';
import '../controllers/store_auth_state.dart';
import 'store_account_status_screen.dart';
import 'store_home_shell.dart';
import 'store_registration_screen.dart';

class StoreOtpVerificationScreen extends ConsumerStatefulWidget {
  const StoreOtpVerificationScreen({
    super.key,
    required this.phone,
    this.isNewRegistration = false,
  });

  final String phone;
  final bool isNewRegistration;

  @override
  ConsumerState<StoreOtpVerificationScreen> createState() =>
      _StoreOtpVerificationScreenState();
}

class _StoreOtpVerificationScreenState
    extends ConsumerState<StoreOtpVerificationScreen> {
  final _otpCtrl = TextEditingController();

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  void _verify() {
    final otp = _otpCtrl.text.trim();
    if (otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the OTP sent to your number')),
      );
      return;
    }
    ref
        .read(storeAuthControllerProvider.notifier)
        .verifyOtp(phone: widget.phone, otp: otp);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<StoreAuthState>(storeAuthControllerProvider, (_, state) {
      if (state is StoreAuthNeedsRegistration) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StoreRegistrationScreen(phone: state.phone),
          ),
        );
      } else if (state is StoreAuthAuthenticated) {
        // Returning, already-onboarded store → straight to home. First-time
        // approval (or pending/rejected) → the status screen.
        final approvedAndStarted =
            state.store.isApproved && state.store.hasStarted;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => approvedAndStarted
                ? StoreHomeShell(store: state.store)
                : StoreAccountStatusScreen(store: state.store),
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
        actions: const [SupportIconButton()],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // Centred vertically so the OTP entry sits in the middle of the page.
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Verify your number',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Enter the OTP sent to +91 ${widget.phone}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
            const SizedBox(height: 28),
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              autofocus: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8),
              decoration: const InputDecoration(
                hintText: '••••',
                counterText: '',
              ),
              onSubmitted: (_) => _verify(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isLoading ? null : _verify,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppColors.onPrimary),
                      )
                    : const Text('Verify',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: isLoading
                    ? null
                    : () {
                        ref
                            .read(storeAuthControllerProvider.notifier)
                            .resendOtp(widget.phone);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('OTP resent.')),
                        );
                      },
                child: const Text('Resend OTP'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
