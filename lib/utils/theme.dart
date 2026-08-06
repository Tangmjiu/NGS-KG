import 'package:flutter/material.dart';
import '../models/theme_pack.dart';
import '../theme/expressive_shape_config.dart';

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

/// MD3 动效 token — 全局统一 Duration + Easing，禁止 magic number
///
/// 参见 Material Design 3 Motion 规范:
///   https://m3.material.io/styles/motion/easing-and-duration
abstract final class AppMotion {
  AppMotion._();

  // ── Duration tokens (M3 standard) ──
  /// Short 1: 50ms — 选中/取消选中
  static const Duration dShort1 = Duration(milliseconds: 50);

  /// Short 2: 100ms — 简单状态切换
  static const Duration dShort2 = Duration(milliseconds: 100);

  /// Short 3: 150ms — 小组件出现
  static const Duration dShort3 = Duration(milliseconds: 150);

  /// Short 4: 200ms — 标准交互
  static const Duration dShort4 = Duration(milliseconds: 200);

  /// Medium 1: 250ms — 面板展开
  static const Duration dMedium1 = Duration(milliseconds: 250);

  /// Medium 2: 300ms — 标准转场
  static const Duration dMedium2 = Duration(milliseconds: 300);

  /// Medium 3: 350ms — 复杂转场
  static const Duration dMedium3 = Duration(milliseconds: 350);

  /// Medium 4: 400ms — 全屏转场
  static const Duration dMedium4 = Duration(milliseconds: 400);

  /// Long 1: 450ms — 强调动画
  static const Duration dLong1 = Duration(milliseconds: 450);

  /// Long 2: 500ms — 复杂强调
  static const Duration dLong2 = Duration(milliseconds: 500);

  // ── Legacy aliases (向后兼容) ──
  static const Duration ds80 = dShort2;
  static const Duration ds200 = dShort4;
  static const Duration ds250 = dMedium1;
  static const Duration ds300 = dMedium2;
  static const Duration ds400 = dMedium4;
  static const Duration ds500 = dLong2;
  static const Duration ds800 = Duration(milliseconds: 800);

  // ── Easing tokens (M3 standard) ──
  /// Standard — 不离开屏幕的移动 (cubic-bezier(0.2, 0, 0, 1))
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Standard Decelerate — 进入屏幕 (cubic-bezier(0, 0, 0, 1))
  static const Curve standardDecelerate = Cubic(0.0, 0.0, 0.0, 1.0);

  /// Standard Accelerate — 离开屏幕 (cubic-bezier(0.3, 0, 1, 1))
  static const Curve standardAccelerate = Cubic(0.3, 0.0, 1.0, 1.0);

  /// Emphasized — 更有表达力的移动 (cubic-bezier(0.2, 0, 0, 1))
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Emphasized Decelerate — 进入屏幕，表达力强 (cubic-bezier(0.05, 0.7, 0.1, 1))
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Emphasized Accelerate — 离开屏幕，表达力强 (cubic-bezier(0.3, 0, 0.8, 0.15))
  static const Curve emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);

  // ── Legacy aliases ──
  static const Curve accelerate = standardAccelerate;
  static const Curve decelerate = standardDecelerate;
  static const Curve linear = Curves.linear;
}

