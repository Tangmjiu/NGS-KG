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

  // ── 序列化 ──

  Map<String, dynamic> toJson() => {
    'regular': regular,
    'medium': medium,
    'bold': bold,
  };

  static FontWeightFiles fromJson(Map<String, dynamic> json) => FontWeightFiles(
    regular: json['regular'] as String? ?? '',
    medium: json['medium'] as String?,
    bold: json['bold'] as String?,
  );
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

  // ── 歌词显示设置覆盖（来自主题包 JSON） ──
  final Map<String, dynamic>? lyricSettingsOverride;

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
    this.lyricSettingsOverride,
  });

  /// 是否有完整 30 色色板
  bool get hasFullColors => lightScheme != null;

  // ── 序列化 ──

  /// 将主题包序列化为 JSON-compatible map。
  Map<String, dynamic> toJson() {
    Map<String, dynamic> componentsJson() => {
      'navigationBarElevation': components.navigationBarElevation,
      'cardElevation': components.cardElevation,
      'dialogElevation': components.dialogElevation,
    };

    Map<String, double>? shapeJson(Map<String, double>? s) =>
        s?.map((k, v) => MapEntry(k, v));

    return {
      'id': id,
      'name': name,
      'author': author,
      'version': version,
      'description': description,
      'isBuiltIn': isBuiltIn,
      'previewPath': previewPath,
      'assetFiles': assetFiles,
      'playerBgPath': playerBgPath,
      'fontFamily': fontFamily,
      'fontWeightFiles': fontWeightFiles?.toJson(),
      'shapes': shapeJson(shapes),
      'motion': {
        'durationScale': motion.durationScale,
        'curve': motion.curve,
      },
      'components': componentsJson(),
      if (lightScheme != null)
        'lightScheme': _serializeColorScheme(lightScheme!),
      if (darkScheme != null)
        'darkScheme': _serializeColorScheme(darkScheme!),
      if (lyricSettingsOverride != null)
        'lyricSettingsOverride': lyricSettingsOverride,
    };
  }

  /// 从 JSON map 反序列化 ThemePack。
  /// 用于启动时从磁盘加载已安装的主题。
  factory ThemePack.fromJson(Map<String, dynamic> json) {
    Map<String, double>? parseShapes(dynamic s) {
      if (s == null) return null;
      return (s as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble()));
    }

    return ThemePack(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '未命名主题',
      author: json['author'] as String? ?? '未知作者',
      version: json['version'] as int? ?? 1,
      description: json['description'] as String?,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      previewPath: json['previewPath'] as String?,
      assetFiles: (json['assetFiles'] as Map<String, dynamic>?)
          ?.cast<String, String>(),
      playerBgPath: json['playerBgPath'] as String?,
      fontFamily: json['fontFamily'] as String?,
      fontWeightFiles: json['fontWeightFiles'] != null
          ? FontWeightFiles.fromJson(
              json['fontWeightFiles'] as Map<String, dynamic>)
          : null,
      shapes: parseShapes(json['shapes']),
      motion: json['motion'] != null
          ? ThemeMotion(
              durationScale:
                  (json['motion']['durationScale'] as num?)?.toDouble() ?? 1.0,
              curve: (json['motion']['curve'] as String?) ?? 'emphasized',
            )
          : ThemeMotion.defaults,
      components: json['components'] != null
          ? ThemeComponents(
              navigationBarElevation: (json['components']
                      ['navigationBarElevation'] as num?)
                  ?.toDouble() ?? 0,
              cardElevation:
                  (json['components']['cardElevation'] as num?)?.toDouble() ??
                      0,
              dialogElevation:
                  (json['components']['dialogElevation'] as num?)?.toDouble() ??
                      0,
            )
          : ThemeComponents.defaults,
      lightScheme: json['lightScheme'] != null
          ? _parseColorScheme(
              json['lightScheme'] as Map<String, dynamic>, Brightness.light)
          : null,
      darkScheme: json['darkScheme'] != null
          ? _parseColorScheme(
              json['darkScheme'] as Map<String, dynamic>, Brightness.dark)
          : null,
      lyricSettingsOverride: json['lyricSettingsOverride']
          as Map<String, dynamic>?,
    );
  }

  /// UI 覆盖能力清单
  List<String> get featureTags {
    final tags = <String>[];
    if (hasFullColors) tags.add('完整色板');
    final assetCount = assetFiles?.length ?? 0;
    if (assetCount > 6) tags.add('占位图');
    if (fontFamily != null) tags.add('自定义字体');
    if (shapes != null) tags.add('自定义形状');
    if (playerBgPath != null) tags.add('播放器壁纸');
    if (assetFiles?.containsKey('hi_res_badge') == true) tags.add('Hi-Res 金标');
    if (motion.durationScale != 1.0) tags.add('自定义动效');
    return tags;
  }
}

