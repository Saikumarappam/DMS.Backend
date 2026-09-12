import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/repository_helper.dart';
import '../../core/storage/session_token_cache.dart';
import '../../core/storage/token_storage.dart';
import '../models/api_parsers.dart';
import '../models/api_response.dart';
import '../models/auth_models.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.read(apiClientProvider),
    ref.read(tokenStorageProvider),
  );
});

class AuthRepository {
  AuthRepository(this._apiClient, this._tokenStorage);

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<ApiResponse<AuthResponse>> login(LoginRequest request) {
    return RepositoryHelper.execute(
      request: () => _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.authLogin,
        data: request.toJson(),
        options: Options(extra: const {'skipAuth': true}),
      ),
      mapData: AuthResponseParser.parse,
    );
  }

  Future<ApiResponse<String>> register(RegisterRequest request) {
    return RepositoryHelper.execute<String>(
      request: () => _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.authRegister,
        data: request.toJson(),
        options: Options(extra: const {'skipAuth': true}),
      ),
      mapData: (body) {
        if (body['status'] != true) return null;
        return body['message'] as String? ??
            'Registration successful. Awaiting admin approval.';
      },
    );
  }

  Future<ApiResponse<AuthResponse>> refresh(String refreshToken) {
    return RepositoryHelper.execute(
      request: () => _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.authRefresh,
        data: RefreshTokenRequest(refreshToken: refreshToken).toJson(),
        options: Options(extra: const {'skipAuth': true}),
      ),
      mapData: AuthResponseParser.parse,
    );
  }

  Future<ApiResponse<bool>> changePassword(ChangePasswordRequest request) {
    return RepositoryHelper.execute<bool>(
      request: () => _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.authChangePassword,
        data: request.toJson(),
      ),
      mapData: (body) => body['status'] as bool? ?? false,
    );
  }

  Future<ApiResponse<String>> forgotPassword(ForgotPasswordRequest request) {
    return RepositoryHelper.execute<String>(
      request: () => _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.authForgotPassword,
        data: request.toJson(),
        options: Options(extra: const {'skipAuth': true}),
      ),
      mapData: (body) {
        if (body['status'] != true) return null;
        return body['message'] as String? ?? 'OTP sent to your email.';
      },
    );
  }

  Future<ApiResponse<String>> verifyOtp(VerifyOtpRequest request) {
    return RepositoryHelper.execute<String>(
      request: () => _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.authVerifyOtp,
        data: request.toJson(),
        options: Options(extra: const {'skipAuth': true}),
      ),
      mapData: (body) {
        if (body['status'] != true) return null;
        final token = body['jsonstring'] as String?;
        if (token != null && token.trim().isNotEmpty) return token.trim();
        return null;
      },
    );
  }

  Future<ApiResponse<String>> resetPassword(ResetPasswordRequest request) {
    return RepositoryHelper.execute<String>(
      request: () => _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.authResetPassword,
        data: request.toJson(),
        options: Options(extra: const {'skipAuth': true}),
      ),
      mapData: (body) {
        if (body['status'] != true) return null;
        return body['message'] as String? ?? 'Password reset successfully.';
      },
    );
  }

  Future<void> persistSession(AuthResponse auth) async {
    await _tokenStorage.saveTokens(
      accessToken: auth.accessToken,
      refreshToken: auth.refreshToken,
      expiresAt: auth.expiresAt,
    );
    await _tokenStorage.saveUser(auth.user);
  }

  Future<void> logout() => _tokenStorage.clearAll();

  Future<bool> hasSession() => _tokenStorage.hasValidSession();

  Future<AuthResponse?> restoreSession() async {
    final accessToken = await _tokenStorage.getAccessToken();
    final refreshToken = await _tokenStorage.getRefreshToken();
    final expiresAt = await _tokenStorage.getExpiresAt();
    final user = await _tokenStorage.getUser();

    if (refreshToken == null || refreshToken.isEmpty || user == null) {
      return null;
    }

    final isExpired = expiresAt == null || DateTime.now().isAfter(expiresAt);

    if (!isExpired && accessToken != null && accessToken.isNotEmpty) {
      final expiry = expiresAt!;
      SessionTokenCache.set(
        access: accessToken,
        refresh: refreshToken,
        expires: expiry,
      );
      return AuthResponse(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: expiry,
        user: user,
      );
    }

    final refreshed = await refresh(refreshToken);
    if (!refreshed.success || refreshed.data == null) return null;

    await persistSession(refreshed.data!);
    return refreshed.data;
  }
}
