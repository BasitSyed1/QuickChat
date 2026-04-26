import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme);

    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryColor,
        onPrimary: AppColors.onPrimaryColor,
        secondary: AppColors.secondaryColor,
        onSecondary: AppColors.onSecondaryColor,
        surface: AppColors.surfaceColor,
        onSurface: AppColors.onSurfaceColor,
        surfaceContainerHighest: AppColors.surfaceMuted,
        error: AppColors.errorColor,
        onError: AppColors.onErrorColor,
        outline: AppColors.borderColor,
      ),
      scaffoldBackgroundColor: AppColors.surfaceColor,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.onSurfaceColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurfaceColor,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: AppColors.onSurfaceColor),
      ),
      dividerColor: AppColors.dividerColor,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceMuted,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.secondaryVariantColor,
            width: 1.4,
          ),
        ),
        hintStyle: GoogleFonts.poppins(
          color: AppColors.onSurfaceMuted,
          fontSize: 15,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primarySoft,
        contentTextStyle: GoogleFonts.poppins(color: AppColors.onPrimaryColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
