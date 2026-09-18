import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const background = Color(0xFF110D0A);
  static const surface = Color(0xFF211711);
  static const accent = Color(0xFFF28C28);
  static const mutedText = Color(0xFFB8A79A);

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: surface,
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: scheme.copyWith(
        primary: accent,
        onPrimary: background,
        error: const Color(0xFFF59E0B),
      ),
      scaffoldBackgroundColor: background,
      fontFamily: 'Georgia',
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFFB76A1A),
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A130F),
        hintStyle: const TextStyle(color: mutedText),
        prefixIconColor: mutedText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF4B392D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF4B392D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        errorStyle: const TextStyle(
          color: Color(0xFFF59E0B),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
