import '../storage/remember_me_storage.dart';

class BiometricLoginHelper {
  BiometricLoginHelper._();

  static const unlockReason = 'Unlock ProfitShield with fingerprint';
  static const signInReason = 'Sign in to ProfitShield with fingerprint';

  /// Fingerprint required before showing an existing logged-in session.
  static bool shouldUnlockSession({
    required RememberMePrefs prefs,
    required bool biometricAvailable,
  }) {
    if (!biometricAvailable || !prefs.enabled) return false;
    return prefs.biometricEnabled || prefs.enabled;
  }

  /// Fingerprint sign-in when session expired but credentials are saved.
  static bool shouldAutoLogin({
    required RememberMePrefs prefs,
    required bool biometricAvailable,
  }) {
    if (!biometricAvailable || !prefs.enabled) return false;

    final userId = prefs.userId;
    final password = prefs.password;
    if (userId == null || userId.isEmpty) return false;
    if (password == null || password.isEmpty) return false;

    return true;
  }
}
