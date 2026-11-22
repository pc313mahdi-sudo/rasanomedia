import 'package:flutter/material.dart';

class RasayarTheme {
  static const Color orange = Color(0xFFFF702E);
  static const Color ink = Color(0xFF141416);
  static const Color panel = Color(0xFF202024);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: orange,
      brightness: brightness,
      surface: isDark ? panel : Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? ink : const Color(0xFFF6F6F8),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? ink : const Color(0xFFF6F6F8),
        foregroundColor: isDark ? Colors.white : const Color(0xFF171719),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: isDark ? panel : Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF29292F) : const Color(0xFFEDEDF1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? panel : Colors.white,
        indicatorColor: orange.withValues(alpha: .16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800 : FontWeight.w500,
        )),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: orange,
        foregroundColor: Colors.white,
      ),
    );
  }
}
