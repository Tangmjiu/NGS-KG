// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../models/theme_pack.dart';
import '../ui/foundation/app_motion_theme.dart';
import 'app_theme_tokens.dart';

/// 主操作独立于普通按钮，保留主题提供的形状与排版。
@immutable
class AppButtonTheme extends ThemeExtension<AppButtonTheme> {
  final ButtonStyle primaryStyle;

  const AppButtonTheme({required this.primaryStyle});

  static ButtonStyle primaryStyleOf(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppButtonTheme>()?.primaryStyle ??
        ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(64, 56)),
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
          textStyle: WidgetStatePropertyAll(theme.textTheme.titleMedium),
          iconSize: const WidgetStatePropertyAll(24),
          tapTargetSize: MaterialTapTargetSize.padded,
          visualDensity: VisualDensity.standard,
          shape: WidgetStateProperty.resolveWith((states) => states
                  .contains(WidgetState.pressed)
              ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              : const StadiumBorder()),
        );
  }

  @override
  AppButtonTheme copyWith({ButtonStyle? primaryStyle}) =>
      AppButtonTheme(primaryStyle: primaryStyle ?? this.primaryStyle);

  @override
  AppButtonTheme lerp(covariant AppButtonTheme? other, double t) {
    if (other == null) return this;
    return AppButtonTheme(
        primaryStyle: ButtonStyle.lerp(primaryStyle, other.primaryStyle, t)!);
  }
}

