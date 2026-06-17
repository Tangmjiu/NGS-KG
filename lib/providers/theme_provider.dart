import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import '../models/theme_pack.dart';
import '../theme/theme_loader.dart';
import '../theme/theme_assets.dart';
import '../utils/theme.dart';

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
}

/// 预设色列表（8 种）
const List<ThemePreset> kThemePresets = [
  ThemePreset(key: 'kugou', label: '酷狗蓝', lightPrimary: Color(0xFF2CA1F4), darkPrimary: Color(0xFF5BB8F8)),
  ThemePreset(key: 'nagisa', label: '凪砂红', lightPrimary: Color(0xFFFF6633), darkPrimary: Color(0xFFFF8866)),
  ThemePreset(key: 'spotify', label: 'Spotify绿', lightPrimary: Color(0xFF1DB954), darkPrimary: Color(0xFF4CD47A)),
  ThemePreset(key: 'purple', label: '优雅紫', lightPrimary: Color(0xFF9C27B0), darkPrimary: Color(0xFFCE93D8)),
  ThemePreset(key: 'orange', label: '暖阳橙', lightPrimary: Color(0xFFFF9800), darkPrimary: Color(0xFFFFB74D)),
  ThemePreset(key: 'pink', label: '樱花粉', lightPrimary: Color(0xFFE91E63), darkPrimary: Color(0xFFF06292)),
  ThemePreset(key: 'cyan', label: '薄荷青', lightPrimary: Color(0xFF00BCD4), darkPrimary: Color(0xFF4DD0E1)),
  ThemePreset(key: 'amber', label: '琥珀金', lightPrimary: Color(0xFFFFC107), darkPrimary: Color(0xFFFFD54F)),
];

/// 主题状态管理
///
/// 管理多主题包列表、选中状态、强调色覆盖、Monet 动态取色。
class ThemeProvider extends ChangeNotifier {
  // ─── SharedPreferences keys ───
  static const _keyThemeMode = 'theme_mode';
  static const _keyAccent = 'theme_accent';
  static const _keyCustomColor = 'theme_custom_color';
  static const _keyUseMonet = 'theme_use_monet';
  static const _keySelectedPack = 'theme_selected_pack';
  static const _keyLaunchCount = 'theme_launch_count';
  static const _keyFirstLaunchDate = 'theme_first_launch_date';
  static const _keySupportDismissed = 'theme_support_dismissed';
  static const _keyFlowLight = 'theme_flow_light';

  static const int supportPopupDays = 14;
  static const int supportPopupMaxLaunches = 10;

  // ─── State ───
  ThemeMode _themeMode = ThemeMode.system;
  String _accentKey = '';
  Color _customColor = const Color(0xFF2CA1F4);
  bool _useMonet = false;
  bool _flowLightEnabled = false;

  final List<ThemePack> _packs = [ngsNagisa, md3Default];
  String _selectedPackId = 'ngs_nagisa';

  int _launchCount = 0;
  int _firstLaunchDate = 0;
  bool _supportDismissed = false;

