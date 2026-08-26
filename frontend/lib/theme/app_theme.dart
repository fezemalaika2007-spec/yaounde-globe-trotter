import 'package:flutter/material.dart';

/// Travel-inspired Material 3 theme for Yaounde.Trip.
class AppTheme {
  static const Color primaryColor = Color(0xFF00695C);
  static const Color secondaryColor = Color(0xFF0288D1);
  static const Color accentColor = Color(0xFFFFB300);
  static const double cardRadius = 16;
  static const double screenPadding = 16;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      secondary: secondaryColor,
      brightness: Brightness.light,
    );
    return _base(scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      secondary: secondaryColor,
      brightness: Brightness.dark,
    );
    return _base(scheme);
  }

  static ThemeData _base(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: isDark ? const Color(0xFF121517) : const Color(0xFFF7F9FB),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: isDark ? const Color(0xFF1B1F23) : scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.bold,
          color: scheme.onSurface,
          letterSpacing: 0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: isDark ? 2 : 1.5,
        shadowColor: isDark ? Colors.black45 : Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.4),
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? const Color(0xFF22262B)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        elevation: 3,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: scheme.primary,
            );
          }
          return TextStyle(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
      ),
    );
  }
}
