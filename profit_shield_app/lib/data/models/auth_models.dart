import 'user_models.dart';

class LoginRequest {
  const LoginRequest({required this.username, required this.password});

  final String username;
  final String password;

  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
      };
}

class RegisterRequest {
  const RegisterRequest({
    required this.name,
    required this.mobileNumber,
    required this.email,
    required this.panNumber,
    required this.password,
    this.address,
    this.businessName,
    this.contactPersonName,
    this.gstNumber,
  });

  final String name;
  final String mobileNumber;
  final String email;
  final String panNumber;
  final String password;
  final String? address;
  final String? businessName;
  final String? contactPersonName;
  final String? gstNumber;

  Map<String, dynamic> toJson() => {
        'name': name,
        'mobileNumber': mobileNumber,
        'email': email,
        'panNumber': panNumber,
        'password': password,
        'address': address ?? '',
        'businessName': businessName ?? '',
        'contactPersonName': contactPersonName ?? name,
        if (gstNumber != null && gstNumber!.isNotEmpty) 'gstNumber': gstNumber,
      };
}

class RefreshTokenRequest {
  const RefreshTokenRequest({required this.refreshToken});

  final String refreshToken;

  Map<String, dynamic> toJson() => {'refreshToken': refreshToken};
}

class ChangePasswordRequest {
  const ChangePasswordRequest({
    required this.currentPassword,
    required this.newPassword,
  });

  final String currentPassword;
  final String newPassword;

  Map<String, dynamic> toJson() => {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      };
}

class ForgotPasswordRequest {
  const ForgotPasswordRequest({required this.email});

  final String email;

  Map<String, dynamic> toJson() => {'email': email};
}

class ResetPasswordRequest {
  const ResetPasswordRequest({
    required this.email,
    required this.resetToken,
    required this.newPassword,
    required this.confirmPassword,
  });

  final String email;
  final String resetToken;
  final String newPassword;
  final String confirmPassword;

  Map<String, dynamic> toJson() => {
        'email': email,
        'resetToken': resetToken,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      };
}

class VerifyOtpRequest {
  const VerifyOtpRequest({required this.email, required this.otp});

  final String email;
  final String otp;

  Map<String, dynamic> toJson() => {
        'email': email,
        'otp': otp,
      };
}

class AuthResponse {
  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final UserModel user;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