/// 应用主题的唯一构建入口。
abstract final class AppTheme {
  static ThemeData build(ColorScheme colors, ThemePack pack,
      {bool hasGlobalBg = false}) {
    final tokens = pack.tokens ??
        AppThemeTokens.fromJson({
          'cardRadius': pack.shapes?['lg'],
          'controlRadius': pack.shapes?['md'],
        });
    final fontFamily = pack.fontFamily ?? 'HarmonyOS Sans';
    final surface =
        hasGlobalBg ? colors.surface.withValues(alpha: 0.88) : colors.surface;
    RoundedRectangleBorder rounded(double radius) =>
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    final card = rounded(tokens.cardRadius);
    final control = rounded(tokens.controlRadius);
    final sheetRadius = pack.shapes?['xl'] ?? tokens.cardRadius + 4;
    final base = ThemeData(
      useMaterial3: true,
      brightness: colors.brightness,
      colorScheme: colors,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: surface,
      extensions: [
        tokens,
        AppMotionTheme(
            durationScale: pack.motion.durationScale,
            effectsCurve: pack.motion.resolvedCurve)
      ],
    );
    final text = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
          fontSize: 36,
          height: 44 / 36,
          fontWeight: FontWeight.w400,
          letterSpacing: 0),
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
          fontSize: 32,
          height: 40 / 32,
          fontWeight: FontWeight.w400,
          letterSpacing: 0),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontSize: 28,
          height: 36 / 28,
          fontWeight: FontWeight.w400,
          letterSpacing: 0),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontSize: 24,
          height: 32 / 24,
          fontWeight: FontWeight.w400,
          letterSpacing: 0),
      titleLarge: base.textTheme.titleLarge?.copyWith(
          fontSize: 22,
          height: 28 / 22,
          fontWeight: FontWeight.w400,
          letterSpacing: 0),
      titleMedium: base.textTheme.titleMedium?.copyWith(
          fontSize: 16,
          height: 24 / 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
          fontSize: 16,
          height: 24 / 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.2),
      bodySmall: base.textTheme.bodySmall?.copyWith(
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
          color: colors.onSurfaceVariant),
    );
    WidgetStateProperty<OutlinedBorder?> buttonShape(double pressedRadius) {
      final customRadius = pack.shapes?['md'];
      if (customRadius != null) {
        return WidgetStatePropertyAll(rounded(customRadius));
      }
      return WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.pressed)
              ? rounded(pressedRadius)
              : const StadiumBorder());
    }

    final buttonStyle = ButtonStyle(
      shape: buttonShape(8),
      minimumSize: const WidgetStatePropertyAll(Size(64, 40)),
      padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
      textStyle: WidgetStatePropertyAll(text.labelLarge),
      iconSize: const WidgetStatePropertyAll(20),
      tapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      animationDuration: pack.motion.scale(const Duration(milliseconds: 200)),
    );
    final primaryButtonStyle = buttonStyle.copyWith(
      shape: buttonShape(12),
      minimumSize: const WidgetStatePropertyAll(Size(64, 56)),
      padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
      textStyle: WidgetStatePropertyAll(text.titleMedium),
      iconSize: const WidgetStatePropertyAll(24),
    );
    return base.copyWith(
      textTheme: text,
      extensions: [
        ...base.extensions.values,
        AppButtonTheme(primaryStyle: primaryButtonStyle),
      ],
      pageTransitionsTheme: PageTransitionsTheme(builders: {
        for (final platform in TargetPlatform.values)
          platform: _ThemePageTransitions(pack.motion),
      }),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.onSurface,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: pack.components.cardElevation,
        color: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: card,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding:
            EdgeInsets.symmetric(horizontal: tokens.pagePadding, vertical: 6),
        minVerticalPadding: 10,
        shape: control,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle:
            text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        iconColor: colors.onSurfaceVariant,
        selectedColor: colors.primary,
        selectedTileColor: colors.secondaryContainer,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: pack.components.navigationBarElevation,
        indicatorColor: colors.secondaryContainer,
        indicatorShape: control,
        labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => text.labelMedium?.copyWith(
                  color: states.contains(WidgetState.selected)
                      ? colors.onSurface
                      : colors.onSurfaceVariant,
                  fontWeight: states.contains(WidgetState.selected)
                      ? FontWeight.w600
                      : FontWeight.w500,
                )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 24,
              color: states.contains(WidgetState.selected)
                  ? colors.onSecondaryContainer
                  : colors.onSurfaceVariant,
            )),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: colors.secondaryContainer,
        indicatorShape: control,
        selectedIconTheme: IconThemeData(color: colors.onSecondaryContainer),
        unselectedIconTheme: IconThemeData(color: colors.onSurfaceVariant),
        selectedLabelTextStyle: text.labelMedium,
        unselectedLabelTextStyle:
            text.labelMedium?.copyWith(color: colors.onSurfaceVariant),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.6),
        hintStyle: text.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(tokens.controlRadius),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(tokens.controlRadius),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(tokens.controlRadius),
            borderSide: BorderSide(color: colors.primary, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      chipTheme: ChipThemeData(
        shape: rounded(pack.shapes?['xs'] ?? tokens.controlRadius),
        backgroundColor: colors.surfaceContainerLow,
        selectedColor: colors.secondaryContainer,
        labelStyle: text.labelLarge,
        secondaryLabelStyle:
            text.labelLarge?.copyWith(color: colors.onSecondaryContainer),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall,
        labelColor: colors.primary,
        unselectedLabelColor: colors.onSurfaceVariant,
        indicatorColor: colors.primary,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.label,
        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: colors.outlineVariant,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(sheetRadius))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: pack.components.dialogElevation,
        shape: card,
        titleTextStyle: text.titleLarge,
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant.withValues(alpha: 0.55),
        thickness: 0.5,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
      textButtonTheme: TextButtonThemeData(style: buttonStyle),
      iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
        tapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.standard,
        shape: buttonShape(8),
        animationDuration: pack.motion.scale(const Duration(milliseconds: 200)),
      )),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: control,
        elevation: 1,
        foregroundColor: colors.onPrimaryContainer,
        backgroundColor: colors.primaryContainer,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.surfaceContainerHighest,
        thumbColor: colors.primary,
        overlayColor: colors.primary.withValues(alpha: 0.12),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.inverseSurface,
        contentTextStyle:
            text.bodyMedium?.copyWith(color: colors.onInverseSurface),
        shape: rounded(pack.shapes?['sm'] ?? tokens.controlRadius),
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: control,
        color: colors.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.primary),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
            color: colors.inverseSurface,
            borderRadius: BorderRadius.circular(8)),
        textStyle: text.bodySmall?.copyWith(color: colors.onInverseSurface),
      ),
    );
  }
}

class _ThemePageTransitions extends PageTransitionsBuilder {
  final ThemeMotion motion;
  const _ThemePageTransitions(this.motion);

  @override
  Duration get transitionDuration =>
      motion.scale(const Duration(milliseconds: 300));

  @override
  Duration get reverseTransitionDuration =>
      motion.scale(const Duration(milliseconds: 250));

  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    if (Theme.of(context).platform == TargetPlatform.android) {
      return const PredictiveBackPageTransitionsBuilder().buildTransitions(
          route, context, animation, secondaryAnimation, child);
    }
    final curved = animation.drive(CurveTween(curve: motion.resolvedCurve));
    return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: curved
              .drive(Tween(begin: const Offset(0, 0.025), end: Offset.zero)),
          child: child,
        ));
  }
}
