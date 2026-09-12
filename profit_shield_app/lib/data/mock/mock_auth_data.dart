import '../../core/config/env_config.dart';
import '../models/auth_models.dart';
import '../models/user_models.dart';
import 'local_user_store.dart';

/// Static demo credentials for offline / UI testing without a backend.
class MockAuthData {
  MockAuthData._();

  static bool get enabled => EnvConfig.useMockData;

  static const String demoUsername = 'sai';
  static const String demoPassword = '123';

  static const String mockAccessToken = 'mock-access-token';

  static bool isMockToken(String? token) =>
      token == mockAccessToken || token == LocalUserStore.localUserToken;

  static Future<AuthResponse?> tryLogin(
    String username,
    String password,
    LocalUserStore localStore,
  ) async {
    if (!enabled) return null;

    final local = await localStore.tryLogin(username, password);
    if (local != null) return local;

    final user = username.trim().toLowerCase();
    final pass = password;

    if (user == demoUsername && pass == demoPassword) {
      return _buildResponse(
        userId: 1,
        name: 'Rajesh Sharma',
        username: demoUsername,
        email: 'rajesh@sharmatraders.com',
        mobileNumber: '9999999999',
        roleName: 'Client',
        businessName: 'Sharma Traders Pvt Ltd',
        address: 'Shop 42, Linking Road, Bandra West, Mumbai - 400050',
        contactPersonName: 'Rajesh Sharma',
        gstNumber: '27ABCDE1234F1Z5',
        panNumber: 'ABCDE1234F',
      );
    }

    if (user == 'admin' && pass == 'admin') {
      return _buildResponse(
        userId: 99,
        name: 'Super Admin',
        username: 'admin',
        email: 'admin@dms.com',
        mobileNumber: '9000000000',
        roleName: 'SuperAdmin',
      );
    }

    return null;
  }

  static AuthResponse _buildResponse({
    required int userId,
    required String name,
    required String username,
    required String email,
    required String mobileNumber,
    required String roleName,
    String? businessName,
    String? address,
    String? contactPersonName,
    String? gstNumber,
    String? panNumber,
  }) {
    return AuthResponse(
      accessToken: mockAccessToken,
      refreshToken: 'mock-refresh-token',
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      user: UserModel(
        userId: userId,
        name: name,
        email: email,
        mobileNumber: mobileNumber,
        roleName: roleName,
        userStatus: 'Active',
        profileCompleted: true,
        username: username,
        businessName: businessName,
        address: address,
        contactPersonName: contactPersonName,
        gstNumber: gstNumber,
        panNumber: panNumber,
      ),
    );
  }
}
