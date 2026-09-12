import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'token_storage.dart';

final sessionActivityStorageProvider = Provider<SessionActivityStorage>((ref) {
  return SessionActivityStorage();
});

/// Logs the user out after [inactivityLimit] without app use.
class SessionActivityStorage {
  SessionActivityStorage({TokenStorage? tokenStorage})
      : _tokenStorage = tokenStorage ?? TokenStorage();

  static const inactivityLimit = Duration(hours: 5);
  static const _lastActiveKey = 'session_last_active_ms';

  final TokenStorage _tokenStorage;

  Future<void> recordActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastActiveKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastActiveKey);
  }

  /// Returns true when an existing auth session was cleared due to inactivity.
  Future<bool> clearAuthIfInactiveExpired() async {
    if (!await _tokenStorage.hasValidSession()) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_lastActiveKey);
    if (lastMs == null) {
      await recordActivity();
      return false;
    }

    final lastActive = DateTime.fromMillisecondsSinceEpoch(lastMs);
    if (DateTime.now().difference(lastActive) >= inactivityLimit) {
      await _tokenStorage.clearSession();
      await clear();
      return true;
    }

    return false;
  }
}
