import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env_config.dart';
import '../../core/storage/session_activity_storage.dart';
import '../../data/mock/local_user_store.dart';
import '../../data/mock/mock_auth_data.dart';
import '../../data/models/auth_models.dart';
import '../../data/models/user_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/user_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isLoading = false,
    this.error,
  });

  final AuthStatus status;
  final UserModel? user;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isSuperAdmin => user?.isSuperAdmin ?? false;
  bool get isClient => user?.isClient ?? false;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(
    this._authRepository,
    this._userRepository,
    this._localUserStore,
    this._sessionActivityStorage,
  ) : super(const AuthState());

  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  final LocalUserStore _localUserStore;
  final SessionActivityStorage _sessionActivityStorage;

  Future<void> restoreSession() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final session = await _authRepository.restoreSession().timeout(
        const Duration(seconds: 4),
        onTimeout: () => null,
      );
      if (session == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
      state = AuthState(
        status: AuthStatus.authenticated,
        user: session.user,
      );
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    if (EnvConfig.useMockData) {
      final mockResponse = await MockAuthData.tryLogin(
        username,
        password,
        _localUserStore,
      );
      if (mockResponse != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: mockResponse.user,
        );
        unawaited(
          _authRepository
              .persistSession(mockResponse)
              .timeout(const Duration(seconds: 5))
              .then((_) => _sessionActivityStorage.recordActivity())
              .catchError((_) {}),
        );
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        status: AuthStatus.unauthenticated,
        error: 'Invalid user name or password',
      );
      return false;
    }

    try {
      final result = await _authRepository
          .login(LoginRequest(
            username: username.trim().toUpperCase(),
            password: password,
          ))
          .timeout(const Duration(seconds: 30));

      if (!result.success || result.data == null) {
        state = state.copyWith(
          isLoading: false,
          status: AuthStatus.unauthenticated,
          error: result.errorMessage,
        );
        return false;
      }

      await _authRepository.persistSession(result.data!);
      await _sessionActivityStorage.recordActivity();
      state = AuthState(
        status: AuthStatus.authenticated,
        user: result.data!.user,
      );
      return true;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        status: AuthStatus.unauthenticated,
        error: 'Login failed. Check your connection and try again.',
      );
      return false;
    }
  }

  Future<String?> register(RegisterRequest request) async {
    state = state.copyWith(isLoading: true, clearError: true);

    if (EnvConfig.useMockData) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await _localUserStore.saveRegistration(
        username: request.panNumber,
        password: request.password,
        request: request,
      );
      state = state.copyWith(isLoading: false);
      return null;
    }

    final result = await _authRepository.register(request);
    state = state.copyWith(isLoading: false);
    if (!result.success) return result.errorMessage;
    return result.data;
  }

  Future<String?> changePassword(ChangePasswordRequest request) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _authRepository.changePassword(request);
    state = state.copyWith(isLoading: false);
    if (!result.success) return result.errorMessage;
    return null;
  }

  Future<String?> forgotPassword(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);

    if (EnvConfig.useMockData) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      state = state.copyWith(isLoading: false);
      return 'OTP sent to your email.';
    }

    final result = await _authRepository.forgotPassword(
      ForgotPasswordRequest(email: email),
    );
    state = state.copyWith(isLoading: false);
    if (!result.success) return result.errorMessage;
    return result.data;
  }

  Future<String?> verifyOtp(String email, String otp) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _authRepository.verifyOtp(
      VerifyOtpRequest(email: email, otp: otp),
    );
    state = state.copyWith(isLoading: false);
    if (!result.success) return result.errorMessage;
    return result.data;
  }

  Future<String?> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
    required String confirmPassword,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _authRepository.resetPassword(
      ResetPasswordRequest(
        email: email,
        resetToken: resetToken,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      ),
    );
    state = state.copyWith(isLoading: false);
    if (!result.success) return result.errorMessage;
    return result.data;
  }

  Future<String?> refreshProfile() async {
    if (!state.isAuthenticated) return null;
    final result = await _userRepository.getProfile();
    if (result.success && result.data != null) {
      state = state.copyWith(user: result.data);
      return null;
    }
    return result.errorMessage ?? 'Unable to load profile. Please try again.';
  }

  Future<void> logout() async {
    await _authRepository.logout();
    await _sessionActivityStorage.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.read(authRepositoryProvider),
    ref.read(userRepositoryProvider),
    ref.read(localUserStoreProvider),
    ref.read(sessionActivityStorageProvider),
  );
});
