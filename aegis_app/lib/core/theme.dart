import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

ThemeData buildAegisTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgPrimary,
    colorScheme: const ColorScheme.dark(
      primary: accentTeal,
      secondary: accentTealDim,
      surface: bgSurface,
      onPrimary: bgPrimary,
      onSurface: textPrimary,
    ),
    textTheme: GoogleFonts.rajdhaniTextTheme().copyWith(
      displayLarge: GoogleFonts.rajdhani(
        color: textPrimary, fontWeight: FontWeight.w700, fontSize: 32,
        letterSpacing: 2,
      ),
      headlineMedium: GoogleFonts.rajdhani(
        color: textPrimary, fontWeight: FontWeight.w700, fontSize: 22,
        letterSpacing: 1.5,
      ),
      bodyMedium: GoogleFonts.rajdhani(
        color: textSecondary, fontWeight: FontWeight.w400, fontSize: 14,
      ),
      labelLarge: GoogleFonts.rajdhani(
        color: textPrimary, fontWeight: FontWeight.w700, fontSize: 15,
        letterSpacing: 1.2,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bgInput,
      hintStyle: GoogleFonts.rajdhani(color: textMuted, fontSize: 14),
      labelStyle: GoogleFonts.rajdhani(
        color: textSecondary, fontSize: 11, letterSpacing: 1.5,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: inputBorderFocus, width: 1.5),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return accentTeal;
        return Colors.transparent;
      }),
      side: const BorderSide(color: accentTealDim, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    ),
  );
}

ThemeData buildAegisLightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(seedColor: accentTeal),
    textTheme: GoogleFonts.rajdhaniTextTheme(),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    ),
  );
}