// ─────────────────────────────────────────────────────────────
//  序列化
// ─────────────────────────────────────────────────────────────

/// 将 ColorScheme 序列化为 {属性名 → '#RRGGBB'} 映射。
Map<String, String> _serializeColorScheme(ColorScheme s) {
  String colorHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  return {
      'primary': colorHex(s.primary),
      'onPrimary': colorHex(s.onPrimary),
      'primaryContainer': colorHex(s.primaryContainer),
      'onPrimaryContainer': colorHex(s.onPrimaryContainer),
      'secondary': colorHex(s.secondary),
      'onSecondary': colorHex(s.onSecondary),
      'secondaryContainer': colorHex(s.secondaryContainer),
      'onSecondaryContainer': colorHex(s.onSecondaryContainer),
      'tertiary': colorHex(s.tertiary),
      'onTertiary': colorHex(s.onTertiary),
      'tertiaryContainer': colorHex(s.tertiaryContainer),
      'onTertiaryContainer': colorHex(s.onTertiaryContainer),
      'error': colorHex(s.error),
      'onError': colorHex(s.onError),
      'errorContainer': colorHex(s.errorContainer),
      'onErrorContainer': colorHex(s.onErrorContainer),
      'surface': colorHex(s.surface),
      'surfaceDim': colorHex(s.surfaceDim),
      'surfaceBright': colorHex(s.surfaceBright),
      'surfaceContainerLowest': colorHex(s.surfaceContainerLowest),
      'surfaceContainerLow': colorHex(s.surfaceContainerLow),
      'surfaceContainer': colorHex(s.surfaceContainer),
      'surfaceContainerHigh': colorHex(s.surfaceContainerHigh),
      'surfaceContainerHighest': colorHex(s.surfaceContainerHighest),
      'onSurface': colorHex(s.onSurface),
      'onSurfaceVariant': colorHex(s.onSurfaceVariant),
      'outline': colorHex(s.outline),
      'outlineVariant': colorHex(s.outlineVariant),
      'inverseSurface': colorHex(s.inverseSurface),
      'inversePrimary': colorHex(s.inversePrimary),
  };
}

