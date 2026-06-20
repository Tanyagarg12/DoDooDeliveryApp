import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Renders N separate single-character boxes for OTP entry.
class OtpInputWidget extends StatefulWidget {
  const OtpInputWidget({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.onChanged,
  });

  final int length;
  final void Function(String otp) onCompleted;
  final void Function(String otp)? onChanged;

  @override
  State<OtpInputWidget> createState() => OtpInputWidgetState();
}

class OtpInputWidgetState extends State<OtpInputWidget> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  String get currentOtp => _controllers.map((c) => c.text).join();

  void clear() {
    for (final c in _controllers) { c.clear(); }
    _focusNodes.first.requestFocus();
  }

  void prefill(String otp) {
    final digits = otp.replaceAll(RegExp(r'\D'), '');
    for (var i = 0; i < widget.length && i < digits.length; i++) {
      _controllers[i].text = digits[i]; // set each box digit
    }
  }

  @override
  Widget build(BuildContext context) {
    const lime = Color(0xFFBABC2F);
    // Responsive: each box flexes to fit the available width, so 6 boxes never
    // overflow on a narrow phone.
    return Row(
      children: List.generate(widget.length, (i) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SizedBox(
              height: 54,
              child: TextFormField(
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(1),
                ],
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1C00)),
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: const Color(0xFFF6F7E8),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: lime, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && i < widget.length - 1) {
                    _focusNodes[i + 1].requestFocus();
                  }
                  if (value.isEmpty && i > 0) {
                    _focusNodes[i - 1].requestFocus();
                  }
                  final otp = currentOtp;
                  widget.onChanged?.call(otp);
                  if (otp.length == widget.length) {
                    widget.onCompleted(otp);
                  }
                },
              ),
            ),
          ),
        );
      }),
    );
  }
}