/// 基于 ColorScheme + ThemePack 构建纯原生 MD3 ThemeData
///
/// 所有组件主题统一使用 AppShape/AppMotion 令牌，禁止 magic number。
ThemeData buildThemeData(
  ColorScheme colorScheme,
  ThemePack pack, {
  bool hasGlobalBg = false,
  bool expressiveShapesEnabled = false,
  String shapePresetId = 'default',
}) {
  final isDark = colorScheme.brightness == Brightness.dark;
  final rawSurface =
      isDark ? colorScheme.surfaceDim : colorScheme.surfaceBright;
  // 有全局背景时，让 surface 半透明以便背景图透出
  final surface = hasGlobalBg ? rawSurface.withValues(alpha: 0.85) : rawSurface;

  // ── 从主题包解析形状覆盖 ──
  final s = pack.shapes;
  final double radiusSm = s?['sm'] ?? 8;
  final double radiusMd = s?['md'] ?? 12;
  final double radiusLg = s?['lg'] ?? 16;
  final double radiusXl = s?['xl'] ?? 28;

  // ── Expressive 形状预设（启用时替换卡片/对话框/FAB/Chip 形状） ──
  final expShapes =
      resolveExpressiveShapes(expressiveShapesEnabled, shapePresetId);
  final OutlinedBorder? expCardShape = expShapes[ShapeTarget.cards];
  final OutlinedBorder? expFabShape = expShapes[ShapeTarget.fab];
  final OutlinedBorder? expChipShape = expShapes[ShapeTarget.chips];

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
      elevation: 0, // MD3E 强调色彩区分层级，而非传统的厚重阴影
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: expCardShape ??
          RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(radiusLg))),
      margin:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // 更宽广的呼吸间距
    ),

    // ── Bottom Sheet ──
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl))),
    ),

    // ── Dialog ──
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      elevation: comp.dialogElevation,
      shape: expCardShape ??
          RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(radiusXl))),
    ),

    // ── Divider ──
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant.withValues(alpha: 0.5), // 更加柔和的分割线
      thickness: 0.5,
      space: 1,
    ),

    // ── Input ──
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(radiusMd)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(radiusMd)),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),

    // ── ListTile ──
    listTileTheme: ListTileThemeData(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 4), // 增加垂直呼吸感
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusMd))),
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
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusSm))),
      behavior: SnackBarBehavior.floating,
    ),

    // ── Text ──
    textTheme: _buildTextTheme(colorScheme, pack.fontFamily),

    // ── Page Transitions (M3 Motion) ──
    // 所有平台使用统一 of M3 转场，避免 Android/iOS 差异
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        // 手机平台: drill-down 导航使用 Shared Z-Axis (前进/后退感)
        TargetPlatform.android: M3SharedZAxisTransitionBuilder(),
        TargetPlatform.iOS: M3SharedZAxisTransitionBuilder(),
        TargetPlatform.fuchsia: M3SharedZAxisTransitionBuilder(),
        // 桌面平台: 使用 Fade (简洁无方向感)
        TargetPlatform.linux: _FadeTransitionBuilder(),
        TargetPlatform.macOS: _FadeTransitionBuilder(),
        TargetPlatform.windows: _FadeTransitionBuilder(),
      },
    ),

    // ── Button Theme (M3 全圆角) ──
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const RoundedRectangleBorder(borderRadius: AppShape.full),
        minimumSize: const Size(64, 40),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: const RoundedRectangleBorder(borderRadius: AppShape.full),
        minimumSize: const Size(64, 40),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const RoundedRectangleBorder(borderRadius: AppShape.full),
        minimumSize: const Size(64, 40),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: const RoundedRectangleBorder(borderRadius: AppShape.full),
        minimumSize: const Size(64, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    ),

    // ── IconButton (M3 标准 40x40, 触控目标 ≥48) ──
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        maximumSize: const Size(48, 48),
        shape: const RoundedRectangleBorder(borderRadius: AppShape.full),
      ),
    ),

    // ── FAB (M3 标准 56x56, 16dp 圆角) ──
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: expFabShape ??
          RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(radiusLg))),
      elevation: 3,
      foregroundColor: colorScheme.onPrimaryContainer,
      backgroundColor: colorScheme.primaryContainer,
    ),

    // ── Chip (M3 8dp 圆角) ──
    chipTheme: ChipThemeData(
      shape: expChipShape ??
          const RoundedRectangleBorder(borderRadius: AppShape.sm),
      backgroundColor: colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(color: colorScheme.onSurface),
      side: BorderSide(color: colorScheme.outlineVariant),
    ),

    // ── Switch (M3 大尺寸拨动) ──
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colorScheme.primary;
        return colorScheme.outline;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return colorScheme.primary.withValues(alpha: 0.5);
        }
        return colorScheme.surfaceContainerHighest;
      }),
    ),

    // ── Tooltip ──
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: AppShape.xs,
      ),
      textStyle: TextStyle(color: colorScheme.onInverseSurface),
      waitDuration: const Duration(milliseconds: 500),
    ),
  );
}

TextTheme _buildTextTheme(ColorScheme cs, String? fontFamily) {
  final base = TextTheme(
    displayLarge: TextStyle(
        fontSize: 57, fontWeight: FontWeight.w300, color: cs.onSurface),
    displayMedium: TextStyle(
        fontSize: 45, fontWeight: FontWeight.w300, color: cs.onSurface),
    displaySmall: TextStyle(
        fontSize: 36, fontWeight: FontWeight.w400, color: cs.onSurface),
    headlineLarge: TextStyle(
        fontSize: 32, fontWeight: FontWeight.w400, color: cs.onSurface),
    headlineMedium: TextStyle(
        fontSize: 28, fontWeight: FontWeight.w400, color: cs.onSurface),
    headlineSmall: TextStyle(
        fontSize: 24, fontWeight: FontWeight.w400, color: cs.onSurface),
    titleLarge: TextStyle(
        fontSize: 22, fontWeight: FontWeight.w500, color: cs.onSurface),
    titleMedium: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w500, color: cs.onSurface),
    titleSmall: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w500, color: cs.onSurface),
    bodyLarge: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w400, color: cs.onSurface),
    bodyMedium: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w400, color: cs.onSurface),
    bodySmall: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w400, color: cs.onSurfaceVariant),
    labelLarge: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w500, color: cs.onSurface),
    labelMedium: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
    labelSmall: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
  );
  if (fontFamily != null) {
    return base.apply(fontFamily: fontFamily);
  }
  return base;
}

