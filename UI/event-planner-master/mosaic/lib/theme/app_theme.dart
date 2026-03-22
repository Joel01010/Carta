import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Carta design system — blue-spectrum, no pink/purple.
class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF080C14);
  static const Color surfaceBorder = Color(0xFF0D1F35);

  // Primary accents — blue spectrum only
  static const Color neonBlue = Color(0xFF00D4FF);
  static const Color deepBlue = Color(0xFF0066FF);

  // Glow
  static Color neonBlueGlow = const Color(0xFF00D4FF).withValues(alpha: 0.30);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF6B8FA8);

  // Status badges
  static const Color statusConfirmed = Color(0xFF00FF94);
  static const Color statusPending = Color(0xFFFFB800);
  static const Color statusCancelled = Color(0xFFFF4444);

  // Sync / connectivity
  static const Color offline = Color(0xFF444444);

  // Icon-button backgrounds
  static const Color iconButtonBg = Color(0xFF0D1F35);
}

class AppGradients {
  static const LinearGradient primary = LinearGradient(
    colors: [AppColors.neonBlue, AppColors.deepBlue],
  );
  static const LinearGradient primaryReversed = LinearGradient(
    colors: [AppColors.deepBlue, AppColors.neonBlue],
  );
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.neonBlue,
        secondary: AppColors.deepBlue,
        surface: AppColors.surface,
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          displayMedium: TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: AppColors.textPrimary),
          bodyMedium: TextStyle(color: AppColors.textSecondary),
          labelLarge: TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
      ),
      useMaterial3: true,
    );
  }
}
