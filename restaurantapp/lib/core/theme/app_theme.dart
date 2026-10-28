import 'package:flutter/material.dart';

/// Monad Design System — Style Tokens and Themes
/// Based on the Monad Style Reference (warm parchment, editorial serif, clean mono, Lake Blue accent).
abstract final class AppTheme {
  // --- Monad Color Tokens ---
  /// Warm parchment canvas fill (#F6F3F1)
  static const Color parchment = Color(0xFFF6F3F1);

  /// Off-Black for primary text and high-contrast actions (#242424)
  static const Color offBlack = Color(0xFF242424);

  /// Pure Ink for top bars, hero accents, and announcements (#000000)
  static const Color ink = Color(0xFF000000);

  /// Graphite for secondary body text and metadata (#4E4D4D)
  static const Color graphite = Color(0xFF4E4D4D);

  /// Smoke for muted helper text and subtle captions (#797776)
  static const Color smoke = Color(0xFF797776);

  /// Ash hairline border color (#CECAC8)
  static const Color ash = Color(0xFFCECAC8);

  /// Lake Blue for primary interactive actions and highlights (#2B59D1)
  static const Color lakeBlue = Color(0xFF2B59D1);

  /// Periwinkle Mist for secondary pastel surfaces and badges (#CFDAF5)
  static const Color periwinkle = Color(0xFFCFDAF5);

  /// Mint pastel decorative accent (#A7FCCD)
  static const Color mint = Color(0xFFA7FCCD);

  /// Coral warm decorative accent (#FF9473)
  static const Color coral = Color(0xFFFF9473);

  /// Sky Blue atmospheric accent (#A0B5EB)
  static const Color skyBlue = Color(0xFFA0B5EB);

  /// Gold warm decorative accent (#ECDA98)
  static const Color gold = Color(0xFFECDA98);

  /// Crimson deep warm accent (#F37A0A)
  static const Color crimson = Color(0xFFF37A0A);

  // --- Backwards-compatible aliases ---
  static const Color background = parchment;
  static const Color surface = Colors.white;
  static const Color accent = lakeBlue;
  static const Color mutedText = smoke;
  static const Color primaryText = offBlack;
  static const Color secondaryText = graphite;
  static const Color borderColor = ash;

  // --- Typography Constants & Helpers ---
  static const String serifFont = 'Georgia';
  static const String monoFont = 'monospace';

  static TextStyle serif({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w400,
    Color color = offBlack,
    double? height,
    double letterSpacing = -0.3,
  }) {
    return TextStyle(
      fontFamily: serifFont,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height ?? 1.25,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle mono({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w400,
    Color color = graphite,
    double? height,
    double letterSpacing = 0.2,
  }) {
    return TextStyle(
      fontFamily: monoFont,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height ?? 1.35,
      letterSpacing: letterSpacing,
    );
  }

  // --- Shape & Radius Tokens ---
  static const double radiusTag = 9999;
  static const double radiusPill = 100;
  static const double radiusCard = 20;
  static const double radiusInput = 12;

  // --- Monad ThemeData ---
  static ThemeData get monadTheme {
    final scheme = ColorScheme.light(
      primary: lakeBlue,
      onPrimary: Colors.white,
      secondary: periwinkle,
      onSecondary: offBlack,
      surface: Colors.white,
      onSurface: offBlack,
      error: const Color(0xFFB3261E),
      onError: Colors.white,
      outline: ash,
      outlineVariant: ash.withValues(alpha: 0.5),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: parchment,
      fontFamily: serifFont,
      canvasColor: parchment,
      cardColor: Colors.white,
      dividerColor: ash,
      appBarTheme: const AppBarTheme(
        backgroundColor: parchment,
        foregroundColor: offBlack,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: serifFont,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: offBlack,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: ash, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(
          fontFamily: monoFont,
          color: smoke,
          fontSize: 13,
        ),
        labelStyle: const TextStyle(
          fontFamily: monoFont,
          color: graphite,
          fontSize: 13,
        ),
        prefixIconColor: smoke,
        suffixIconColor: smoke,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: ash, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: ash, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: lakeBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: Color(0xFFB3261E), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: Color(0xFFB3261E), width: 1.5),
        ),
        errorStyle: const TextStyle(
          fontFamily: monoFont,
          color: Color(0xFFB3261E),
          fontSize: 11,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lakeBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: monoFont,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: lakeBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: monoFont,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: offBlack,
          side: const BorderSide(color: ash, width: 1),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: monoFont,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lakeBlue,
          textStyle: const TextStyle(
            fontFamily: monoFont,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: parchment,
        selectedColor: lakeBlue,
        disabledColor: parchment,
        labelStyle: const TextStyle(
          fontFamily: monoFont,
          fontSize: 12,
          color: offBlack,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: monoFont,
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        side: const BorderSide(color: ash, width: 1),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: periwinkle,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: lakeBlue, size: 24);
          }
          return const IconThemeData(color: smoke, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: monoFont,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: lakeBlue,
            );
          }
          return const TextStyle(
            fontFamily: monoFont,
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: smoke,
          );
        }),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: offBlack,
        shape: StadiumBorder(),
        contentTextStyle: TextStyle(
          fontFamily: monoFont,
          color: parchment,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: ash, width: 1),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: serifFont,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: offBlack,
        ),
      ),
    );
  }

  /// Dark fallback alias pointing to Monad theme so that existing references use the Monad system
  static ThemeData get dark => monadTheme;

  /// Light theme
  static ThemeData get light => monadTheme;
}
