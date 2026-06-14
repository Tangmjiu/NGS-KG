import 'package:flutter/material.dart';

/// MD3 形状 token — 统一 RadiusSource，禁止 magic number
abstract final class AppShape {
  AppShape._();

  /// extra-small: 4dp — Chips, snackbars
  static const BorderRadius xs = BorderRadius.all(Radius.circular(4));

  /// small: 8dp — Text fields, menus, buttons
  static const BorderRadius sm = BorderRadius.all(Radius.circular(8));

  /// medium: 12dp — Cards, dialogs
  static const BorderRadius md = BorderRadius.all(Radius.circular(12));

  /// large: 16dp — FABs, navigation drawer
  static const BorderRadius lg = BorderRadius.all(Radius.circular(16));

  /// extra-large: 28dp — Bottom sheets, dialogs
  static const BorderRadius xl = BorderRadius.all(Radius.circular(28));

  /// full: pill shape — Buttons, chips, badges
  static const BorderRadius full = BorderRadius.all(Radius.circular(9999));
}

class AppTheme {
  // ───── Light palette ─────
  static const Color _primary = Color(0xFF1DB954);
  static const Color _onPrimary = Color(0xFFFFFFFF);
  static const Color _primaryContainer = Color(0xFFB5F5C8);
  static const Color _onPrimaryContainer = Color(0xFF002111);

  static const Color _secondary = Color(0xFF4A9375);
  static const Color _onSecondary = Color(0xFFFFFFFF);
  static const Color _secondaryContainer = Color(0xFFCCF7E0);
  static const Color _onSecondaryContainer = Color(0xFF002112);

  static const Color _tertiary = Color(0xFF3E6A9C);
  static const Color _onTertiary = Color(0xFFFFFFFF);

  static const Color _error = Color(0xFFBA1A1A);
  static const Color _onError = Color(0xFFFFFFFF);
  static const Color _errorContainer = Color(0xFFFFDAD6);
  static const Color _onErrorContainer = Color(0xFF410002);

  static const Color _lightSurfaceBright = Color(0xFFFCFDF8);
  static const Color _lightSurfaceDim = Color(0xFFDDDFD9);
  static const Color _lightSurfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color _lightSurfaceContainerLow = Color(0xFFF7F8F3);
  static const Color _lightSurfaceContainer = Color(0xFFF2F4EE);
  static const Color _lightSurfaceContainerHigh = Color(0xFFEBEDE7);
  static const Color _lightSurfaceContainerHighest = Color(0xFFE0E3DC);
  static const Color _lightOnSurface = Color(0xFF1A1C19);
  static const Color _lightOnSurfaceVariant = Color(0xFF43483F);
  static const Color _lightOutline = Color(0xFF73796F);
  static const Color _lightOutlineVariant = Color(0xFFC3C9BD);
  static const Color _lightInverseSurface = Color(0xFF2F312D);
  static const Color _lightInversePrimary = Color(0xFF8AD8A5);

  // ───── Dark palette ─────
  static const Color _darkPrimary = Color(0xFF8AD8A5);
  static const Color _darkOnPrimary = Color(0xFF003919);
  static const Color _darkPrimaryContainer = Color(0xFF00532A);
  static const Color _darkOnPrimaryContainer = Color(0xFFB5F5C8);

  static const Color _darkSecondary = Color(0xFFB1DBC4);
  static const Color _darkOnSecondary = Color(0xFF1C3728);
  static const Color _darkSecondaryContainer = Color(0xFF334F3E);
  static const Color _darkOnSecondaryContainer = Color(0xFFCCF7E0);

  static const Color _darkTertiary = Color(0xFFB3CDFF);
  static const Color _darkOnTertiary = Color(0xFF002F58);

  static const Color _darkError = Color(0xFFFFB4AB);
  static const Color _darkOnError = Color(0xFF690005);
  static const Color _darkErrorContainer = Color(0xFF93000A);
  static const Color _darkOnErrorContainer = Color(0xFFFFDAD6);

