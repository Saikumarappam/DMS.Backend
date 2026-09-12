import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/biometric_auth_service.dart';
import '../../../core/auth/biometric_login_helper.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/app_biometric_lock_provider.dart';
import '../../providers/auth_provider.dart';

class BiometricLockOverlay extends ConsumerStatefulWidget {
  const BiometricLockOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BiometricLockOverlay> createState() => _BiometricLockOverlayState();
}

class _BiometricLockOverlayState extends ConsumerState<BiometricLockOverlay> {
  bool _prompting = false;

  Future<void> _promptUnlock() async {
    if (_prompting || !ref.read(appBiometricLockProvider)) return;

    _prompting = true;
    try {
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
      _prompting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(appBiometricLockProvider);

    return Stack(
      children: [
        widget.child,
        if (locked)
          Positioned.fill(
            child: Material(
              color: Colors.white,
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.fingerprint,
                          size: 72,
                          color: AppColors.primary.withValues(alpha: 0.9),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Unlock ProfitShield',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Use your fingerprint to continue',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 28),
                        FilledButton.icon(
                          onPressed: _prompting ? null : _promptUnlock,
                          icon: const Icon(Icons.fingerprint),
                          label: Text(_prompting ? 'Checking…' : 'Use fingerprint'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.darkBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
