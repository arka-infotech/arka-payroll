import 'package:flutter/material.dart';

/// Brand palette — deep teal / slate (not purple-default AI look).
class ArkaColors {
  static const Color navy = Color(0xFF0B3D5C);
  static const Color teal = Color(0xFF1A6B7A);
  static const Color sand = Color(0xFFF3F6F8);
  static const Color ink = Color(0xFF1A1A1A);
  static const Color muted = Color(0xFF5C6B73);
}

class ArkaTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ArkaColors.navy,
        primary: ArkaColors.navy,
        secondary: ArkaColors.teal,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: ArkaColors.sand,
      fontFamily: 'Segoe UI',
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: ArkaColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ArkaColors.navy,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
