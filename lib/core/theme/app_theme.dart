import 'package:flutter/material.dart';

class AppColors {
  // High Contrast Void Backgrounds
  static const Color background = Color(0xFF08090C); // Pitch Void
  static const Color surface = Color(0xFF12141A);    // Dark Matte Surface
  static const Color surfaceElevated = Color(0xFF181B24); // Elevated Cards
  static const Color border = Color(0xFF222634);     // Crisp 1px Outline

  // Typography
  static const Color textPrimary = Color(0xFFFFFFFF); // Pure Crisp White
  static const Color textSecondary = Color(0xFF94A3B8); // Slate
  static const Color textMuted = Color(0xFF64748B);

  // Neon High-Energy Accents
  static const Color accentCyan = Color(0xFF00E5FF);   // Electric Neon Cyan (VLSI / Primary)
  static const Color accentPurple = Color(0xFFA855F7); // Ultraviolet (Game Dev / Creative)
  static const Color accentCrimson = Color(0xFFFF3366);// Neon Crimson (Cyber / Alert)
  static const Color accentGreen = Color(0xFF00E676);  // Matrix Green (Done / Active)
  static const Color accentAmber = Color(0xFFFFB300);  // Gold / Milestones
}

class AppTheme {
  static const Color background = AppColors.background;
  static const Color cardBackground = AppColors.surface;
  static const Color borderColor = AppColors.border;
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color cyanAccent = AppColors.accentCyan;
  static const Color crimsonAccent = AppColors.accentCrimson;
  static const Color purpleAccent = AppColors.accentPurple;

  static Color getCategoryColor(BuildContext context, String category) {
    switch (category.toLowerCase().trim()) {
      case 'career':
        return AppColors.accentAmber;
      case 'health':
      case 'fitness':
        return AppColors.accentGreen;
      case 'skill development':
      case 'learning':
      case 'learning/skill development':
        return Theme.of(context).colorScheme.primary;
      case 'personal':
        return AppColors.accentPurple;
      default:
        final name = category.trim().toLowerCase();
        if (name.isEmpty) return Theme.of(context).colorScheme.primary;
        final hash = name.codeUnits.fold(0, (sum, unit) => sum + unit);
        final colors = [
          Theme.of(context).colorScheme.primary,
          AppColors.accentPurple,
          AppColors.accentCrimson,
          AppColors.accentGreen,
          AppColors.accentAmber,
          Colors.indigoAccent,
          Colors.tealAccent,
        ];
        return colors[hash % colors.length];
    }
  }

  static ThemeData get darkTheme => themeWithAccent(AppColors.accentCyan);

  static ThemeData themeWithAccent(Color accentColor) {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      cardColor: AppColors.surface,
      dividerColor: AppColors.border,
      colorScheme: ColorScheme.dark(
        surface: AppColors.surface,
        primary: accentColor,
        secondary: AppColors.accentPurple,
        error: AppColors.accentCrimson,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.textPrimary),
        bodyMedium: TextStyle(color: AppColors.textSecondary),
      ),
      useMaterial3: true,
    );
  }
}
