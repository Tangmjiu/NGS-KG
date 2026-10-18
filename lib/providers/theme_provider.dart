// SPDX-License-Identifier: MIT
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/lyric_settings.dart';
import '../models/theme_pack.dart';
import '../services/market_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_assets.dart';
import '../theme/theme_loader.dart';
import '../theme/theme_settings_store.dart';
import '../utils/logger.dart';

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
  ThemePreset(
      key: 'kugou',
      label: '酷狗蓝',
      lightPrimary: Color(0xFF2CA1F4),
      darkPrimary: Color(0xFF5BB8F8)),
  ThemePreset(
      key: 'nagisa',
      label: '凪砂红',
      lightPrimary: Color(0xFFFF6633),
      darkPrimary: Color(0xFFFF8866)),
  ThemePreset(
      key: 'spotify',
      label: '森林绿',
      lightPrimary: Color(0xFF1DB954),
      darkPrimary: Color(0xFF4CD47A)),
  ThemePreset(
      key: 'purple',
      label: '优雅紫',
      lightPrimary: Color(0xFF9C27B0),
      darkPrimary: Color(0xFFCE93D8)),
  ThemePreset(
      key: 'orange',
      label: '暖阳橙',
      lightPrimary: Color(0xFFFF9800),
      darkPrimary: Color(0xFFFFB74D)),
  ThemePreset(
      key: 'pink',
      label: '樱花粉',
      lightPrimary: Color(0xFFE91E63),
      darkPrimary: Color(0xFFF06292)),
  ThemePreset(
      key: 'cyan',
      label: '薄荷青',
      lightPrimary: Color(0xFF00BCD4),
      darkPrimary: Color(0xFF4DD0E1)),
  ThemePreset(
      key: 'amber',
      label: '琥珀金',
      lightPrimary: Color(0xFFFFC107),
      darkPrimary: Color(0xFFFFD54F)),
];

/// 负责主题选择与解析；持久化及历史格式迁移由独立存储层完成。
class ThemeProvider extends ChangeNotifier {
  ThemeProvider({
    ThemeSettingsStore? settingsStore,
    Future<void> Function(String)? deleteTheme,
    Future<void> Function(String)? uninstallMarketTheme,
  })  : _store = settingsStore ?? ThemeSettingsStore(),
        _deleteTheme = deleteTheme ?? ThemeLoader.deleteTheme,
        _uninstallMarketTheme =
            uninstallMarketTheme ?? MarketService.uninstallTheme;

  final ThemeSettingsStore _store;
  final Future<void> Function(String) _deleteTheme;
  final Future<void> Function(String) _uninstallMarketTheme;
  ThemeSettings _settings = const ThemeSettings();
  final List<ThemePack> _packs = [ngsNagisa, md3Default];
  Future<void> _pendingSave = Future.value();
  final Set<String> _loadedFonts = {};
  int _activation = 0;
  bool _disposed = false;
  bool _hasValidBg = false;
  static const int supportPopupDays = 14;
  static const int supportPopupMaxLaunches = 10;

  ThemeMode get themeMode => _settings.mode;
  String get accentKey => _settings.accentKey;
  Color get customColor => _settings.customColor;
  bool get useMonet => _settings.useMonet;
  bool get flowLightEnabled => _settings.flowLight;
  bool get showHiResBadge => _settings.showHiResBadge;
  String get selectedPackId => _settings.selectedPackId;
  List<ThemePack> get packs => List.unmodifiable(_packs);
  ThemePack get currentPack => _packs
      .firstWhere((pack) => pack.id == selectedPackId, orElse: () => ngsNagisa);
  bool get hasAccentOverride => accentKey.isNotEmpty;
  Color get effectiveColor => accentKey == 'custom'
      ? customColor
      : kThemePresets
              .where((preset) => preset.key == accentKey)
              .firstOrNull
              ?.lightPrimary ??
          customColor;
  String get accentLabel => accentKey == 'custom'
      ? '自定义'
      : kThemePresets
              .where((preset) => preset.key == accentKey)
              .firstOrNull
              ?.label ??
          '无覆盖';
  LyricSettings get lyricSettings =>
      _settings.lyricOverride ??
      LyricSettings.fromJson({
        ...LyricSettings.defaults.toJson(),
        ...?currentPack.lyricSettingsOverride,
      });
  bool get shouldShowSupportPopup =>
      !_settings.supportDismissed &&
      _settings.launchCount <= supportPopupMaxLaunches &&
      (_settings.firstLaunchDate == 0 ||
          DateTime.now().millisecondsSinceEpoch - _settings.firstLaunchDate <=
              supportPopupDays * Duration.millisecondsPerDay);

  Future<void> init() async {
    try {
      _settings = await _store.load();
      for (final id in await ThemeLoader.getImportedThemeIds()) {
        if (_packs.any((pack) => pack.id == id)) continue;
        final pack = await ThemeLoader.loadPackFromDisk(id);
        if (pack != null) _packs.add(pack);
      }
      // 读取失败时保留磁盘主题及选中 ID，避免一次存储故障抹掉用户选择。
      _settings = _settings.copyWith(
        launchCount: _settings.launchCount + 1,
        firstLaunchDate: _settings.firstLaunchDate == 0
            ? DateTime.now().millisecondsSinceEpoch
            : _settings.firstLaunchDate,
      );
      await _activate();
      await _persist();
    } catch (error, stack) {
      Log.e('ThemeProvider', 'Theme initialization failed', error, stack);
    }
  }

