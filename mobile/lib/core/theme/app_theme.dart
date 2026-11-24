import 'package:material_ui/material_ui.dart';

/// Shared Module 1 design-system palette, sourced from docs/UI_Design
/// (cream background, sage-green primary, terracotta secondary).
class AppColors {
  AppColors._();

  static const Color background = Color(0xFFF7F2E7);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color sage = Color(0xFF7C9473);
  static const Color sageDark = Color(0xFF57705A);
  static const Color sageLight = Color(0xFFDCE6D5);

  static const Color terracotta = Color(0xFFC1603F);
  static const Color terracottaDark = Color(0xFFA24E32);
  static const Color terracottaLight = Color(0xFFF5DDD3);

  static const Color textPrimary = Color(0xFF2E2B26);
  static const Color textSecondary = Color(0xFF716B60);
  static const Color error = Color(0xFFB3392C);
  static const Color border = Color(0xFFE1D9C8);

  // Welcome/Login/Register hero header — sunset-over-hills gradient behind
  // the walking-figure illustration, per docs/UI_Design login/register refs.
  static const Color heroSkyTop = Color(0xFFFBEDDD);
  static const Color heroGlow = Color(0xFFE8987A);
  static const Color heroHill = Color(0xFF8CA47D);
}

/// Shared ThemeData for the app — cream/off-white background, sage-green
/// primary accent, terracotta secondary accent, pill buttons, rounded cards.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.sage,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.sage,
      onPrimary: Colors.white,
      secondary: AppColors.terracotta,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          letterSpacing: -0.5,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          height: 1.1,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          letterSpacing: -0.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.2,
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.2,
        ),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        bodyLarge: TextStyle(fontSize: 16, color: AppColors.textPrimary, height: 1.4),
        bodyMedium: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.4),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.terracotta,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.terracotta.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: const StadiumBorder(),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.sageDark,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
        floatingLabelStyle: const TextStyle(color: AppColors.sageDark, fontWeight: FontWeight.w600),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.sage, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.sage : Colors.transparent,
        ),
        side: const BorderSide(color: AppColors.sage, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.sage : AppColors.textSecondary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
