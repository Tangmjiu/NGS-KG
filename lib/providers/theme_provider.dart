import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import '../utils/logger.dart';
import '../theme/theme_loader.dart';
import '../theme/theme_assets.dart';

/// 预设主题色定义
class ThemePreset {
  final String key;
  final String label;
  final Color lightPrimary;
  final Color darkPrimary;

  const ThemePreset({
    required this.key,
    required this.label,
    required this.lightPrimary,
    required this.darkPrimary,
  });

  /// 生成适应亮色的 FlexSchemeColor
  FlexSchemeColor get schemeColor => FlexSchemeColor.from(
        primary: lightPrimary,
        brightness: Brightness.light,
      );

  /// 生成适应暗色的 FlexSchemeColor
  FlexSchemeColor get darkSchemeColor => FlexSchemeColor.from(
        primary: darkPrimary,
        brightness: Brightness.dark,
      );
}

/// 预设色列表（8 种）
const List<ThemePreset> kThemePresets = [
  ThemePreset(
    key: 'kugou',
    label: '酷狗蓝',
    lightPrimary: Color(0xFF2CA1F4),
    darkPrimary: Color(0xFF5BB8F8),
  ),
  ThemePreset(
    key: 'nagisa',
    label: '凪砂红',
    lightPrimary: Color(0xFFFF6633),
    darkPrimary: Color(0xFFFF8866),
  ),
  ThemePreset(
    key: 'spotify',
    label: 'Spotify绿',
    lightPrimary: Color(0xFF1DB954),
    darkPrimary: Color(0xFF4CD47A),
  ),
  ThemePreset(
    key: 'purple',
    label: '优雅紫',
    lightPrimary: Color(0xFF9C27B0),
    darkPrimary: Color(0xFFCE93D8),
  ),
  ThemePreset(
    key: 'orange',
    label: '暖阳橙',
    lightPrimary: Color(0xFFFF9800),
    darkPrimary: Color(0xFFFFB74D),
  ),
  ThemePreset(
    key: 'pink',
    label: '樱花粉',
    lightPrimary: Color(0xFFE91E63),
    darkPrimary: Color(0xFFF06292),
  ),
  ThemePreset(
    key: 'cyan',
    label: '薄荷青',
    lightPrimary: Color(0xFF00BCD4),
    darkPrimary: Color(0xFF4DD0E1),
  ),
  ThemePreset(
    key: 'amber',
    label: '琥珀金',
    lightPrimary: Color(0xFFFFC107),
    darkPrimary: Color(0xFFFFD54F),
  ),
];

/// 主题状态管理
///
/// 管理 ThemeMode、强调色、自定义颜色、Monet 动态取色，
/// 所有设置持久化到 SharedPreferences。
class ThemeProvider extends ChangeNotifier {
  // ─── SharedPreferences keys ───
  static const _keyThemeMode = 'theme_mode';
  static const _keyAccent = 'theme_accent';
  static const _keyCustomColor = 'theme_custom_color';
  static const _keyUseMonet = 'theme_use_monet';
  static const _keyLaunchCount = 'theme_launch_count';
  static const _keyFirstLaunchDate = 'theme_first_launch_date';
  static const _keySupportDismissed = 'theme_support_dismissed';

  /// 安装后自动弹出支持弹窗的天数
  static const int supportPopupDays = 14;
  /// 安装后自动弹出支持弹窗的最大次数
  static const int supportPopupMaxLaunches = 10;

  // ─── State ───
  ThemeMode _themeMode = ThemeMode.dark;
  String _accentKey = 'kugou';
  Color _customColor = const Color(0xFF2CA1F4);
  bool _useMonet = false;
  LoadedTheme? _loadedTheme;
  int _launchCount = 0;
  int _firstLaunchDate = 0;
  bool _supportDismissed = false;

  /// 本次启动是否应该弹出支持弹窗
  bool get shouldShowSupportPopup {
    if (_supportDismissed) return false;
    if (_launchCount > supportPopupMaxLaunches) return false;

    // 安装后超过 supportPopupDays 天不再自动弹
    if (_firstLaunchDate > 0) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - _firstLaunchDate;
      if (elapsed > supportPopupDays * 24 * 60 * 60 * 1000) return false;
    }

