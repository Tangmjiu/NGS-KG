// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../theme/app_theme_tokens.dart';
import '../theme/theme_manifest_adapter.dart';

Map<String, dynamic> _map(Object? value) => ThemeManifestAdapter.map(value);
String? _string(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
double _number(Object? value, double fallback, double min, double max) =>
    value is num && value.isFinite
        ? value.toDouble().clamp(min, max)
        : fallback;

@immutable
class ThemeMotion {
  final double durationScale;
  final String curve;
  const ThemeMotion({this.durationScale = 1, this.curve = 'emphasized'});
  static const defaults = ThemeMotion();
  Curve get resolvedCurve => switch (curve) {
        'standard' => const Cubic(0.2, 0, 0, 1),
        'linear' => Curves.linear,
        _ => Curves.easeInOutCubicEmphasized,
      };
  Duration scale(Duration duration) =>
      Duration(milliseconds: (duration.inMilliseconds * durationScale).round());
  factory ThemeMotion.fromJson(Map<String, dynamic> json) => ThemeMotion(
        durationScale: _number(json['durationScale'], 1, 0.5, 2),
        curve:
            const ['standard', 'linear', 'emphasized'].contains(json['curve'])
                ? json['curve'] as String
                : 'emphasized',
      );
  Map<String, dynamic> toJson() =>
      {'durationScale': durationScale, 'curve': curve};
}

@immutable
class ThemeComponents {
  final double navigationBarElevation;
  final double cardElevation;
  final double dialogElevation;
  const ThemeComponents(
      {this.navigationBarElevation = 0,
      this.cardElevation = 0,
      this.dialogElevation = 0});
  static const defaults = ThemeComponents();
  factory ThemeComponents.fromJson(Map<String, dynamic> json) =>
      ThemeComponents(
        navigationBarElevation:
            _number(json['navigationBarElevation'], 0, 0, 24),
        cardElevation: _number(json['cardElevation'], 0, 0, 24),
        dialogElevation: _number(json['dialogElevation'], 0, 0, 24),
      );
  Map<String, dynamic> toJson() => {
        'navigationBarElevation': navigationBarElevation,
        'cardElevation': cardElevation,
        'dialogElevation': dialogElevation,
      };
}

@immutable
class FontWeightFiles {
  final String regular;
  final String? medium;
  final String? bold;
  const FontWeightFiles({required this.regular, this.medium, this.bold});
  Map<String, dynamic> toJson() => {
        'regular': regular,
        'medium': medium,
        'bold': bold,
      };
  static FontWeightFiles fromJson(Map<String, dynamic> json) => FontWeightFiles(
        regular: _string(json['regular']) ?? '',
        medium: _string(json['medium']),
        bold: _string(json['bold']),
      );
}

/// 安装后统一使用的主题模型；旧清单仅在解析边界做字段迁移。
@immutable
class ThemePack {
  final String id;
  final String name;
  final String author;
  final int version;
  final String? description;
  final bool isBuiltIn;
  final String? previewPath;
  final ColorScheme? lightScheme;
  final ColorScheme? darkScheme;
  final String? fontFamily;
  final FontWeightFiles? fontWeightFiles;
  final Map<String, double>? shapes;
  final ThemeMotion motion;
  final ThemeComponents components;
  final Map<String, String>? assetFiles;
  final String? playerBgPath;
  final Map<String, dynamic>? lyricSettingsOverride;
  final AppThemeTokens? tokens;

  const ThemePack({
    required this.id,
    required this.name,
    required this.author,
    this.version = 3,
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
    this.tokens,
  });

  bool get hasFullColors => lightScheme != null || darkScheme != null;

  factory ThemePack.fromJson(Map<String, dynamic> source) {
    final json = ThemeManifestAdapter.normalize(source);
    final shapeMap = _map(json['shapes']);
    final shapes = <String, double>{
      for (final entry in shapeMap.entries)
        if (entry.value is num && (entry.value as num).isFinite)
          entry.key: _number(entry.value, 0, 0, 64),
    };
    final assets = <String, String>{
      for (final entry in _map(json['assetFiles']).entries)
        if (_string(entry.value) != null) entry.key: entry.value as String,
    };
    final lyrics = _map(json['lyricSettingsOverride']);
    final fonts = _map(json['fontWeightFiles']);
    return ThemePack(
      id: _string(json['id']) ?? '',
      name: _string(json['name']) ?? '未命名主题',
      author: _string(json['author']) ?? '未知作者',
      version: json['version'] is int ? json['version'] as int : 1,
      description: _string(json['description']),
      isBuiltIn: json['isBuiltIn'] == true,
      previewPath: _string(json['previewPath']),
      lightScheme:
          parseThemeColors(_map(json['lightScheme']), Brightness.light),
      darkScheme: parseThemeColors(_map(json['darkScheme']), Brightness.dark),
      fontFamily: _string(json['fontFamily']),
      fontWeightFiles: fonts.isEmpty ? null : FontWeightFiles.fromJson(fonts),
      shapes: shapes.isEmpty ? null : Map.unmodifiable(shapes),
      motion: ThemeMotion.fromJson(_map(json['motion'])),
      components: ThemeComponents.fromJson(_map(json['components'])),
      assetFiles: assets.isEmpty ? null : Map.unmodifiable(assets),
      playerBgPath: _string(json['playerBgPath']),
      lyricSettingsOverride: lyrics.isEmpty
          ? null
          : Map.unmodifiable({
              if (lyrics['fontSize'] is num)
                'fontSize': _number(lyrics['fontSize'], 16, 12, 28),
              if (lyrics['fontWeight'] is num)
                'fontWeight': _number(lyrics['fontWeight'], 400, 100, 900),
              if (lyrics['centerAlign'] is bool)
                'centerAlign': lyrics['centerAlign'],
              if (lyrics['blurEffect'] is bool)
                'blurEffect': lyrics['blurEffect'],
            }),
      tokens: AppThemeTokens.fromJson(_map(json['design'])),
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': 3,
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
        'shapes': shapes,
        'motion': motion.toJson(),
        'components': components.toJson(),
        'design': (tokens ?? AppThemeTokens.defaults).toJson(),
        if (lightScheme != null)
          'lightScheme': serializeThemeColors(lightScheme!),
        if (darkScheme != null) 'darkScheme': serializeThemeColors(darkScheme!),
        if (lyricSettingsOverride != null)
          'lyricSettingsOverride': lyricSettingsOverride,
      };

  List<String> get featureTags => [
        if (hasFullColors) '完整色板',
        if ((assetFiles?.length ?? 0) > 6) '占位图',
        if (fontFamily != null) '自定义字体',
        if (shapes != null) '自定义形状',
        if (playerBgPath != null) '播放器壁纸',
        if (assetFiles?.containsKey('hi_res_badge') == true) 'Hi-Res 金标',
        if (motion.durationScale != 1) '自定义动效',
      ];
}

Color? _parseColor(Object? value) {
  if (value is! String) return null;
  final hex = value.replaceFirst('#', '');
  if (!RegExp(r'^(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(hex)) {
    return null;
  }
  final number = int.parse(hex, radix: 16);
  return Color(hex.length == 6 ? 0xff000000 | number : number);
}

ColorScheme? parseThemeColors(
    Map<String, dynamic> colors, Brightness brightness) {
  if (colors.isEmpty) return null;
  final base = ColorScheme.fromSeed(
    seedColor: _parseColor(colors['primary']) ?? const Color(0xFF2CA1F4),
    brightness: brightness,
  );
  return base.copyWith(
    primary: _parseColor(colors['primary']),
    onPrimary: _parseColor(colors['onPrimary']),
    primaryContainer: _parseColor(colors['primaryContainer']),
    onPrimaryContainer: _parseColor(colors['onPrimaryContainer']),
    primaryFixed: _parseColor(colors['primaryFixed']),
    primaryFixedDim: _parseColor(colors['primaryFixedDim']),
    onPrimaryFixed: _parseColor(colors['onPrimaryFixed']),
    onPrimaryFixedVariant: _parseColor(colors['onPrimaryFixedVariant']),
    secondary: _parseColor(colors['secondary']),
    onSecondary: _parseColor(colors['onSecondary']),
    secondaryContainer: _parseColor(colors['secondaryContainer']),
    onSecondaryContainer: _parseColor(colors['onSecondaryContainer']),
    secondaryFixed: _parseColor(colors['secondaryFixed']),
    secondaryFixedDim: _parseColor(colors['secondaryFixedDim']),
    onSecondaryFixed: _parseColor(colors['onSecondaryFixed']),
    onSecondaryFixedVariant: _parseColor(colors['onSecondaryFixedVariant']),
    tertiary: _parseColor(colors['tertiary']),
    onTertiary: _parseColor(colors['onTertiary']),
    tertiaryContainer: _parseColor(colors['tertiaryContainer']),
    onTertiaryContainer: _parseColor(colors['onTertiaryContainer']),
    tertiaryFixed: _parseColor(colors['tertiaryFixed']),
    tertiaryFixedDim: _parseColor(colors['tertiaryFixedDim']),
    onTertiaryFixed: _parseColor(colors['onTertiaryFixed']),
    onTertiaryFixedVariant: _parseColor(colors['onTertiaryFixedVariant']),
    error: _parseColor(colors['error']),
    onError: _parseColor(colors['onError']),
    errorContainer: _parseColor(colors['errorContainer']),
    onErrorContainer: _parseColor(colors['onErrorContainer']),
    surface: _parseColor(colors['surface']),
    surfaceDim: _parseColor(colors['surfaceDim']),
    surfaceBright: _parseColor(colors['surfaceBright']),
    surfaceContainerLowest: _parseColor(colors['surfaceContainerLowest']),
    surfaceContainerLow: _parseColor(colors['surfaceContainerLow']),
    surfaceContainer: _parseColor(colors['surfaceContainer']),
    surfaceContainerHigh: _parseColor(colors['surfaceContainerHigh']),
    surfaceContainerHighest: _parseColor(colors['surfaceContainerHighest']),
    onSurface: _parseColor(colors['onSurface']),
    onSurfaceVariant: _parseColor(colors['onSurfaceVariant']),
    outline: _parseColor(colors['outline']),
    outlineVariant: _parseColor(colors['outlineVariant']),
    shadow: _parseColor(colors['shadow']),
    scrim: _parseColor(colors['scrim']),
    inverseSurface: _parseColor(colors['inverseSurface']),
    onInverseSurface: _parseColor(colors['onInverseSurface']),
    inversePrimary: _parseColor(colors['inversePrimary']),
    surfaceTint: _parseColor(colors['surfaceTint']),
  );
}

Map<String, String> serializeThemeColors(ColorScheme colors) {
  String hex(Color color) {
    final value =
        color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();
    return '#${value.startsWith('FF') ? value.substring(2) : value}';
  }

  return {
    'primary': hex(colors.primary),
    'onPrimary': hex(colors.onPrimary),
    'primaryContainer': hex(colors.primaryContainer),
    'onPrimaryContainer': hex(colors.onPrimaryContainer),
    'primaryFixed': hex(colors.primaryFixed),
    'primaryFixedDim': hex(colors.primaryFixedDim),
    'onPrimaryFixed': hex(colors.onPrimaryFixed),
    'onPrimaryFixedVariant': hex(colors.onPrimaryFixedVariant),
    'secondary': hex(colors.secondary),
    'onSecondary': hex(colors.onSecondary),
    'secondaryContainer': hex(colors.secondaryContainer),
    'onSecondaryContainer': hex(colors.onSecondaryContainer),
    'secondaryFixed': hex(colors.secondaryFixed),
    'secondaryFixedDim': hex(colors.secondaryFixedDim),
    'onSecondaryFixed': hex(colors.onSecondaryFixed),
    'onSecondaryFixedVariant': hex(colors.onSecondaryFixedVariant),
    'tertiary': hex(colors.tertiary),
    'onTertiary': hex(colors.onTertiary),
    'tertiaryContainer': hex(colors.tertiaryContainer),
    'onTertiaryContainer': hex(colors.onTertiaryContainer),
    'tertiaryFixed': hex(colors.tertiaryFixed),
    'tertiaryFixedDim': hex(colors.tertiaryFixedDim),
    'onTertiaryFixed': hex(colors.onTertiaryFixed),
    'onTertiaryFixedVariant': hex(colors.onTertiaryFixedVariant),
    'error': hex(colors.error),
    'onError': hex(colors.onError),
    'errorContainer': hex(colors.errorContainer),
    'onErrorContainer': hex(colors.onErrorContainer),
    'surface': hex(colors.surface),
    'surfaceDim': hex(colors.surfaceDim),
    'surfaceBright': hex(colors.surfaceBright),
    'surfaceContainerLowest': hex(colors.surfaceContainerLowest),
    'surfaceContainerLow': hex(colors.surfaceContainerLow),
    'surfaceContainer': hex(colors.surfaceContainer),
    'surfaceContainerHigh': hex(colors.surfaceContainerHigh),
    'surfaceContainerHighest': hex(colors.surfaceContainerHighest),
    'onSurface': hex(colors.onSurface),
    'onSurfaceVariant': hex(colors.onSurfaceVariant),
    'outline': hex(colors.outline),
    'outlineVariant': hex(colors.outlineVariant),
    'shadow': hex(colors.shadow),
    'scrim': hex(colors.scrim),
    'inverseSurface': hex(colors.inverseSurface),
    'onInverseSurface': hex(colors.onInverseSurface),
    'inversePrimary': hex(colors.inversePrimary),
    'surfaceTint': hex(colors.surfaceTint),
  };
}

/// NGS 凪砂 — 默认主题
const ThemePack ngsNagisa = ThemePack(
  id: 'ngs_nagisa',
  name: 'Ran Nagisa',
  author: 'mjiutang',
  version: 3,
  isBuiltIn: true,
  description: 'Welcome to Garden of Eden',
  tokens: AppThemeTokens.defaults,
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