  static const Color _darkSurfaceDim = Color(0xFF121412);
  static const Color _darkSurfaceBright = Color(0xFF383A36);
  static const Color _darkSurfaceContainerLowest = Color(0xFF0D0F0C);
  static const Color _darkSurfaceContainerLow = Color(0xFF1A1C19);
  static const Color _darkSurfaceContainer = Color(0xFF1E201D);
  static const Color _darkSurfaceContainerHigh = Color(0xFF252723);
  static const Color _darkSurfaceContainerHighest = Color(0xFF2A2D28);
  static const Color _darkOnSurface = Color(0xFFE2E3DD);
  static const Color _darkOnSurfaceVariant = Color(0xFFC3C9BD);
  static const Color _darkOutline = Color(0xFF8D9388);
  static const Color _darkOutlineVariant = Color(0xFF43483F);
  static const Color _darkInverseSurface = Color(0xFFE2E3DD);
  static const Color _darkInversePrimary = Color(0xFF006E38);

  // ───── Shape tokens ─────
  static const double cardRadius = 12.0;
  static const double dialogRadius = 16.0;
  static const double inputRadius = 8.0;
  static const double snackBarRadius = 8.0;

  // ───── Light theme ─────
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: _primary,
          onPrimary: _onPrimary,
          primaryContainer: _primaryContainer,
          onPrimaryContainer: _onPrimaryContainer,
          secondary: _secondary,
          onSecondary: _onSecondary,
          secondaryContainer: _secondaryContainer,
          onSecondaryContainer: _onSecondaryContainer,
          tertiary: _tertiary,
          onTertiary: _onTertiary,
          error: _error,
          onError: _onError,
          errorContainer: _errorContainer,
          onErrorContainer: _onErrorContainer,
          surface: _lightSurfaceDim,
          onSurface: _lightOnSurface,
          onSurfaceVariant: _lightOnSurfaceVariant,
          outline: _lightOutline,
          outlineVariant: _lightOutlineVariant,
          inverseSurface: _lightInverseSurface,
          inversePrimary: _lightInversePrimary,
          surfaceBright: _lightSurfaceBright,
          surfaceDim: _lightSurfaceDim,
          surfaceContainerLowest: _lightSurfaceContainerLowest,
          surfaceContainerLow: _lightSurfaceContainerLow,
          surfaceContainer: _lightSurfaceContainer,
          surfaceContainerHigh: _lightSurfaceContainerHigh,
          surfaceContainerHighest: _lightSurfaceContainerHighest,
        ),
        scaffoldBackgroundColor: _lightSurfaceBright,
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          backgroundColor: _lightSurfaceBright,
          foregroundColor: _lightOnSurface,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: _lightSurfaceContainer,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(cardRadius)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: _lightSurfaceBright,
          surfaceTintColor: Colors.transparent,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: _lightSurfaceBright,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(dialogRadius)),
        ),
        dividerTheme: DividerThemeData(
          color: _lightOutlineVariant,
          thickness: 0.5,
          space: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _lightSurfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(inputRadius),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: _lightSurfaceContainer,
          indicatorColor: _primary.withValues(alpha: 0.2),
          surfaceTintColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _primary);
            }
            return const TextStyle(fontSize: 12, color: _lightOutline);
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: _primary, size: 24);
            }
            return const IconThemeData(color: _lightOutline, size: 24);
          }),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: _primary,
          inactiveTrackColor: _lightSurfaceContainerHighest,
          thumbColor: _primary,
          overlayColor: _primary.withValues(alpha: 0.12),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: _primary,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: _lightOnSurface,
          contentTextStyle: TextStyle(color: _lightSurfaceBright),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(snackBarRadius)),
          behavior: SnackBarBehavior.floating,
        ),
        textTheme: _lightTextTheme,
      );

  static const TextTheme _lightTextTheme = TextTheme(
    displayLarge: TextStyle(
        fontSize: 57, fontWeight: FontWeight.w300, color: _lightOnSurface),
    displayMedium: TextStyle(
        fontSize: 45, fontWeight: FontWeight.w300, color: _lightOnSurface),
    displaySmall: TextStyle(
        fontSize: 36, fontWeight: FontWeight.w400, color: _lightOnSurface),
    headlineLarge: TextStyle(
        fontSize: 32, fontWeight: FontWeight.w400, color: _lightOnSurface),
    headlineMedium: TextStyle(
        fontSize: 28, fontWeight: FontWeight.w400, color: _lightOnSurface),
    headlineSmall: TextStyle(
        fontSize: 24, fontWeight: FontWeight.w400, color: _lightOnSurface),
    titleLarge: TextStyle(
        fontSize: 22, fontWeight: FontWeight.w500, color: _lightOnSurface),
    titleMedium: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w500, color: _lightOnSurface),
    titleSmall: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w500, color: _lightOnSurface),
    bodyLarge: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w400, color: _lightOnSurface),
    bodyMedium: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w400, color: _lightOnSurface),
    bodySmall: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w400, color: _lightOnSurface),
    labelLarge: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w500, color: _lightOnSurface),
    labelMedium: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w500, color: _lightOnSurface),
    labelSmall: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w500, color: _lightOnSurface),
  );

  // ───── Dark theme ─────
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: _darkPrimary,
          onPrimary: _darkOnPrimary,
          primaryContainer: _darkPrimaryContainer,
          onPrimaryContainer: _darkOnPrimaryContainer,
          secondary: _darkSecondary,
          onSecondary: _darkOnSecondary,
          secondaryContainer: _darkSecondaryContainer,
          onSecondaryContainer: _darkOnSecondaryContainer,
          tertiary: _darkTertiary,
          onTertiary: _darkOnTertiary,
          error: _darkError,
          onError: _darkOnError,
          errorContainer: _darkErrorContainer,
          onErrorContainer: _darkOnErrorContainer,
          surface: _darkSurfaceDim,
          onSurface: _darkOnSurface,
          onSurfaceVariant: _darkOnSurfaceVariant,
          outline: _darkOutline,
          outlineVariant: _darkOutlineVariant,
          inverseSurface: _darkInverseSurface,
          inversePrimary: _darkInversePrimary,
          surfaceDim: _darkSurfaceDim,
          surfaceBright: _darkSurfaceBright,
          surfaceContainerLowest: _darkSurfaceContainerLowest,
          surfaceContainerLow: _darkSurfaceContainerLow,
          surfaceContainer: _darkSurfaceContainer,
          surfaceContainerHigh: _darkSurfaceContainerHigh,
          surfaceContainerHighest: _darkSurfaceContainerHighest,
        ),
        scaffoldBackgroundColor: _darkSurfaceDim,
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          backgroundColor: _darkSurfaceDim,
          foregroundColor: _darkOnSurface,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: _darkSurfaceContainer,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(cardRadius)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: _darkSurfaceContainer,
          surfaceTintColor: Colors.transparent,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: _darkSurfaceContainer,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(dialogRadius)),
        ),
        dividerTheme: DividerThemeData(
          color: _darkOutlineVariant,
          thickness: 0.5,
          space: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _darkSurfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(inputRadius),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: _darkSurfaceContainer,
          indicatorColor: _darkPrimary.withValues(alpha: 0.2),
          surfaceTintColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _darkPrimary);
            }
            return const TextStyle(fontSize: 12, color: _darkOutline);
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: _darkPrimary, size: 24);
            }
            return const IconThemeData(color: _darkOutline, size: 24);
          }),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: _darkPrimary,
          inactiveTrackColor: _darkSurfaceContainerHighest,
          thumbColor: _darkPrimary,
          overlayColor: _darkPrimary.withValues(alpha: 0.12),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: _darkPrimary,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: _darkOnSurface,
          contentTextStyle: TextStyle(color: _darkSurfaceDim),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(snackBarRadius)),
          behavior: SnackBarBehavior.floating,
        ),
        textTheme: _darkTextTheme,
      );

  static const TextTheme _darkTextTheme = TextTheme(
    displayLarge: TextStyle(
        fontSize: 57, fontWeight: FontWeight.w300, color: _darkOnSurface),
    displayMedium: TextStyle(
        fontSize: 45, fontWeight: FontWeight.w300, color: _darkOnSurface),
    displaySmall: TextStyle(
        fontSize: 36, fontWeight: FontWeight.w400, color: _darkOnSurface),
    headlineLarge: TextStyle(
        fontSize: 32, fontWeight: FontWeight.w400, color: _darkOnSurface),
    headlineMedium: TextStyle(
        fontSize: 28, fontWeight: FontWeight.w400, color: _darkOnSurface),
    headlineSmall: TextStyle(
        fontSize: 24, fontWeight: FontWeight.w400, color: _darkOnSurface),
    titleLarge: TextStyle(
        fontSize: 22, fontWeight: FontWeight.w500, color: _darkOnSurface),
    titleMedium: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w500, color: _darkOnSurface),
    titleSmall: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w500, color: _darkOnSurface),
    bodyLarge: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w400, color: _darkOnSurface),
    bodyMedium: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w400, color: _darkOnSurface),
    bodySmall: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w400, color: _darkOnSurface),
    labelLarge: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w500, color: _darkOnSurface),
    labelMedium: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w500, color: _darkOnSurface),
    labelSmall: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w500, color: _darkOnSurface),
  );
}
