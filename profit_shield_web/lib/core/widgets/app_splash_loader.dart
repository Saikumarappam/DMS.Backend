import 'package:flutter/material.dart';

import '../config/app_assets.dart';
import '../theme/app_colors.dart';

/// App icon with an indeterminate ring — used on splash and screen loaders.
class AppSplashLoader extends StatelessWidget {
  const AppSplashLoader({
    super.key,
    this.size = 96,
    this.progressColor = AppColors.gold,
    this.trackColor,
    this.iconBackground = Colors.white,
  });

  final double size;
  final Color progressColor;
  final Color? trackColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    final iconSize = size * 0.72;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: size * 0.045,
              color: progressColor,
              backgroundColor: trackColor ?? progressColor.withValues(alpha: 0.18),
            ),
          ),
          Container(
            width: iconSize,
            height: iconSize,
            padding: EdgeInsets.all(size * 0.12),
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Image.asset(AppAssets.logoMark, fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}

/// Full-screen splash shown while the app session is restoring.
class AppSplashScreen extends StatelessWidget {
  const AppSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSplashLoader(
              size: 112,
              progressColor: AppColors.gold,
              iconBackground: Colors.white,
            ),
            SizedBox(height: 20),
            Text(
              'ProfitShield',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Blocks the current screen while data is loading.
class AppLoadingOverlay extends StatelessWidget {
  const AppLoadingOverlay({super.key, this.opaque = false});

  final bool opaque;

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: ColoredBox(
        color: opaque ? AppColors.navy : Colors.white.withValues(alpha: 0.92),
        child: Center(
          child: AppSplashLoader(
            size: opaque ? 112 : 96,
            progressColor: opaque ? AppColors.gold : AppColors.navy,
            trackColor: (opaque ? AppColors.gold : AppColors.navy).withValues(alpha: 0.16),
          ),
        ),
      ),
    );
  }
}