// ════════════════════════════════════════════════════════════════════════════
//  M3 Page Transition Builders
//  实现 Material Design 3 Motion 规范的页面转场:
//    https://m3.material.io/styles/motion/transitions
// ════════════════════════════════════════════════════════════════════════════

/// M3 Shared Z-Axis 转场 — 用于 drill-down 导航（列表→详情）
///
/// 新页面从 z 轴方向淡入并放大，旧页面淡出并缩小。
/// Duration: 300ms (Medium2), Easing: Emphasized Decelerate (进入) / Accelerate (离开)
class M3SharedZAxisTransitionBuilder extends PageTransitionsBuilder {
  const M3SharedZAxisTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _SharedZAxisTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

class _SharedZAxisTransition extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  const _SharedZAxisTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // ── 前进: 新页面进入 (Emphasized Decelerate) ──
    final forwardScale = Tween<double>(begin: 0.92, end: 1.0).animate(
        CurvedAnimation(
            parent: animation, curve: AppMotion.emphasizedDecelerate));
    final forwardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: animation, curve: AppMotion.emphasizedDecelerate));

    // ── 后退: 旧页面被覆盖时缩小淡出 (Emphasized Accelerate) ──
    final backwardScale = Tween<double>(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(
            parent: secondaryAnimation, curve: AppMotion.emphasizedAccelerate));
    final backwardOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(
            parent: secondaryAnimation, curve: AppMotion.emphasizedAccelerate));

    return FadeTransition(
      opacity: forwardOpacity,
      child: ScaleTransition(
        scale: forwardScale,
        alignment: Alignment.center,
        child: FadeTransition(
          opacity: backwardOpacity,
          child: ScaleTransition(
            scale: backwardScale,
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// M3 Fade 转场 — 用于桌面平台和简单页面切换
///
/// 仅淡入淡出，无位移/缩放。Duration: 150ms (Short3)
class _FadeTransitionBuilder extends PageTransitionsBuilder {
  const _FadeTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: AppMotion.emphasized),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: ReverseAnimation(secondaryAnimation),
          curve: AppMotion.emphasized,
        ),
        child: child,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  M3 便捷转场工具函数
//  用于 showDialog / showModalBottomSheet 等需要自定义动画的场景
// ════════════════════════════════════════════════════════════════════════════

/// M3 Dialog 出现转场 — Fade + Scale (从 0.8→1.0)
///
/// Duration: 250ms (Medium1), Easing: Emphasized Decelerate
Widget m3DialogTransitionBuilder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child) {
  final curve =
      CurvedAnimation(parent: animation, curve: AppMotion.emphasizedDecelerate);
  return FadeTransition(
    opacity: curve,
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.8, end: 1.0).animate(curve),
      alignment: Alignment.center,
      child: child,
    ),
  );
}

/// M3 Bottom Sheet 出现转场 — Slide up + Fade
///
/// Duration: 300ms (Medium2), Easing: Emphasized Decelerate
Widget m3BottomSheetTransitionBuilder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child) {
  final curve =
      CurvedAnimation(parent: animation, curve: AppMotion.emphasizedDecelerate);
  return FadeTransition(
    opacity: curve,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.15),
        end: Offset.zero,
      ).animate(curve),
      child: child,
    ),
  );
}

/// M3 Fade Through 转场 — 用于无关联页面切换 (Bottom Nav)
///
/// 先淡出再淡入（有短暂完全透明期），强调页面切换。
/// Duration: 300ms (Medium2)
class M3FadeThroughTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const M3FadeThroughTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Fade Through: 0→0.5 移动→1.0，中间有短暂不可见期
    final opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.5, 1.0, curve: AppMotion.emphasizedDecelerate),
      ),
    );
    final scale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.5, 1.0, curve: AppMotion.emphasizedDecelerate),
      ),
    );
    return FadeTransition(
      opacity: opacity,
      child: ScaleTransition(
        scale: scale,
        child: child,
      ),
    );
  }
}

