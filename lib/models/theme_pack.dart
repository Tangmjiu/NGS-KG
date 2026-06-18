import 'package:flutter/material.dart';

/// 动效配置
@immutable
class ThemeMotion {
  final double durationScale;
  final String curve;

  const ThemeMotion({this.durationScale = 1.0, this.curve = 'emphasized'});

  static const ThemeMotion defaults = ThemeMotion();

  Curve get resolvedCurve {
    return switch (curve) {
      'standard' => Curves.easeInOut,
      'linear' => Curves.linear,
      _ => Curves.fastOutSlowIn, // 'emphasized' or fallback
    };
  }

  Duration scale(Duration d) =>
      Duration(milliseconds: (d.inMilliseconds * durationScale).round());
}

/// 组件偏好
@immutable
class ThemeComponents {
  final double navigationBarElevation;
  final double cardElevation;
  final double dialogElevation;

  const ThemeComponents({
    this.navigationBarElevation = 0,
    this.cardElevation = 0,
    this.dialogElevation = 0,
  });

  static const ThemeComponents defaults = ThemeComponents();
}

/// 字体权重文件映射
@immutable
class FontWeightFiles {
  final String regular;
  final String? medium;
  final String? bold;

  const FontWeightFiles({
    required this.regular,
    this.medium,
    this.bold,
  });
}

/// 统一主题包模型
///
/// 所有主题（内置 + 导入 ZIP）统一用此模型表示。
@immutable
class ThemePack {
  final String id;
  final String name;
  final String author;
  final int version;
  final String? description;
  final bool isBuiltIn;
  final String? previewPath;

  // ── 颜色（null = 不由包提供，走 fromSeed 自动生成） ──
  final ColorScheme? lightScheme;
  final ColorScheme? darkScheme;

  // ── 字体 ──
  final String? fontFamily;
  final FontWeightFiles? fontWeightFiles;

  // ── 形状覆盖 ──
  final Map<String, double>? shapes;

  // ── 动效 ──
  final ThemeMotion motion;

  // ── 组件偏好 ──
  final ThemeComponents components;

  // ── 资源图 {key → 文件绝对路径} ──
  final Map<String, String>? assetFiles;

  // ── 播放器壁纸 ──
  final String? playerBgPath;

  const ThemePack({
    required this.id,
    required this.name,
    required this.author,
    this.version = 1,
    this.description,
    this.isBuiltIn = false,
    this.previewPath,
    this.lightScheme,
    this.darkScheme,
    this.fontFamily,
    this.fontWeightFiles,
    this.shapes,
    this.motion = ThemeMotion.defaults,
    this.components = ThemeComponents.defaults,
    this.assetFiles,
    this.playerBgPath,
  });

  /// 是否有完整 30 色色板
  bool get hasFullColors => lightScheme != null;

  /// UI 覆盖能力清单
  List<String> get featureTags {
    final tags = <String>[];
    if (hasFullColors) tags.add('完整色板');
    final assetCount = assetFiles?.length ?? 0;
    if (assetCount > 6) tags.add('占位图');
    if (fontFamily != null) tags.add('自定义字体');
    if (shapes != null) tags.add('自定义形状');
    if (playerBgPath != null) tags.add('播放器壁纸');
    if (motion.durationScale != 1.0) tags.add('自定义动效');
    return tags;
  }
}

// ─────────────────────────────────────────────────────────────
//  内置主题包常量
// ─────────────────────────────────────────────────────────────

/// NGS 凪砂 — 默认主题
const ThemePack ngsNagisa = ThemePack(
  id: 'ngs_nagisa',
  name: 'Ran Nagisa',
  author: 'mjiutang',
  version: 1,
  isBuiltIn: true,
  description: 'Welcome to Garden of Eden',
  lightScheme: ColorScheme.light(
    primary: Color(0xFFFF6633),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFFFDBC9),
    onPrimaryContainer: Color(0xFF361400),
    secondary: Color(0xFFA85A3A),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFFDBC9),
    onSecondaryContainer: Color(0xFF3A1500),
    tertiary: Color(0xFF8B4E6B),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFFD8E5),
    onTertiaryContainer: Color(0xFF390A27),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFFFF8F6),
    surfaceDim: Color(0xFFE8D6D0),
    surfaceBright: Color(0xFFFFF8F6),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFFF1EC),
    surfaceContainer: Color(0xFFF6E3DC),
    surfaceContainerHigh: Color(0xFFEFDCD6),
    surfaceContainerHighest: Color(0xFFE3D1CA),
    onSurface: Color(0xFF231A17),
    onSurfaceVariant: Color(0xFF53443E),
    outline: Color(0xFF85736C),
    outlineVariant: Color(0xFFD8C2BA),
    inverseSurface: Color(0xFF392E2B),
    inversePrimary: Color(0xFFFFB59A),
  ),
  darkScheme: ColorScheme.dark(
    primary: Color(0xFFFFB59A),
    onPrimary: Color(0xFF552500),
    primaryContainer: Color(0xFF7A3600),
    onPrimaryContainer: Color(0xFFFFDBC9),
    secondary: Color(0xFFFFB59A),
    onSecondary: Color(0xFF552500),
    secondaryContainer: Color(0xFF7A3600),
    onSecondaryContainer: Color(0xFFFFDBC9),
    tertiary: Color(0xFFFFB0CA),
    onTertiary: Color(0xFF55213E),
    tertiaryContainer: Color(0xFF6F3755),
    onTertiaryContainer: Color(0xFFFFD8E5),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF1A110F),
    surfaceDim: Color(0xFF1A110F),
    surfaceBright: Color(0xFF423734),
    surfaceContainerLowest: Color(0xFF140C0A),
    surfaceContainerLow: Color(0xFF231A17),
    surfaceContainer: Color(0xFF271E1B),
    surfaceContainerHigh: Color(0xFF322825),
    surfaceContainerHighest: Color(0xFF3E332F),
    onSurface: Color(0xFFF0DFD9),
    onSurfaceVariant: Color(0xFFD8C2BA),
    outline: Color(0xFFA08D85),
    outlineVariant: Color(0xFF53443E),
    inverseSurface: Color(0xFFF0DFD9),
    inversePrimary: Color(0xFFFF6633),
  ),
  assetFiles: {
    'sthiswrong': 'assets/images/sthiswrong.png',
    'codecrash': 'assets/images/codecrash.png',
    'loading': 'assets/images/loading.png',
    'ban': 'assets/images/ban.png',
    'supportme': 'assets/images/supportme.png',
    'icon': 'assets/images/icon.png',
    'empty_playlist': 'assets/images/empty_playlist.png',
    'empty_content': 'assets/images/empty_content.png',
    'load_failed': 'assets/images/load_failed.png',
  },
);

/// MD3 全局 — 纯 Material Design 3 规范，无自定义图片
const ThemePack md3Default = ThemePack(
  id: 'md3_default',
  name: 'MD3 全局',
  author: 'Material Design 3',
  version: 1,
  isBuiltIn: true,
  description: '纯 Material Design 3 规范，无自定义图片',
  // lightScheme/darkScheme 均为 null → 走 ColorScheme.fromSeed
  // 无 assetFiles → 使用系统图标 fallback
);