  // ─── 支持弹窗 ───
  bool get shouldShowSupportPopup {
    if (_supportDismissed) return false;
    if (_launchCount > supportPopupMaxLaunches) return false;
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
  bool get flowLightEnabled => _flowLightEnabled;

  List<ThemePack> get packs => List.unmodifiable(_packs);
  String get selectedPackId => _selectedPackId;

  /// 当前选中的主题包
  ThemePack get currentPack {
    return _packs.firstWhere(
      (p) => p.id == _selectedPackId,
      orElse: () => ngsNagisa,
    );
  }

  /// 当前有效强调色（预设色或自定义色）
  Color get effectiveColor {
    if (_accentKey == 'custom') return _customColor;
    final preset = kThemePresets.where((p) => p.key == _accentKey);
    return preset.isNotEmpty ? preset.first.lightPrimary : _customColor;
  }

  /// 当前强调色显示名称
  String get accentLabel {
    if (_accentKey == 'custom') return '自定义';
    final preset = kThemePresets.where((p) => p.key == _accentKey);
    return preset.isNotEmpty ? preset.first.label : '无覆盖';
  }

  /// 是否有强调色覆盖（空 key 表示无覆盖，用主题包的颜色）
  bool get hasAccentOverride => _accentKey.isNotEmpty;

  // ─── 初始化 ───

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final modeIdx = prefs.getInt(_keyThemeMode);
      if (modeIdx != null) {
        _themeMode = ThemeMode.values[modeIdx.clamp(0, ThemeMode.values.length - 1)];
      }

      _accentKey = prefs.getString(_keyAccent) ?? '';

      final customColorInt = prefs.getInt(_keyCustomColor);
      if (customColorInt != null) {
        _customColor = Color(customColorInt);
      }

      _useMonet = prefs.getBool(_keyUseMonet) ?? false;
      _selectedPackId = prefs.getString(_keySelectedPack) ?? 'ngs_nagisa';
      _flowLightEnabled = prefs.getBool(_keyFlowLight) ?? false;

      // 确保选中包存在于列表中
      if (!_packs.any((p) => p.id == _selectedPackId)) {
        _selectedPackId = 'ngs_nagisa';
      }

      // ─── 加载自定义字体 ───
      unawaited(_loadFontsForPack(currentPack));

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

  // ─── 主题包管理 ───

  /// 切换到指定主题包
  Future<void> selectPack(String packId) async {
    if (_selectedPackId == packId) return;
    if (!_packs.any((p) => p.id == packId)) return;
    _selectedPackId = packId;
    _applyPackAssets();
    await _loadFontsForPack(currentPack);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySelectedPack, packId);
    } catch (e, s) {
      Log.e('ThemeProvider', 'persist selectedPack error', e, s);
    }
  }

  /// 从 ZIP 导入主题包
  Future<bool> importTheme() async {
    final pack = await ThemeLoader.importFromPicker();
    if (pack == null) return false;
    _packs.add(pack);
    _selectedPackId = pack.id;
    _applyPackAssets();
    notifyListeners();
    return true;
  }

  /// 添加已下载的主题包（市场安装用，不自动选中）
  void addMarketPack(ThemePack pack) {
    _packs.add(pack);
    notifyListeners();
  }

  /// 删除导入的主题包
  Future<void> deletePack(String packId) async {
    final pack = _packs.firstWhere(
      (p) => p.id == packId,
      orElse: () => ngsNagisa,
    );
    if (pack.isBuiltIn) return; // 不能删内置包
    await ThemeLoader.deleteTheme(packId);
    _packs.removeWhere((p) => p.id == packId);
    if (_selectedPackId == packId) {
      _selectedPackId = 'ngs_nagisa';
      _applyPackAssets();
    }
    notifyListeners();
  }

  /// 把当前主题包的资源加载到 ThemeAssets
  void _applyPackAssets() {
    final pack = currentPack;
    if (pack.assetFiles != null && pack.assetFiles!.isNotEmpty) {
      ThemeAssets.loadFromThemePack(pack);
    } else {
      ThemeAssets.resetToDefault();
    }
  }

  /// 加载主题包的自定义字体
  Future<void> _loadFontsForPack(ThemePack pack) async {
    final weightFiles = pack.fontWeightFiles;
    final family = pack.fontFamily;
    if (weightFiles == null || family == null) return;

    Future<void> _loadWeight(String path) async {
      if (path.isEmpty) return;
      final file = File(path);
      if (!file.existsSync()) return;
      final bytes = await file.readAsBytes();
      await ui.loadFontFromList(Uint8List.fromList(bytes), fontFamily: family);
    }

    try {
      await Future.wait([
        _loadWeight(weightFiles.regular),
        if (weightFiles.medium != null) _loadWeight(weightFiles.medium!),
        if (weightFiles.bold != null) _loadWeight(weightFiles.bold!),
      ]);
      Log.i('ThemeProvider', 'Font "$family" loaded');
    } catch (e, s) {
      Log.e('ThemeProvider', 'Failed to load font "$family"', e, s);
    }
  }

  Future<void> dismissSupportPopup() async {
    _supportDismissed = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keySupportDismissed, true);
    } catch (e, s) {
      Log.e('ThemeProvider', 'dismissSupport error', e, s);
    }
  }

  // ─── Setters ───

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

  /// 设置强调色覆盖（空 key = 清除覆盖）
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

  /// 清除强调色覆盖，恢复主题包内置颜色
  Future<void> clearAccentOverride() async {
    _accentKey = '';
    _useMonet = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAccent, '');
      await prefs.setBool(_keyUseMonet, false);
    } catch (e, s) {
      Log.e('ThemeProvider', 'persist clearAccent error', e, s);
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
    if (!v) {
      _accentKey = '';
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyUseMonet, v);
      if (!v) await prefs.setString(_keyAccent, '');
    } catch (e, s) {
      Log.e('ThemeProvider', 'persist monet error', e, s);
    }
  }

  Future<void> setFlowLightEnabled(bool v) async {
    _flowLightEnabled = v;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyFlowLight, v);
    } catch (e, s) {
      Log.e('ThemeProvider', 'persist flowLight error', e, s);
    }
  }

  // ─── 构建 ThemeData ───

  /// 解析当前有效 ColorScheme
  ColorScheme _resolveScheme(Brightness brightness, {ColorScheme? dynamicScheme}) {
    // 1. Monet 优先
    if (_useMonet) {
      if (dynamicScheme != null) return dynamicScheme;
      return ColorScheme.fromSeed(
        seedColor: const Color(0xFF2CA1F4),
        brightness: brightness,
      );
    }

    // 2. 强调色覆盖
    if (hasAccentOverride) {
      return ColorScheme.fromSeed(
        seedColor: effectiveColor,
        brightness: brightness,
      );
    }

    // 3. 主题包内置色板
    final pack = currentPack;
    if (brightness == Brightness.light) {
      if (pack.lightScheme != null) return pack.lightScheme!;
    } else {
      if (pack.darkScheme != null) return pack.darkScheme!;
    }

    // 4. 默认回退
    return ColorScheme.fromSeed(
      seedColor: const Color(0xFF2CA1F4),
      brightness: brightness,
    );
  }

  ThemeData buildLightTheme(BuildContext context, {ColorScheme? dynamicScheme}) {
    final scheme = _resolveScheme(Brightness.light, dynamicScheme: dynamicScheme);
    return buildThemeData(scheme, currentPack, hasGlobalBg: currentPack.playerBgPath != null);
  }

  ThemeData buildDarkTheme(BuildContext context, {ColorScheme? dynamicScheme}) {
    final scheme = _resolveScheme(Brightness.dark, dynamicScheme: dynamicScheme);
    return buildThemeData(scheme, currentPack, hasGlobalBg: currentPack.playerBgPath != null);
  }
}
