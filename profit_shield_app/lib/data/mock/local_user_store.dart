import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_models.dart';
import '../models/user_models.dart';

final localUserStoreProvider = Provider<LocalUserStore>((ref) => LocalUserStore());

class LocalUserStore {
  LocalUserStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;
  static const _usersKey = 'local_registered_users';

  static const String localUserToken = 'local-user-token';

  Future<void> saveRegistration({
    required String username,
    required String password,
    required RegisterRequest request,
  }) async {
    final users = await _loadAll();
    final key = username.trim().toLowerCase();
    users[key] = {
      'password': password,
      'user': UserModel(
        userId: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        name: request.name,
        email: request.email,
        mobileNumber: request.mobileNumber,
        roleName: 'Client',
        userStatus: 'Active',
        profileCompleted: true,
        username: key,
        businessName: request.businessName ?? request.name,
        panNumber: request.panNumber,
        address: request.address,
        contactPersonName: request.contactPersonName ?? request.name,
        gstNumber: request.gstNumber,
      ).toJson(),
    };
    await _storage.write(key: _usersKey, value: jsonEncode(users));
  }

  Future<AuthResponse?> tryLogin(String username, String password) async {
    final users = await _loadAll();
    final key = username.trim().toLowerCase();
    final entry = users[key];
    if (entry == null) return null;
    if (entry['password'] != password) return null;

    final user = UserModel.fromJson(entry['user'] as Map<String, dynamic>);
    return AuthResponse(
      accessToken: localUserToken,
      refreshToken: 'local-refresh-token',
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      user: user,
    );
  }

  Future<Map<String, dynamic>> _loadAll() async {
    try {
      final raw = await _storage
          .read(key: _usersKey)
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
      if (raw == null) return {};
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }
}
