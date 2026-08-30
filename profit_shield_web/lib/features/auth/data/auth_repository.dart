import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../models/user_model.dart';

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<({AppUser user, String token, String refreshToken, DateTime? expiresAt})> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    if (kDebugMode) {
      debugPrint('[LOGIN] Starting login for username: ${username.trim()}');
      debugPrint('[LOGIN] API: ${AppConfig.apiBaseUrl}/auth/login');
    }

    late final ApiResponse response;
    try {
      response = await _api.post(
        '/auth/login',
        auth: false,
        body: {
          'username': username.trim(),
          'password': password,
        },
      );
    } on ApiException catch (e) {
      final message = _loginErrorMessage(e.message, e.statusCode);
      if (kDebugMode) {
        debugPrint('[LOGIN] Failed | statusCode=${e.statusCode ?? '-'} | message=$message');
      }
      throw ApiException(message, statusCode: e.statusCode);
    }

    if (!response.status) {
      final message = _loginErrorMessage(response.message, response.statusCode);
      if (kDebugMode) {
        debugPrint('[LOGIN] Failed | statusCode=${response.statusCode} | message=$message');
      }
      throw ApiException(message, statusCode: response.statusCode);
    }

    final token = response.token;
    final refresh = response.refreshToken;
    if (token == null || refresh == null) {
      throw ApiException('Login succeeded but tokens were missing.');
    }

    final rows = response.array0;
    if (rows.isEmpty) {
      throw ApiException('Login succeeded but user profile was missing.');
    }

    final user = AppUser.fromJson(rows.first);

    if (kDebugMode) {
      debugPrint('[LOGIN] Success | user=${user.name} | role=${user.roleName}');
    }

    _api.accessToken = token;
    _api.refreshToken = refresh;
    _api.expiresAt = response.expiresAt;
    if (rememberMe) {
      await _api.persistTokens(token: token, refresh: refresh, expires: response.expiresAt);
    } else {
      final prefsToken = _api.accessToken;
      final prefsRefresh = _api.refreshToken;
      final prefsExpires = _api.expiresAt;
      await _api.clearTokens();
      _api.accessToken = prefsToken;
      _api.refreshToken = prefsRefresh;
      _api.expiresAt = prefsExpires;
    }

    await _api.persistUsername(username);

    return (
      user: user,
      token: token,
      refreshToken: refresh,
      expiresAt: response.expiresAt,
    );
  }

  Future<AppUser?> restoreSession() async {
    await _api.loadStoredTokens();
    if (_api.accessToken == null || _api.refreshToken == null) return null;

    try {
      final response = await _api.get('/users/profile');
      if (!response.status || response.array0.isEmpty) return null;
      final user = AppUser.fromJson(response.array0.first);
      await _cacheUsernameFromProfile(response.array0.first);
      return user;
    } catch (_) {
      // Try refresh path via interceptor on next call; clear if profile fails hard.
      try {
        final refreshed = await _api.post(
          '/auth/refresh',
          auth: false,
          body: {'refreshToken': _api.refreshToken},
        );
        if (!refreshed.status || refreshed.token == null || refreshed.refreshToken == null) {
          await _api.clearTokens();
          return null;
        }
        await _api.persistTokens(
          token: refreshed.token!,
          refresh: refreshed.refreshToken!,
          expires: refreshed.expiresAt,
        );
        if (refreshed.array0.isNotEmpty) {
          return AppUser.fromJson(refreshed.array0.first);
        }
        final profile = await _api.get('/users/profile');
        if (profile.status && profile.array0.isNotEmpty) {
          await _cacheUsernameFromProfile(profile.array0.first);
          return AppUser.fromJson(profile.array0.first);
        }
      } catch (_) {
        await _api.clearTokens();
      }
      return null;
    }
  }

  Future<void> logout() => _api.clearTokens();

  Future<void> forgotPassword(String email) async {
    final response = await _api.post(
      '/auth/forgot-password',
      auth: false,
      body: {'email': email.trim()},
    );
    if (!response.status) {
      throw ApiException(response.message, statusCode: response.statusCode);
    }
  }

  Future<void> verifyPassword(String password) async {
    try {
      await _verifyPasswordViaEndpoint(password);
      return;
    } on ApiException catch (e) {
      if (!_isVerifyEndpointUnavailable(e)) {
        throw ApiException(_verifyPasswordErrorMessage(e.message, e.statusCode), statusCode: e.statusCode);
      }
    }

    final username = await _resolveLoginUsername();
    if (username == null) {
      throw ApiException('Unable to verify password. Please sign out and sign in again.');
    }

    await _verifyPasswordViaLogin(username, password);
  }

  Future<void> _verifyPasswordViaEndpoint(String password) async {
    final response = await _api.post(
      '/auth/verify-password',
      body: {'password': password},
    );
    if (!response.status) {
      throw ApiException(
        _verifyPasswordErrorMessage(response.message, response.statusCode),
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> _verifyPasswordViaLogin(String username, String password) async {
    try {
      await _api.post(
        '/auth/login',
        auth: false,
        body: {
          'username': username.trim(),
          'password': password,
        },
      );
    } on ApiException catch (e) {
      throw ApiException(
        _verifyPasswordErrorMessage(e.message, e.statusCode),
        statusCode: e.statusCode,
      );
    }
  }

  Future<String?> _resolveLoginUsername() async {
    final stored = await _api.loadStoredUsername();
    if (stored != null && stored.isNotEmpty) return stored;

    try {
      final response = await _api.get('/users/profile');
      if (response.array0.isEmpty) return null;

      final username = await _cacheUsernameFromProfile(response.array0.first);
      return username;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _cacheUsernameFromProfile(Map<String, dynamic> row) async {
    final username = '${row['Username'] ?? row['username'] ?? ''}'.trim();
    if (username.isEmpty) return null;
    await _api.persistUsername(username);
    return username;
  }

  bool _isVerifyEndpointUnavailable(ApiException error) {
    final message = error.message.toLowerCase();
    return message.contains('404') ||
        message.contains('not found') ||
        message.contains('empty response from server');
  }

  String _verifyPasswordErrorMessage(String message, String? statusCode) {
    final mapped = _loginErrorMessage(message, statusCode);
    if (mapped == 'Incorrect username.') {
      return 'Incorrect password.';
    }
    if (mapped == 'Incorrect password.') {
      return 'Incorrect password.';
    }

    final trimmed = message.trim();
    final code = statusCode ?? '';
    final lower = trimmed.toLowerCase();

    if (code == '1003' ||
        lower.contains('incorrect password') ||
        lower.contains('current password is incorrect') ||
        lower.contains('invalid username or password')) {
      return 'Incorrect password.';
    }

    return trimmed.isEmpty ? 'Password verification failed.' : trimmed;
  }

  String _loginErrorMessage(String message, String? statusCode) {
    final trimmed = message.trim();
    final code = statusCode ?? '';
    final lower = trimmed.toLowerCase();

    if (code == '1005' || lower.contains('locked') || lower.contains('not approved')) {
      return trimmed.isEmpty ? 'Account is locked or not approved.' : trimmed;
    }

    if (code == '1003' && lower.contains('failed attempt')) {
      return 'Incorrect password.';
    }

    if (lower.contains('incorrect password')) {
      return 'Incorrect password.';
    }

    if (code == '1003' ||
        code == '1001' && lower.contains('username') ||
        lower == 'invalid username or password.' ||
        lower.contains('incorrect username')) {
      return 'Incorrect username.';
    }

    return trimmed.isEmpty ? 'Login failed.' : trimmed;
  }
}
