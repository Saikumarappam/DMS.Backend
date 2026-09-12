import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/biometric_auth_service.dart';
import '../auth/biometric_lock_guard.dart';
import '../auth/biometric_login_helper.dart';
import '../router/app_router.dart';
import '../storage/remember_me_storage.dart';
import '../storage/session_activity_storage.dart';
import '../../presentation/providers/app_biometric_lock_provider.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/upload_flow_provider.dart';

/// Keeps the session alive while the app is used and enforces a 5-hour inactivity logout.
class AppLifecycleHandler extends ConsumerStatefulWidget {
  const AppLifecycleHandler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLifecycleHandler> createState() => _AppLifecycleHandlerState();
}

class _AppLifecycleHandlerState extends ConsumerState<AppLifecycleHandler>
    with WidgetsBindingObserver {
  bool _handlingSession = false;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
      _recordActivityIfAuthenticated();
      _lockIfBiometricRequired();
    } else if (state == AppLifecycleState.resumed) {
      _enforceInactivityTimeout();
      _backgroundedAt = null;
    }
  }

  Future<void> _recordActivityIfAuthenticated() async {
    if (!ref.read(authProvider).isAuthenticated) return;
    await ref.read(sessionActivityStorageProvider).recordActivity();
  }

  Future<void> _lockIfBiometricRequired() async {
    if (BiometricLockGuard.isSuppressed) return;
    if (!ref.read(authProvider).isAuthenticated) return;

    final rememberPrefs = await ref.read(rememberMeStorageProvider).load();
    final biometricAvailable =
        await ref.read(biometricAuthServiceProvider).hasEnrolledBiometrics();

    if (!BiometricLoginHelper.shouldUnlockSession(
      prefs: rememberPrefs,
      biometricAvailable: biometricAvailable,
    )) {
      return;
    }

    ref.read(appBiometricLockProvider.notifier).state = true;
  }

  Future<void> _enforceInactivityTimeout() async {
    if (_handlingSession) return;

    _handlingSession = true;
    try {
      if (ref.read(authProvider).isAuthenticated) {
        final expired =
            await ref.read(sessionActivityStorageProvider).clearAuthIfInactiveExpired();
        if (!mounted) return;
        if (expired) {
          ref.read(appBiometricLockProvider.notifier).state = false;
          resetClientSession(ref);
          await ref.read(authProvider.notifier).logout();
          ref.read(routerProvider).go('/login');
          return;
        }

        await ref.read(sessionActivityStorageProvider).recordActivity();
      }

      if (BiometricLockGuard.isSuppressed) {
        ref.read(appBiometricLockProvider.notifier).state = false;
        return;
      }

      if (!ref.read(appBiometricLockProvider)) return;

      final backgroundedAt = _backgroundedAt;
      if (backgroundedAt != null &&
          DateTime.now().difference(backgroundedAt) < const Duration(seconds: 2)) {
        ref.read(appBiometricLockProvider.notifier).state = false;
        return;
      }

      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;

      final unlocked = await ref.read(biometricAuthServiceProvider).authenticate(
            reason: BiometricLoginHelper.unlockReason,
          );
      if (!mounted) return;

      if (unlocked) {
        ref.read(appBiometricLockProvider.notifier).state = false;
        return;
      }

      ref.read(appBiometricLockProvider.notifier).state = false;
      await ref.read(authProvider.notifier).logout();
      if (!mounted) return;
      ref.read(routerProvider).go('/login');
    } finally {
      _handlingSession = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
