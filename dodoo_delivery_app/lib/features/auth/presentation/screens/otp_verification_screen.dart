import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/fade_in.dart';
import '../controllers/auth_controller.dart';
import '../controllers/auth_state.dart';
import '../widgets/otp_input_widget.dart';
import 'account_status_screen.dart';
import 'rider_registration_screen.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.phone,
    this.isNewRegistration = false,
    this.devOtp = '',
  });

  final String phone;
  final bool isNewRegistration;
  /// OTP returned by the server (demo only). Pre-fills the boxes.
  final String devOtp;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _otpKey = GlobalKey<OtpInputWidgetState>();
  String _otp = '';
  String _currentDevOtp = '';
  int _resendSeconds = 60;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _currentDevOtp = widget.devOtp;
    _startResendTimer();

    // Auto-fill boxes after first frame
    if (_currentDevOtp.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _otpKey.currentState?.prefill(_currentDevOtp);
        setState(() => _otp = _currentDevOtp);
      });
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_resendSeconds == 0) {
        t.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  void _verify() {
    if (_otp.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 4-digit OTP')),
      );
      return;
    }
    ref.read(authControllerProvider.notifier).verifyOtp(
          phone: widget.phone,
          otp: _otp,
        );
  }

  Future<void> _resend() async {
    _otpKey.currentState?.clear();
    setState(() { _otp = ''; _currentDevOtp = ''; });

    final newOtp = await ref.read(authControllerProvider.notifier)
        .resendOtp(widget.phone);

    _startResendTimer();

    if (newOtp.isNotEmpty) {
      setState(() => _currentDevOtp = newOtp);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _otpKey.currentState?.prefill(newOtp);
        setState(() => _otp = newOtp);
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New OTP sent')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (_, state) {
      if (state is AuthAuthenticated) {
        final rider = state.rider;
        if (rider.isApproved) {
          Navigator.pushNamedAndRemoveUntil(
              context, '/home', (r) => false, arguments: rider);
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => AccountStatusScreen(rider: rider),
            ),
            (r) => false,
          );
        }
      } else if (state is AuthNeedsRegistration) {
        // OTP verified for a new number → go to the registration form.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RiderRegistrationScreen(phone: state.phone),
          ),
        );
      } else if (state is AuthError) {
        _otpKey.currentState?.clear();
        setState(() { _otp = ''; _currentDevOtp = ''; });
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              // Icon badge
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryLight.withValues(alpha: 0.5),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(Icons.mark_email_read_rounded,
                    size: 40, color: AppColors.onPrimary),
              ),
              const SizedBox(height: 22),
              Text(
                widget.isNewRegistration
                    ? 'Verify your number'
                    : 'Enter the code',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text.rich(
                textAlign: TextAlign.center,
                TextSpan(
                  text: 'We sent a 4-digit code to\n',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  children: [
                    TextSpan(
                      text: '+91 ${widget.phone}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1C00)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              FadeIn(
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
                    children: [
                      if (_currentDevOtp.isNotEmpty) ...[
                        _DemoOtpChip(
                          otp: _currentDevOtp,
                          onTap: () {
                            _otpKey.currentState?.prefill(_currentDevOtp);
                            setState(() => _otp = _currentDevOtp);
                          },
                        ),
                        const SizedBox(height: 18),
                      ],
                      OtpInputWidget(
                        key: _otpKey,
                        length: 4,
                        onCompleted: (otp) => setState(() => _otp = otp),
                        onChanged: (otp) => setState(() => _otp = otp),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: isLoading ? null : _verify,
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
                              : const Icon(Icons.check_circle_rounded, size: 20),
                          label: Text(
                            isLoading ? 'Verifying…' : 'Verify OTP',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _resendSeconds > 0
                          ? Text(
                              'Resend code in ${_resendSeconds}s',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 13),
                            )
                          : TextButton.icon(
                              onPressed: _resend,
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Resend OTP'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.accent,
                                textStyle: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                    ],
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

// ── Sub-widgets ───────────────────────────────────────────────────────────────

/// Tappable chip that shows the demo OTP and auto-fills on tap.
class _DemoOtpChip extends StatelessWidget {
  const _DemoOtpChip({required this.otp, required this.onTap});
  final String otp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFCD34D)),
        ),
        child: Row(
          children: [
            const Icon(Icons.developer_mode_rounded,
                size: 20, color: Color(0xFFB45309)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Demo OTP (tap to fill)',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    otp,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.touch_app_outlined,
                size: 20, color: Color(0xFFB45309)),
          ],
        ),
      ),
    );
  }
}
