/// Temporarily skips biometric lock while opening files in another app.
class BiometricLockGuard {
  BiometricLockGuard._();

  static DateTime? _suppressedUntil;

  static void suppressFor(Duration duration) {
    _suppressedUntil = DateTime.now().add(duration);
  }

  static bool get isSuppressed {
    final until = _suppressedUntil;
    if (until == null) return false;
    if (DateTime.now().isBefore(until)) return true;
    _suppressedUntil = null;
    return false;
  }
}
