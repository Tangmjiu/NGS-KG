import 'package:flutter/material.dart';
import '../models/theme_pack.dart';

/// MD3 形状 token — 统一 BorderRadius，禁止 magic number
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

/// MD3 响应式断点
abstract final class AppBreakpoint {
  AppBreakpoint._();

  static const double compact = 600;
  static const double medium = 840;
  static const double expanded = 1200;

  static bool isCompact(double width) => width < compact;
  static bool isMedium(double width) => width >= compact && width < medium;
  static bool isExpanded(double width) => width >= medium;

  static int columnCount(double width) =>
      width >= expanded ? 3 : (width >= compact ? 2 : 1);
}

/// MD3 动效 token
abstract final class AppMotion {
  AppMotion._();

  static const Duration ds80 = Duration(milliseconds: 80);
  static const Duration ds200 = Duration(milliseconds: 200);
  static const Duration ds250 = Duration(milliseconds: 250);
  static const Duration ds300 = Duration(milliseconds: 300);
  static const Duration ds400 = Duration(milliseconds: 400);
  static const Duration ds500 = Duration(milliseconds: 500);
  static const Duration ds800 = Duration(milliseconds: 800);

  static const Curve accelerate = Curves.easeIn;
  static const Curve decelerate = Curves.easeOut;
  static const Curve emphasized = Curves.fastOutSlowIn;
  static const Curve standardAccelerate = Curves.easeIn;
  static const Curve standardDecelerate = Curves.easeOut;
  static const Curve linear = Curves.linear;
}

/// 基于 ColorScheme + ThemePack 构建纯原生 MD3 ThemeData
///
/// 所有组件主题统一使用 AppShape/AppMotion 令牌，禁止 magic number。
ThemeData buildThemeData(ColorScheme colorScheme, ThemePack pack, {bool hasGlobalBg = false}) {
  final isDark = colorScheme.brightness == Brightness.dark;
  final rawSurface = isDark ? colorScheme.surfaceDim : colorScheme.surfaceBright;
  // 有全局背景时，让 surface 半透明以便背景图透出
  final surface = hasGlobalBg ? rawSurface.withValues(alpha: 0.85) : rawSurface;

  // ── 从主题包解析形状覆盖 ──
  final s = pack.shapes;
  final double radiusXs = s?['xs'] ?? 4;
  final double radiusSm = s?['sm'] ?? 8;
  final double radiusMd = s?['md'] ?? 12;
  final double radiusLg = s?['lg'] ?? 16;
  final double radiusXl = s?['xl'] ?? 28;

  // ── 动效覆盖 ──
  final motion = pack.motion;
  final curve = motion.resolvedCurve;

  // ── 组件覆盖 ──
  final comp = pack.components;

  return ThemeData(
    useMaterial3: true,
    brightness: colorScheme.brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: surface,

    // ── AppBar ──
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: surface,
      foregroundColor: colorScheme.onSurface,
    ),

    // ── Card ──
    cardTheme: CardThemeData(
      elevation: comp.cardElevation,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(radiusMd))),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),

    // ── Bottom Sheet ──
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(radiusXl))),
    ),

    // ── Dialog ──
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      elevation: comp.dialogElevation,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(radiusLg))),
    ),

    // ── Divider ──
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 0.5,
      space: 0,
    ),

    // ── Input ──
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(radiusSm)),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),

    // ── ListTile ──
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),

    // ── NavigationBar ──
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surfaceContainer,
      indicatorColor: colorScheme.primary.withValues(alpha: 0.2),
      surfaceTintColor: Colors.transparent,
      elevation: comp.navigationBarElevation,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorScheme.primary,
          );
        }
        return TextStyle(fontSize: 12, color: colorScheme.outline);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: colorScheme.primary, size: 24);
        }
        return IconThemeData(color: colorScheme.outline, size: 24);
      }),
    ),

    // ── Slider ──
    sliderTheme: SliderThemeData(
      activeTrackColor: colorScheme.primary,
      inactiveTrackColor: colorScheme.surfaceContainerHighest,
      thumbColor: colorScheme.primary,
      overlayColor: colorScheme.primary.withValues(alpha: 0.12),
    ),

    // ── ProgressIndicator ──
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
    ),

    // ── SnackBar ──
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: TextStyle(
        color: colorScheme.brightness == Brightness.dark
            ? const Color(0xFF000000)
            : const Color(0xFFFFFFFF),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(radiusSm))),
      behavior: SnackBarBehavior.floating,
    ),

    // ── Text ──
    textTheme: _buildTextTheme(colorScheme, pack.fontFamily),
  );
}

TextTheme _buildTextTheme(ColorScheme cs, String? fontFamily) {
  final base = TextTheme(
    displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w300, color: cs.onSurface),
    displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w300, color: cs.onSurface),
    displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400, color: cs.onSurface),
    headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w400, color: cs.onSurface),
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w400, color: cs.onSurface),
    headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w400, color: cs.onSurface),
    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: cs.onSurface),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: cs.onSurface),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: cs.onSurface),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: cs.onSurface),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: cs.onSurface),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: cs.onSurfaceVariant),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: cs.onSurface),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
    labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
  );
  if (fontFamily != null) {
    return base.apply(fontFamily: fontFamily);
  }
  return base;
}
