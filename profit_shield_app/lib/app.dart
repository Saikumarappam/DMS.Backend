import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/lifecycle/app_lifecycle_handler.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/widgets/auth/biometric_lock_overlay.dart';

class DmsApp extends ConsumerWidget {
  const DmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return AppLifecycleHandler(
      child: MaterialApp.router(
        title: 'ProfitShield',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router,
        builder: (context, child) {
          return BiometricLockOverlay(
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
