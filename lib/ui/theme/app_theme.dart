import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants.dart';

class AppTheme {
  static ThemeData get dark {
    const colorScheme = ColorScheme.dark(
      primary: pokerGold,
      onPrimary: Colors.black,
      secondary: Color(0xFF2A8C64),
      onSecondary: Colors.white,
      error: Color(0xFFCF6679),
      onError: Colors.black,
      surface: pokerDarkSurface,
      onSurface: Colors.white,
    );

    final baseTextTheme = Typography.material2021().black;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: pokerDark,
      textTheme: GoogleFonts.latoTextTheme(baseTextTheme).copyWith(
        headlineLarge: GoogleFonts.lato(fontWeight: FontWeight.w700, letterSpacing: 0.2, color: Colors.white),
        headlineMedium: GoogleFonts.lato(fontWeight: FontWeight.w700, letterSpacing: 0.2, color: Colors.white),
        titleLarge: GoogleFonts.lato(fontWeight: FontWeight.w600, color: Colors.white),
        titleMedium: GoogleFonts.lato(fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge: GoogleFonts.lato(height: 1.35, color: Colors.white),
        bodyMedium: GoogleFonts.lato(height: 1.3, color: Colors.white),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: pokerDarkSurface.withValues(alpha: 0.95),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(120, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 1,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(120, 46),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.34)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: pokerDarkSurface,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
