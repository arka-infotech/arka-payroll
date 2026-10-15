import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ArkaColors {
  static const Color navy = Color(0xFF0A3550);
  static const Color teal = Color(0xFF14808F);
  static const Color accent = Color(0xFF3D9EFF);
  static const Color sand = Color(0xFFF0F4F8);
  static const Color ink = Color(0xFF1A2332);
  static const Color muted = Color(0xFF64748B);
  static const Color darkSurface = Color(0xFF0C1017);
  static const Color darkCard = Color(0xFF151B26);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
}

class ArkaTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: dark ? ArkaColors.accent : ArkaColors.navy,
      brightness: brightness,
      primary: dark ? ArkaColors.accent : ArkaColors.navy,
      secondary: ArkaColors.teal,
      surface: dark ? ArkaColors.darkCard : Colors.white,
    );

    final textTheme = GoogleFonts.sourceSans3TextTheme(
      dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    ).apply(
      bodyColor: dark ? Colors.white : ArkaColors.ink,
      displayColor: dark ? Colors.white : ArkaColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: dark ? ArkaColors.darkSurface : ArkaColors.sand,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? ArkaColors.darkCard : ArkaColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.sourceSans3(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: dark ? Colors.white10 : const Color(0xFFE6ECF1),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF222833) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: dark ? Colors.white12 : const Color(0xFFD7E0E8),
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: dark ? ArkaColors.darkCard : Colors.white,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.secondary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.secondary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        backgroundColor: dark ? ArkaColors.darkCard : Colors.white,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }
}
