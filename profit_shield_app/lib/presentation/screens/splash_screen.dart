import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/biometric_auth_service.dart';
import '../../core/auth/biometric_login_helper.dart';
import '../../core/storage/remember_me_storage.dart';
import '../../core/storage/session_activity_storage.dart';
import '../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/biometric_cold_start_pending_provider.dart';
import '../providers/upload_flow_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    final sessionStorage = ref.read(sessionActivityStorageProvider);
    final minSplash = Future<void>.delayed(const Duration(milliseconds: 400));

    final expired = await sessionStorage.clearAuthIfInactiveExpired();
    if (expired) {
      resetClientSession(ref);
      await ref.read(authProvider.notifier).logout();
    } else {
      await ref.read(authProvider.notifier).restoreSession();
      if (ref.read(authProvider).isAuthenticated) {
        await sessionStorage.recordActivity();
      }
    }

    await minSplash;
    if (!mounted) return;

    final rememberPrefs = await ref.read(rememberMeStorageProvider).load();
    final biometricAvailable =
        await ref.read(biometricAuthServiceProvider).hasEnrolledBiometrics();
    final wasAuthenticated = ref.read(authProvider).isAuthenticated;
    final shouldUnlockSession = wasAuthenticated &&
        BiometricLoginHelper.shouldUnlockSession(
          prefs: rememberPrefs,
          biometricAvailable: biometricAvailable,
        );
    final shouldAutoLogin = !wasAuthenticated &&
        BiometricLoginHelper.shouldAutoLogin(
          prefs: rememberPrefs,
          biometricAvailable: biometricAvailable,
        );

    if (shouldUnlockSession || shouldAutoLogin) {
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;

      final unlocked = await ref.read(biometricAuthServiceProvider).authenticate(
            reason: BiometricLoginHelper.unlockReason,
          );

      ref.read(biometricColdStartPendingProvider.notifier).state = false;

      if (!unlocked) {
        if (wasAuthenticated) {
          await ref.read(authProvider.notifier).logout();
        }
        if (mounted) context.go('/login');
        return;
      }

      if (shouldAutoLogin) {
        final success = await ref.read(authProvider.notifier).login(
              rememberPrefs.userId!,
              rememberPrefs.password!,
            );
        if (!mounted) return;

        if (success) {
          final auth = ref.read(authProvider);
          context.go(auth.isSuperAdmin ? '/admin' : '/dashboard');
          return;
        }

        context.go('/login');
        return;
      }
    } else {
      ref.read(biometricColdStartPendingProvider.notifier).state = false;
    }

    final auth = ref.read(authProvider);
    if (auth.isAuthenticated) {
      context.go(auth.isSuperAdmin ? '/admin' : '/dashboard');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final logoWidth = (constraints.maxWidth * 0.78).clamp(220.0, 320.0);

            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/brand_logo.png',
                      width: logoWidth,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                const SizedBox(height: 40),
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
