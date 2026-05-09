import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF1DB954);
  static const Color darkSurface = Color(0xFF121212);
  static const Color darkCard = Color(0xFF1E1E1E);

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: primaryColor,
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16),
        ),
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: primaryColor,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkSurface,
        cardColor: darkCard,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: darkSurface,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: darkCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: darkCard,
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: darkCard,
          indicatorColor: primaryColor.withAlpha(51),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
            }
            return TextStyle(fontSize: 12, color: Colors.grey[400]);
          }),
        ),
      );
}
