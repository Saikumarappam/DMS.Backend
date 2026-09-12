import 'package:flutter/material.dart';

/// ProfitShield brand palette — navy blue + gold from official logo.
class AppColors {
  AppColors._();

  static const Color darkBlue = Color(0xFF0B1F3A);
  static const Color navy = Color(0xFF1A365D);
  static const Color primary = Color(0xFF0B1F3A);
  static const Color primaryLight = Color(0xFF1E3A5F);
  static const Color gold = Color(0xFFC9A84C);
  static const Color goldLight = Color(0xFFE8D5A3);
  static const Color goldDark = Color(0xFFA8893A);
  static const Color sky = Color(0xFFF0F4F8);
  static const Color skyLight = Color(0xFFF8FAFC);
  static const Color accent = Color(0xFFC9A84C);
  static const Color surface = Color(0xFFF7F9FC);
  static const Color card = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0B1F3A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFC9A84C);
  static const Color warningLight = Color(0xFFFEF9EC);
  static const Color info = Color(0xFF1E3A5F);
  static const Color infoLight = Color(0xFFE8EEF5);
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);

  static const LinearGradient authGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darkBlue, navy, Color(0xFF243B55)],
  );

  /// Login / auth header — bright blue into navy (matches wave login mockup).
  static const LinearGradient authHeaderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E5AA8),
      navy,
      darkBlue,
    ],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darkBlue, navy],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldDark, gold, goldLight],
  );

  static const LinearGradient card3DGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darkBlue, navy],
  );

  static const LinearGradient icon3DGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF0F4F8), Color(0xFFE2E8F0)],
  );
}