  Future<void> _persist() {
    final snapshot = _settings;
    return _pendingSave = _pendingSave
        .then((_) => _store.save(snapshot))
        .catchError((Object error, StackTrace stack) {
      Log.e('ThemeProvider', 'Cannot save theme settings', error, stack);
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _update(ThemeSettings settings) {
    _settings = settings;
    _notify();
    return _persist();
  }

  Future<void> _activate() async {
    final generation = ++_activation;
    final pack = currentPack;
    ThemeAssets.loadFromThemePack(pack);
    _hasValidBg = false;
    final wallpaper = pack.playerBgPath;
    bool exists = false;
    if (wallpaper != null && wallpaper.isNotEmpty) {
      exists =
          wallpaper.startsWith('assets/') || await File(wallpaper).exists();
    }
    await _loadFonts(pack);
    if (generation != _activation || _disposed) return;
    _hasValidBg = exists;
    _notify();
  }

  Future<void> _loadFonts(ThemePack pack) async {
    final family = pack.fontFamily;
    final weights = pack.fontWeightFiles;
    if (family == null || weights == null) return;
    for (final filename in weights.toJson().values.whereType<String>()) {
      try {
        final file = File(filename);
        if (!await file.exists()) continue;
        final modified = (await file.lastModified()).microsecondsSinceEpoch;
        final key = '$family:$filename:$modified';
        if (_loadedFonts.contains(key)) continue;
        await ui.loadFontFromList(await file.readAsBytes(), fontFamily: family);
        _loadedFonts.add(key);
      } catch (error, stack) {
        Log.e('ThemeProvider', 'Cannot load theme font', error, stack);
      }
    }
  }

  Future<void> selectPack(String packId) async {
    if (selectedPackId == packId || !_packs.any((pack) => pack.id == packId)) {
      return;
    }
    _settings = _settings.copyWith(selectedPackId: packId);
    final saved = _persist();
    await _activate();
    await saved;
  }

  Future<bool> importTheme() async {
    final pack = await ThemeLoader.importFromPicker();
    if (pack == null) return false;
    _replacePack(pack);
    _settings = _settings.copyWith(selectedPackId: pack.id);
    await _activate();
    await _persist();
    return true;
  }

  void _replacePack(ThemePack pack) {
    final index = _packs.indexWhere((existing) => existing.id == pack.id);
    if (index < 0) {
      _packs.add(pack);
    } else if (!_packs[index].isBuiltIn) {
      _packs[index] = pack;
    }
  }

  void addMarketPack(ThemePack pack) {
    _replacePack(pack);
    if (selectedPackId == pack.id) {
      unawaited(_activate());
    } else {
      _notify();
    }
  }

  Future<void> deletePack(String packId) async {
    final pack = _packs.where((pack) => pack.id == packId).firstOrNull;
    if (pack == null || pack.isBuiltIn) return;
    await _deleteTheme(packId);
    try {
      await _uninstallMarketTheme(packId);
    } catch (error, stack) {
      Log.w('ThemeProvider', 'Cannot clear theme market record', error, stack);
    }
    _packs.removeWhere((pack) => pack.id == packId);
    if (selectedPackId == packId) {
      _settings = _settings.copyWith(selectedPackId: ngsNagisa.id);
      await _activate();
      await _persist();
    } else {
      _notify();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _update(_settings.copyWith(mode: mode));
  Future<void> setAccent(String key) =>
      _update(_settings.copyWith(accentKey: key, useMonet: false));
  Future<void> clearAccentOverride() => setAccent('');
  Future<void> setCustomColor(Color color) => _update(_settings.copyWith(
      accentKey: 'custom', customColor: color, useMonet: false));
  Future<void> setUseMonet(bool value) => _update(
      _settings.copyWith(useMonet: value, accentKey: value ? accentKey : ''));
  Future<void> setFlowLightEnabled(bool value) =>
      _update(_settings.copyWith(flowLight: value));
  Future<void> setShowHiResBadge(bool value) =>
      _update(_settings.copyWith(showHiResBadge: value));
  Future<void> setLyricSettings(LyricSettings settings) =>
      _update(_settings.copyWith(lyricOverride: settings));
  Future<void> dismissSupportPopup() =>
      _update(_settings.copyWith(supportDismissed: true));

  ColorScheme _scheme(Brightness brightness, ColorScheme? dynamicScheme) {
    if (useMonet && dynamicScheme != null) return dynamicScheme;
    if (useMonet || hasAccentOverride) {
      return ColorScheme.fromSeed(
        seedColor: useMonet ? const Color(0xFF2CA1F4) : effectiveColor,
        brightness: brightness,
      );
    }
    return (brightness == Brightness.light
            ? currentPack.lightScheme
            : currentPack.darkScheme) ??
        ColorScheme.fromSeed(
            seedColor: const Color(0xFF2CA1F4), brightness: brightness);
  }

  ThemeData buildLightTheme(BuildContext context,
          {ColorScheme? dynamicScheme}) =>
      AppTheme.build(_scheme(Brightness.light, dynamicScheme), currentPack,
          hasGlobalBg: _hasValidBg);
  ThemeData buildDarkTheme(BuildContext context,
          {ColorScheme? dynamicScheme}) =>
      AppTheme.build(_scheme(Brightness.dark, dynamicScheme), currentPack,
          hasGlobalBg: _hasValidBg);

  @override
  void dispose() {
    _disposed = true;
    _activation++;
    super.dispose();
  }
}
