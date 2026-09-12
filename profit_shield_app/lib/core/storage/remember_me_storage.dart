import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final rememberMeStorageProvider = Provider<RememberMeStorage>((ref) {
  return RememberMeStorage();
});

class RememberMePrefs {
  const RememberMePrefs({
    this.enabled = false,
    this.userId,
    this.password,
    this.biometricEnabled = false,
  });

  final bool enabled;
  final String? userId;
  final String? password;
  final bool biometricEnabled;
}

class RememberMeStorage {
  RememberMeStorage({
    FlutterSecureStorage? secureStorage,
    FlutterSecureStorage? secureStorageFallback,
  })  : _secure = secureStorage ?? _primarySecureStorage,
        _secureStorageFallback = secureStorageFallback ?? _fallbackSecureStorage;

  static const _primarySecureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
      sharedPreferencesName: 'profitshield_secure',
      preferencesKeyPrefix: 'ps_',
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const _fallbackSecureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: false,
      resetOnError: true,
      sharedPreferencesName: 'profitshield_secure_fb',
      preferencesKeyPrefix: 'psfb_',
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  final FlutterSecureStorage _secure;
  final FlutterSecureStorage _secureStorageFallback;

  static const _enabledKey = 'remember_me_enabled';
  static const _userIdKey = 'remembered_user_id';
  static const _passwordKey = 'remembered_password';
  static const _biometricKey = 'remember_biometric_enabled';

  static const _backupEnabledKey = 'ps_backup_remember_enabled';
  static const _backupUserIdKey = 'ps_backup_remember_user_id';
  static const _backupBiometricKey = 'ps_backup_biometric_enabled';

  Future<String?> _readSecure(String key) async {
    try {
      final value = await _secure.read(key: key);
      if (value != null) return value;
    } catch (_) {}

    try {
      return await _secureStorageFallback.read(key: key);
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
        await _secureStorageFallback.write(key: key, value: value);
      } catch (_) {}
    }
  }

  Future<void> _deleteSecure(String key) async {
    try {
      await _secure.delete(key: key);
    } catch (_) {}
    try {
      await _secureStorageFallback.delete(key: key);
    } catch (_) {}
  }

  Future<RememberMePrefs> load() async {
    final prefs = await SharedPreferences.getInstance();

    final enabledSecure = await _readSecure(_enabledKey);
    final enabled = enabledSecure == 'true' || (prefs.getBool(_backupEnabledKey) ?? false);
    if (!enabled) {
      return const RememberMePrefs(enabled: false);
    }

    final userIdSecure = await _readSecure(_userIdKey);
    final userIdBackup = prefs.getString(_backupUserIdKey);
    final userIdRaw = userIdSecure ?? userIdBackup;

    final password = await _readSecure(_passwordKey);

    final biometricSecure = await _readSecure(_biometricKey);
    final biometricEnabled =
        biometricSecure == 'true' || (prefs.getBool(_backupBiometricKey) ?? false);

    return RememberMePrefs(
      enabled: true,
      userId: userIdRaw?.trim().isNotEmpty == true ? userIdRaw!.trim().toUpperCase() : null,
      password: password?.isNotEmpty == true ? password : null,
      biometricEnabled: biometricEnabled,
    );
  }

  Future<void> save({
    required bool enabled,
    String? userId,
    String? password,
    bool biometricEnabled = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await _writeSecure(_enabledKey, enabled.toString());
    await prefs.setBool(_backupEnabledKey, enabled);

    if (enabled && userId != null && userId.trim().isNotEmpty) {
      final normalizedUser = userId.trim().toUpperCase();
      await _writeSecure(_userIdKey, normalizedUser);
      await prefs.setString(_backupUserIdKey, normalizedUser);

      if (password != null && password.isNotEmpty) {
        await _writeSecure(_passwordKey, password);
      } else {
        await _deleteSecure(_passwordKey);
      }

      final useBiometric = biometricEnabled;
      await _writeSecure(_biometricKey, useBiometric.toString());
      await prefs.setBool(_backupBiometricKey, useBiometric);
    } else {
      await _deleteSecure(_userIdKey);
      await _deleteSecure(_passwordKey);
      await _deleteSecure(_biometricKey);
      await prefs.remove(_backupUserIdKey);
      await prefs.setBool(_backupBiometricKey, false);
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await _deleteSecure(_enabledKey);
    await _deleteSecure(_userIdKey);
    await _deleteSecure(_passwordKey);
    await _deleteSecure(_biometricKey);
    await prefs.remove(_backupEnabledKey);
    await prefs.remove(_backupUserIdKey);
    await prefs.setBool(_backupBiometricKey, false);
  }
}