/// 从 {属性名 → '#RRGGBB'} 映射反序列化 ColorScheme。
ColorScheme _parseColorScheme(Map<String, dynamic> data, Brightness brightness) {
  Color c(String key, Color fallback) {
    final v = data[key] as String?;
    if (v == null || v.isEmpty) return fallback;
    final h = v.replaceFirst('#', '');
    final val = int.tryParse(h, radix: 16);
    if (val == null) return fallback;
    return Color(0xFF000000 | val);
  }

  if (brightness == Brightness.light) {
    return ColorScheme.light(
      primary: c('primary', const Color(0xFF2CA1F4)),
      onPrimary: c('onPrimary', const Color(0xFFFFFFFF)),
      primaryContainer: c('primaryContainer', const Color(0xFFD2E5FF)),
      onPrimaryContainer: c('onPrimaryContainer', const Color(0xFF001D35)),
      secondary: c('secondary', const Color(0xFF565F71)),
      onSecondary: c('onSecondary', const Color(0xFFFFFFFF)),
      secondaryContainer: c('secondaryContainer', const Color(0xFFDAE2F9)),
      onSecondaryContainer: c('onSecondaryContainer', const Color(0xFF131C2B)),
      tertiary: c('tertiary', const Color(0xFF6E5676)),
      onTertiary: c('onTertiary', const Color(0xFFFFFFFF)),
      tertiaryContainer: c('tertiaryContainer', const Color(0xFFF8D8FE)),
      onTertiaryContainer: c('onTertiaryContainer', const Color(0xFF271430)),
      error: c('error', const Color(0xFFBA1A1A)),
      onError: c('onError', const Color(0xFFFFFFFF)),
      errorContainer: c('errorContainer', const Color(0xFFFFDAD6)),
      onErrorContainer: c('onErrorContainer', const Color(0xFF410002)),
      surface: c('surface', const Color(0xFFFDF8FF)),
      surfaceDim: c('surfaceDim', const Color(0xFFDED8E1)),
      surfaceBright: c('surfaceBright', const Color(0xFFFDF8FF)),
      surfaceContainerLowest: c('surfaceContainerLowest', const Color(0xFFFFFFFF)),
      surfaceContainerLow: c('surfaceContainerLow', const Color(0xFFF7F2FB)),
      surfaceContainer: c('surfaceContainer', const Color(0xFFF2ECF5)),
      surfaceContainerHigh: c('surfaceContainerHigh', const Color(0xFFEBE6EF)),
      surfaceContainerHighest: c('surfaceContainerHighest', const Color(0xFFE0DAE3)),
      onSurface: c('onSurface', const Color(0xFF1C1B1F)),
      onSurfaceVariant: c('onSurfaceVariant', const Color(0xFF49454F)),
      outline: c('outline', const Color(0xFF7A7580)),
      outlineVariant: c('outlineVariant', const Color(0xFFCAC4CD)),
      inverseSurface: c('inverseSurface', const Color(0xFF313033)),
      inversePrimary: c('inversePrimary', const Color(0xFFA9D0FF)),
    );
  } else {
    return ColorScheme.dark(
      primary: c('primary', const Color(0xFFAAC7FF)),
      onPrimary: c('onPrimary', const Color(0xFF003258)),
      primaryContainer: c('primaryContainer', const Color(0xFF00497D)),
      onPrimaryContainer: c('onPrimaryContainer', const Color(0xFFD2E5FF)),
      secondary: c('secondary', const Color(0xFFBEC6DC)),
      onSecondary: c('onSecondary', const Color(0xFF283141)),
      secondaryContainer: c('secondaryContainer', const Color(0xFF3E4759)),
      onSecondaryContainer: c('onSecondaryContainer', const Color(0xFFDAE2F9)),
      tertiary: c('tertiary', const Color(0xFFDBBDE2)),
      onTertiary: c('onTertiary', const Color(0xFF3D2846)),
      tertiaryContainer: c('tertiaryContainer', const Color(0xFF553F5D)),
      onTertiaryContainer: c('onTertiaryContainer', const Color(0xFFF8D8FE)),
      error: c('error', const Color(0xFFFFB4AB)),
      onError: c('onError', const Color(0xFF690005)),
      errorContainer: c('errorContainer', const Color(0xFF93000A)),
      onErrorContainer: c('onErrorContainer', const Color(0xFFFFDAD6)),
      surface: c('surface', const Color(0xFF141318)),
      surfaceDim: c('surfaceDim', const Color(0xFF141318)),
      surfaceBright: c('surfaceBright', const Color(0xFF3A383E)),
      surfaceContainerLowest: c('surfaceContainerLowest', const Color(0xFF0E0E13)),
      surfaceContainerLow: c('surfaceContainerLow', const Color(0xFF1C1B20)),
      surfaceContainer: c('surfaceContainer', const Color(0xFF201F24)),
      surfaceContainerHigh: c('surfaceContainerHigh', const Color(0xFF2B292F)),
      surfaceContainerHighest: c('surfaceContainerHighest', const Color(0xFF36343A)),
      onSurface: c('onSurface', const Color(0xFFE6E1E6)),
      onSurfaceVariant: c('onSurfaceVariant', const Color(0xFFCAC4CD)),
      outline: c('outline', const Color(0xFF948F99)),
      outlineVariant: c('outlineVariant', const Color(0xFF49454F)),
      inverseSurface: c('inverseSurface', const Color(0xFFE6E1E6)),
      inversePrimary: c('inversePrimary', const Color(0xFF00619F)),
    );
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