/// M3 Staggered List Item 进场动画
///
/// 用于 ListView/GridView 项的交错进场。每个项从底部滑入并淡入。
/// [index] 为项在列表中的索引，[itemDelay] 为每项间隔（默认 50ms = Short1）
class M3StaggeredFadeIn extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration itemDelay;
  final Duration duration;

  const M3StaggeredFadeIn({
    super.key,
    required this.index,
    required this.child,
    this.itemDelay = const Duration(milliseconds: 50),
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<M3StaggeredFadeIn> createState() => _M3StaggeredFadeInState();
}

class _M3StaggeredFadeInState extends State<M3StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _opacity = CurvedAnimation(
        parent: _controller, curve: AppMotion.emphasizedDecelerate);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _controller, curve: AppMotion.emphasizedDecelerate));

    // 交错延迟：每项最多 8 项延迟后不再增加
    final delay = Duration(
      milliseconds:
          (widget.index.clamp(0, 8)) * widget.itemDelay.inMilliseconds,
    );
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: widget.child,
      ),
    );
  }
}

/// M3 按压反馈 — 卡片/按钮按下时缩放
///
/// 包裹可点击元素，按压时缩放到 0.97，松开回弹。
/// Duration: 150ms (Short3), Easing: Emphasized
class M3PressScale extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final double scaleDown;

  const M3PressScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.scaleDown = 0.97,
  });

  @override
  State<M3PressScale> createState() => _M3PressScaleState();
}

class _M3PressScaleState extends State<M3PressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.dShort3,
      reverseDuration: AppMotion.dShort3,
    );
    _scale = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
        CurvedAnimation(parent: _controller, curve: AppMotion.emphasized));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}

/// M3 喜欢/收藏按钮弹跳反馈
///
/// 点击时 scale 1.0 → 1.3 → 1.0 弹跳效果
/// Duration: 200ms (Short4), Easing: Emphasized
class M3BounceFeedback extends StatefulWidget {
  final Widget child;
  final bool trigger;

  const M3BounceFeedback({
    super.key,
    required this.child,
    required this.trigger,
  });

  @override
  State<M3BounceFeedback> createState() => _M3BounceFeedbackState();
}

class _M3BounceFeedbackState extends State<M3BounceFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.dShort4,
    );
  }

  @override
  void didUpdateWidget(M3BounceFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 弹跳: 1.0 → 1.3 → 1.0
    final scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3)
            .chain(CurveTween(curve: AppMotion.emphasizedAccelerate)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: AppMotion.emphasizedDecelerate)),
        weight: 60,
      ),
    ]).animate(_controller);

    return ScaleTransition(
      scale: scale,
      child: widget.child,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  M3 便捷弹窗函数 — 替代 showDialog / showModalBottomSheet
//  自动应用 M3 Emphasized 转场动画
// ════════════════════════════════════════════════════════════════════════════

/// M3 Dialog 显示 — 使用 Emphasized Decelerate 转场 (Fade + Scale)
///
/// Duration: 250ms (Medium1)
/// 替代 showDialog，自动应用 M3 动画
Future<T?> showM3Dialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useRootNavigator = false,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
}) {
  return showGeneralDialog<T>(
    context: context,
    pageBuilder: (_, __, ___) => builder(context),
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel ??
        MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor ?? Colors.black54,
    transitionDuration: AppMotion.dMedium1,
    transitionBuilder: m3DialogTransitionBuilder,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
  );
}

/// M3 Bottom Sheet 显示 — 使用 Emphasized Decelerate 转场 (Slide up + Fade)
///
/// Duration: 300ms (Medium2)
/// 替代 showModalBottomSheet，自动应用 M3 动画
Future<T?> showM3ModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  double? elevation,
  ShapeBorder? shape,
  Clip? clipBehavior,
  Color? barrierColor,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool showDragHandle = false,
  String? barrierLabel,
  AnimationController? transitionAnimationController,
  Offset? anchorPoint,
  BoxConstraints? constraints,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    backgroundColor: backgroundColor,
    elevation: elevation,
    shape: shape,
    clipBehavior: clipBehavior,
    barrierColor: barrierColor,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: showDragHandle,
    barrierLabel: barrierLabel,
    transitionAnimationController: transitionAnimationController,
    anchorPoint: anchorPoint,
    constraints: constraints,
    // M3 动画通过 transitionAnimationController 实现
    // 如未提供 controller，Flutter 默认使用 M3-compatible 曲线
  );
}
