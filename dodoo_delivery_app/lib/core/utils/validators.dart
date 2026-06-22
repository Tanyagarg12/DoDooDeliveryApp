class Validators {
  Validators._();

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone number is required';
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 10) return 'Enter a valid 10-digit mobile number';
    return null;
  }

  static String? otp(String? value) {
    if (value == null || value.trim().isEmpty) return 'OTP is required';
    if (value.length != 4 || !RegExp(r'^\d{4}$').hasMatch(value)) {
      return 'Enter the 4-digit OTP';
    }
    return null;
  }

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? fullName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Full name is required';
    if (value.trim().length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    final emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? aadhaar(String? value) {
    if (value == null || value.trim().isEmpty) return 'Aadhaar number is required';
    final digits = value.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{12}$').hasMatch(digits)) {
      return 'Aadhaar must be exactly 12 digits';
    }
    return null;
  }

  static String? drivingLicense(String? value) {
    if (value == null || value.trim().isEmpty) return 'Driving license number is required';
    if (value.trim().length < 5) return 'Enter a valid license number';
    return null;
  }

  /// Indian IFSC: 4 letters + 0 + 6 alphanumerics (e.g. HDFC0001234).
  static String? ifsc(String? value) {
    if (value == null || value.trim().isEmpty) return 'IFSC code is required';
    final v = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(v)) {
      return 'Enter a valid IFSC (e.g. HDFC0001234)';
    }
    return null;
  }

  static String? bankAccountNumber(String? value) {
    if (value == null || value.trim().isEmpty) return 'Account number is required';
    final digits = value.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{9,18}$').hasMatch(digits)) {
      return 'Enter a valid account number (9–18 digits)';
    }
    return null;
  }

  /// Driving licence number. Indian DL formats vary widely (MH1420110012345,
  /// DL-0420110149646, DLCAP00243142010, …), so accept any 8–20 alphanumeric
  /// string (spaces/hyphens ignored) rather than enforcing one layout.
  static String? drivingLicenseFormat(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional here
    final v = value.replaceAll(RegExp(r'[ -]'), '').toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{8,20}$').hasMatch(v)) {
      return 'Enter a valid DL number';
    }
    return null;
  }

  /// Aadhaar 12-digit, optional spaces — returns null when empty (use when the
  /// rider may upload an image instead of typing the number).
  static String? aadhaarFormat(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final digits = value.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{12}$').hasMatch(digits)) {
      return 'Aadhaar must be exactly 12 digits';
    }
    return null;
  }

  static String normalizePhone(String phone) {
    String digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('91') && digits.length == 12) {
      digits = digits.substring(2);
    }
    return digits;
  }
}
