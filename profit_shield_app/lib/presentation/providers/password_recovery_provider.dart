import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env_config.dart';
import '../../data/models/auth_models.dart';
import '../../data/repositories/auth_repository.dart';

enum RecoveryStep { requestOtp, verifyOtp, resetPassword }

class PasswordRecoveryState {
  const PasswordRecoveryState({
    this.step = RecoveryStep.requestOtp,
    this.email = '',
    this.resetToken,
    this.isLoading = false,
    this.error,
  });

  final RecoveryStep step;
  final String email;
  final String? resetToken;
  final bool isLoading;
  final String? error;

  PasswordRecoveryState copyWith({
    RecoveryStep? step,
    String? email,
    String? resetToken,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearToken = false,
  }) {
    return PasswordRecoveryState(
      step: step ?? this.step,
      email: email ?? this.email,
      resetToken: clearToken ? null : (resetToken ?? this.resetToken),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PasswordRecoveryNotifier extends StateNotifier<PasswordRecoveryState> {
  PasswordRecoveryNotifier(this._repository) : super(const PasswordRecoveryState());

  final AuthRepository _repository;

  void reset() => state = const PasswordRecoveryState();

  void goBack() {
    switch (state.step) {
      case RecoveryStep.requestOtp:
        break;
      case RecoveryStep.verifyOtp:
        state = state.copyWith(step: RecoveryStep.requestOtp, clearError: true);
      case RecoveryStep.resetPassword:
        state = state.copyWith(step: RecoveryStep.verifyOtp, clearError: true);
    }
  }

  /// Step 1 — POST /auth/forgot-password  `{ "email": "..." }`
  Future<String?> requestOtp(String email) async {
    state = state.copyWith(isLoading: true, clearError: true, email: email.trim());

    if (EnvConfig.useMockData) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      state = state.copyWith(
        isLoading: false,
        step: RecoveryStep.verifyOtp,
      );
      return 'OTP sent to your email.';
    }

    final result = await _repository.forgotPassword(
      ForgotPasswordRequest(email: email.trim()),
    );

    if (!result.success) {
      state = state.copyWith(isLoading: false, error: result.errorMessage);
      return result.errorMessage;
    }

    state = state.copyWith(
      isLoading: false,
      step: RecoveryStep.verifyOtp,
    );
    return result.data;
  }

  /// Step 2 — POST /auth/verify-otp  `{ "email": "...", "otp": "..." }`
  Future<String?> verifyOtp(String otp) async {
    if (state.email.isEmpty) {
      return 'Email is missing. Please start again.';
    }

    state = state.copyWith(isLoading: true, clearError: true);

    if (EnvConfig.useMockData) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      state = state.copyWith(
        isLoading: false,
        resetToken: 'mock-reset-token',
        step: RecoveryStep.resetPassword,
      );
      return null;
    }

    final result = await _repository.verifyOtp(
      VerifyOtpRequest(email: state.email, otp: otp.trim()),
    );

    if (!result.success || result.data == null || result.data!.isEmpty) {
      final error = result.errorMessage.isNotEmpty
          ? result.errorMessage
          : 'Invalid or expired OTP.';
      state = state.copyWith(isLoading: false, error: error);
      return error;
    }

    state = state.copyWith(
      isLoading: false,
      resetToken: result.data,
      step: RecoveryStep.resetPassword,
    );
    return null;
  }

  /// Step 3 — POST /auth/reset-password
  Future<String?> resetPassword({
    required String newPassword,
    required String confirmPassword,
  }) async {
    final token = state.resetToken;
    if (state.email.isEmpty || token == null || token.isEmpty) {
      return 'Session expired. Please request a new OTP.';
    }

    state = state.copyWith(isLoading: true, clearError: true);

    if (EnvConfig.useMockData) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      state = state.copyWith(isLoading: false);
      return null;
    }

    final result = await _repository.resetPassword(
      ResetPasswordRequest(
        email: state.email,
        resetToken: token,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      ),
    );

    if (!result.success) {
      state = state.copyWith(isLoading: false, error: result.errorMessage);
      return result.errorMessage;
    }

    state = state.copyWith(isLoading: false);
    return result.data;
  }
}

final passwordRecoveryProvider =
    StateNotifierProvider<PasswordRecoveryNotifier, PasswordRecoveryState>((ref) {
  return PasswordRecoveryNotifier(ref.read(authRepositoryProvider));
});
