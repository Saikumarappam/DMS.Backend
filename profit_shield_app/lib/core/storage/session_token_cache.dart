/// In-memory auth tokens so API calls work immediately after login even if
/// secure storage is slow or temporarily unavailable on the device.
class SessionTokenCache {
  SessionTokenCache._();

  static String? accessToken;
  static String? refreshToken;
  static DateTime? expiresAt;

  static void set({
    required String access,
    required String refresh,
    required DateTime expires,
  }) {
    accessToken = access;
    refreshToken = refresh;
    expiresAt = expires;
  }

  static void clear() {
    accessToken = null;
    refreshToken = null;
    expiresAt = null;
  }
}