    return _launchCount <= supportPopupMaxLaunches;
  }

  // ─── Getters ───
  ThemeMode get themeMode => _themeMode;
  String get accentKey => _accentKey;
  Color get customColor => _customColor;
  bool get useMonet => _useMonet;

  /// 当前有效强调色（预设色或自定义色）
  Color get effectiveColor {
    if (_accentKey == 'custom') return _customColor;
    final preset = kThemePresets.where((p) => p.key == _accentKey);
    return preset.isNotEmpty ? preset.first.lightPrimary : _customColor;
  }

  /// 当前预设对象（自定义模式返回 null）
  ThemePreset? get currentPreset {
    if (_accentKey == 'custom') return null;
    return kThemePresets.where((p) => p.key == _accentKey).firstOrNull;
  }

  /// 当前强调色显示名称
  String get accentLabel {
    if (_loadedTheme != null) return '主题包: ${_loadedTheme!.name}';
    if (_accentKey == 'custom') return '自定义';
    final preset = kThemePresets.where((p) => p.key == _accentKey);
    return preset.isNotEmpty ? preset.first.label : '自定义';
  }

  // ─── 初始化 ───

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final modeIdx = prefs.getInt(_keyThemeMode) ?? 1;
      _themeMode =
          ThemeMode.values[modeIdx.clamp(0, ThemeMode.values.length - 1)];

      _accentKey = prefs.getString(_keyAccent) ?? 'kugou';

      final customColorInt = prefs.getInt(_keyCustomColor);
      if (customColorInt != null) {
        _customColor = Color(customColorInt);
      }

      _useMonet = prefs.getBool(_keyUseMonet) ?? false;

      // ─── 启动计数 & 支持弹窗 ───
      _launchCount = prefs.getInt(_keyLaunchCount) ?? 0;
      _launchCount++;
      await prefs.setInt(_keyLaunchCount, _launchCount);

      _firstLaunchDate = prefs.getInt(_keyFirstLaunchDate) ?? 0;
      if (_firstLaunchDate == 0) {
        _firstLaunchDate = DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt(_keyFirstLaunchDate, _firstLaunchDate);
      }

      _supportDismissed = prefs.getBool(_keySupportDismissed) ?? false;

      notifyListeners();
    } catch (e, s) {
      Log.e('ThemeProvider', 'init error', e, s);
    }
  }

  // ─── ZIP 主题包管理 ───

  /// 当前已加载的主题包（null = 使用默认主题）
  LoadedTheme? get loadedTheme => _loadedTheme;

  /// 从 ZIP 文件导入主题包
  Future<bool> importTheme() async {
    final theme = await ThemeLoader.importFromPicker();
    if (theme == null) return false;

    _loadedTheme = theme;

    // 替换资源路径
    if (theme.assetFiles.isNotEmpty) {
      ThemeAssets.loadFromTheme(theme.assetFiles);
    }

    // 使用主题包的颜色作为当前强调色
    _accentKey = 'custom';
    _customColor = theme.lightPrimary;
    _useMonet = false;

    notifyListeners();
    return true;
  }

  /// 移除已导入的主题包，恢复默认
  Future<void> removeTheme() async {
    if (_loadedTheme != null) {
      await ThemeLoader.deleteTheme(_loadedTheme!.id);
    }
    _loadedTheme = null;
    ThemeAssets.resetToDefault();
    _accentKey = 'kugou';
    notifyListeners();
  }

  /// 标记支持弹窗已关闭（永久不再自动弹出）
  Future<void> dismissSupportPopup() async {
    _supportDismissed = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keySupportDismissed, true);
    } catch (e, s) {
      Log.e('ThemeProvider', 'dismissSupport error', e, s);
    }
  }

  // ─── Setters（自动持久化） ───

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyThemeMode, mode.index);
    } catch (e, s) {
      Log.e('ThemeProvider', 'persist themeMode error', e, s);
    }
  }

  Future<void> setAccent(String key) async {
    _accentKey = key;
    _useMonet = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAccent, key);
      await prefs.setBool(_keyUseMonet, false);
    } catch (e, s) {
      Log.e('ThemeProvider', 'persist accent error', e, s);
    }
  }

  Future<void> setCustomColor(Color color) async {
    _accentKey = 'custom';
    _customColor = color;
    _useMonet = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAccent, 'custom');
      await prefs.setInt(_keyCustomColor, color.toARGB32());
      await prefs.setBool(_keyUseMonet, false);
    } catch (e, s) {
      Log.e('ThemeProvider', 'persist customColor error', e, s);
    }
  }

  Future<void> setUseMonet(bool v) async {
    _useMonet = v;
    if (v) {
      _accentKey = 'monet';
    } else {
      _accentKey = 'kugou';
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyUseMonet, v);
      await prefs.setString(_keyAccent, _accentKey);
    } catch (e, s) {
      Log.e('ThemeProvider', 'persist monet error', e, s);
    }
  }

  // ─── 构建 ThemeData ───

  /// 共享的 subThemesData 配置
  static const _subThemesData = FlexSubThemesData(
    defaultRadius: 12,
    inputDecoratorRadius: 8,
    dialogRadius: 16,
    navigationBarOpacity: 0.2,
    navigationBarIndicatorOpacity: 0.2,
  );

  /// 构建浅色主题
  ///
  /// [dynamicScheme] 由 main.dart 的 DynamicColorBuilder 提供
  /// （Android 12+ 壁纸动态色），仅 _useMonet=true 时生效。
  ThemeData buildLightTheme(BuildContext context, {ColorScheme? dynamicScheme}) {
    // Monet 动态取色
    if (_useMonet) {
      return FlexThemeData.light(
        colorScheme: _monetScheme(Brightness.light, dynamicScheme: dynamicScheme),
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 20,
        appBarElevation: 0,
        subThemesData: _subThemesData,
      );
    }

    final preset = currentPreset;
    if (preset != null) {
      return FlexThemeData.light(
        colors: preset.schemeColor,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 20,
        appBarElevation: 0,
        subThemesData: _subThemesData,
      );
    }

    // 自定义色
    return FlexThemeData.light(
      colors: FlexSchemeColor.from(primary: _customColor, brightness: Brightness.light),
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 20,
      appBarElevation: 0,
      subThemesData: _subThemesData,
    );
  }

  /// 构建深色主题
  ///
  /// [dynamicScheme] 由 main.dart 的 DynamicColorBuilder 提供
  /// （Android 12+ 壁纸动态色），仅 _useMonet=true 时生效。
  ThemeData buildDarkTheme(BuildContext context, {ColorScheme? dynamicScheme}) {
    if (_useMonet) {
      return FlexThemeData.dark(
        colorScheme: _monetScheme(Brightness.dark, dynamicScheme: dynamicScheme),
        surfaceMode: FlexSurfaceMode.highScaffoldLowSurfaces,
        blendLevel: 15,
        appBarElevation: 0,
        subThemesData: _subThemesData,
      );
    }

    final preset = currentPreset;
    if (preset != null) {
      return FlexThemeData.dark(
        colors: preset.darkSchemeColor,
        surfaceMode: FlexSurfaceMode.highScaffoldLowSurfaces,
        blendLevel: 15,
        appBarElevation: 0,
        subThemesData: _subThemesData,
      );
    }

    // 自定义色
    return FlexThemeData.dark(
      colors: FlexSchemeColor.from(primary: _customColor, brightness: Brightness.dark),
      surfaceMode: FlexSurfaceMode.highScaffoldLowSurfaces,
      blendLevel: 15,
      appBarElevation: 0,
      subThemesData: _subThemesData,
    );
  }

  // ─── Monet 动态取色 ───

  /// 获取 Android 12+ 动态色方案
  ///
  /// 优先使用 [dynamic_color] 包提供的系统壁纸色，
  /// 回退到 ColorScheme.fromSeed 用预设色生成。
  ColorScheme _monetScheme(Brightness brightness, {ColorScheme? dynamicScheme}) {
    if (dynamicScheme != null) return dynamicScheme;
    return ColorScheme.fromSeed(
      seedColor: const Color(0xFF2CA1F4),
      brightness: brightness,
    );
  }
}
