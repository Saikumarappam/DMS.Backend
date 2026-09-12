class Validators {
  Validators._();

  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _mobileRegex = RegExp(r'^[6-9]\d{9}$');
  static final RegExp _panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
  static final RegExp _gstRegex = RegExp(
    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
  );
  static final RegExp _upperRegex = RegExp(r'[A-Z]');
  static final RegExp _lowerRegex = RegExp(r'[a-z]');
  static final RegExp _digitRegex = RegExp(r'[0-9]');
  static final RegExp _specialRegex = RegExp(r'[^a-zA-Z0-9]');

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field is required';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!_emailRegex.hasMatch(value.trim())) {
      return 'Invalid email address';
    }
    return null;
  }

  static String? mobile(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Mobile number is required';
    }
    if (!_mobileRegex.hasMatch(value.trim())) {
      return 'Invalid mobile number';
    }
    return null;
  }

  static String? pan(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'User ID (PAN) is required';
    }
    final pan = value.trim().toUpperCase();
    if (!_panRegex.hasMatch(pan)) {
      return 'Invalid PAN number';
    }
    return null;
  }

  static String? gst(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final gst = value.trim().toUpperCase();
    if (!_gstRegex.hasMatch(gst)) {
      return 'Invalid GST number';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (!isStrongPassword(value)) {
      return 'Password must be 8+ chars with upper, lower, digit, special';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Confirm password is required';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  static String? otp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'OTP is required';
    }
    final otp = value.trim();
    if (otp.length < 4 || otp.length > 8) {
      return 'Enter the OTP sent to your email';
    }
    return null;
  }

  static bool isStrongPassword(String password) =>
      password.length >= 8 &&
      _upperRegex.hasMatch(password) &&
      _lowerRegex.hasMatch(password) &&
      _digitRegex.hasMatch(password) &&
      _specialRegex.hasMatch(password);
}
