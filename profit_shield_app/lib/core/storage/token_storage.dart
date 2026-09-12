import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/user_models.dart';
import 'session_token_cache.dart';

class TokenStorage {
  TokenStorage({
    FlutterSecureStorage? secureStorage,
    FlutterSecureStorage? secureStorageFallback,
  })  : _secure = secureStorage ?? _primarySecureStorage,
        _secureFallback = secureStorageFallback ?? _fallbackSecureStorage;

  static const _primarySecureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
      sharedPreferencesName: 'profitshield_tokens',
      preferencesKeyPrefix: 'pst_',
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const _fallbackSecureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: false,
      resetOnError: true,
      sharedPreferencesName: 'profitshield_tokens_fb',
      preferencesKeyPrefix: 'pstfb_',
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  final FlutterSecureStorage _secure;
  final FlutterSecureStorage _secureFallback;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _expiresAtKey = 'expires_at';
  static const _userKey = 'user_json';

  static const _backupAccessKey = 'ps_backup_access_token';
  static const _backupRefreshKey = 'ps_backup_refresh_token';
  static const _backupExpiresKey = 'ps_backup_expires_at';
  static const _backupUserKey = 'ps_backup_user_json';

  Future<String?> _readSecure(String key) async {
    try {
      final value = await _secure.read(key: key);
      if (value != null) return value;
    } catch (_) {}

    try {
      return await _secureFallback.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeSecure(String key, String value) async {
    var saved = false;
    try {
      await _secure.write(key: key, value: value);
      saved = true;
    } catch (_) {}

    if (!saved) {
      try {
        await _secureFallback.write(key: key, value: value);
      } catch (_) {}
    }
  }

  Future<void> _deleteSecure(String key) async {
    try {
      await _secure.delete(key: key);
    } catch (_) {}
    try {
      await _secureFallback.delete(key: key);
    } catch (_) {}
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  }) async {
    SessionTokenCache.set(
      access: accessToken,
      refresh: refreshToken,
      expires: expiresAt,
    );

    await _writeSecure(_accessTokenKey, accessToken);
    await _writeSecure(_refreshTokenKey, refreshToken);
    await _writeSecure(_expiresAtKey, expiresAt.toUtc().toIso8601String());

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backupAccessKey, accessToken);
    await prefs.setString(_backupRefreshKey, refreshToken);
    await prefs.setString(_backupExpiresKey, expiresAt.toUtc().toIso8601String());
  }

  Future<String?> getAccessToken() async {
    final cached = SessionTokenCache.accessToken;
    if (cached != null && cached.isNotEmpty) return cached;

    final secure = await _readSecure(_accessTokenKey);
    if (secure != null && secure.isNotEmpty) {
      SessionTokenCache.accessToken = secure;
      return secure;
    }

    final prefs = await SharedPreferences.getInstance();
    final backup = prefs.getString(_backupAccessKey);
    if (backup != null && backup.isNotEmpty) {
      SessionTokenCache.accessToken = backup;
      return backup;
    }

    return null;
  }

  Future<String?> getRefreshToken() async {
    final cached = SessionTokenCache.refreshToken;
    if (cached != null && cached.isNotEmpty) return cached;

    final secure = await _readSecure(_refreshTokenKey);
    if (secure != null && secure.isNotEmpty) {
      SessionTokenCache.refreshToken = secure;
      return secure;
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_backupRefreshKey);
  }

  Future<DateTime?> getExpiresAt() async {
    final cached = SessionTokenCache.expiresAt;
    if (cached != null) return cached;

    final secure = await _readSecure(_expiresAtKey);
    if (secure != null) {
      final parsed = DateTime.tryParse(secure);
      if (parsed != null) {
        SessionTokenCache.expiresAt = parsed;
        return parsed;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final backup = prefs.getString(_backupExpiresKey);
    return backup != null ? DateTime.tryParse(backup) : null;
  }

  Future<void> saveUser(UserModel user) async {
    final json = jsonEncode(user.toJson());
    await _writeSecure(_userKey, json);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backupUserKey, json);
  }

  Future<UserModel?> getUser() async {
    final secure = await _readSecure(_userKey);
    if (secure != null) {
      return UserModel.fromJson(jsonDecode(secure) as Map<String, dynamic>);
    }

    final prefs = await SharedPreferences.getInstance();
    final backup = prefs.getString(_backupUserKey);
    if (backup == null) return null;
    return UserModel.fromJson(jsonDecode(backup) as Map<String, dynamic>);
  }

  Future<bool> hasValidSession() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clearSession() async {
    SessionTokenCache.clear();
    await _deleteSecure(_accessTokenKey);
    await _deleteSecure(_refreshTokenKey);
    await _deleteSecure(_expiresAtKey);
    await _deleteSecure(_userKey);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_backupAccessKey);
    await prefs.remove(_backupRefreshKey);
    await prefs.remove(_backupExpiresKey);
    await prefs.remove(_backupUserKey);
  }

  Future<void> clearAll() async => clearSession();
}
