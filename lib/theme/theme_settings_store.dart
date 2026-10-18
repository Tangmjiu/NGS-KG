// SPDX-License-Identifier: MIT
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lyric_settings.dart';

@immutable
class ThemeSettings {
  final ThemeMode mode;
  final String selectedPackId;
  final String accentKey;
  final Color customColor;
  final bool useMonet;
  final bool flowLight;
  final bool showHiResBadge;
  final LyricSettings? lyricOverride;
  final int launchCount;
  final int firstLaunchDate;
  final bool supportDismissed;

  const ThemeSettings({
    this.mode = ThemeMode.system,
    this.selectedPackId = 'ngs_nagisa',
    this.accentKey = '',
    this.customColor = const Color(0xFF2CA1F4),
    this.useMonet = false,
    this.flowLight = false,
    this.showHiResBadge = false,
    this.lyricOverride,
    this.launchCount = 0,
    this.firstLaunchDate = 0,
    this.supportDismissed = false,
  });

  factory ThemeSettings.fromJson(Map<String, dynamic> json) {
    final mode = json['mode'];
    final pack = json['pack'];
    LyricSettings? lyrics;
    try {
      final raw = json['lyrics'];
      if (raw is Map<String, dynamic>) lyrics = LyricSettings.fromJson(raw);
    } catch (_) {}
    return ThemeSettings(
      mode: mode is int ? ThemeMode.values[mode.clamp(0, 2)] : ThemeMode.system,
      selectedPackId:
          pack is String && pack != 'ngs_default' ? pack : 'ngs_nagisa',
      accentKey: json['accent'] is String ? json['accent'] as String : '',
      customColor: json['color'] is int
          ? Color(json['color'] as int)
          : const Color(0xFF2CA1F4),
      useMonet: json['monet'] == true,
      flowLight: json['flowLight'] == true,
      showHiResBadge: json['hiResBadge'] == true,
      lyricOverride: lyrics,
      launchCount: json['launchCount'] is int ? json['launchCount'] as int : 0,
      firstLaunchDate:
          json['firstLaunchDate'] is int ? json['firstLaunchDate'] as int : 0,
      supportDismissed: json['supportDismissed'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.index,
        'pack': selectedPackId,
        'accent': accentKey,
        'color': customColor.toARGB32(),
        'monet': useMonet,
        'flowLight': flowLight,
        'hiResBadge': showHiResBadge,
        'lyrics': lyricOverride?.toJson(),
        'launchCount': launchCount,
        'firstLaunchDate': firstLaunchDate,
        'supportDismissed': supportDismissed,
      };

  ThemeSettings copyWith({
    ThemeMode? mode,
    String? selectedPackId,
    String? accentKey,
    Color? customColor,
    bool? useMonet,
    bool? flowLight,
    bool? showHiResBadge,
    LyricSettings? lyricOverride,
    int? launchCount,
    int? firstLaunchDate,
    bool? supportDismissed,
  }) =>
      ThemeSettings(
        mode: mode ?? this.mode,
        selectedPackId: selectedPackId ?? this.selectedPackId,
        accentKey: accentKey ?? this.accentKey,
        customColor: customColor ?? this.customColor,
        useMonet: useMonet ?? this.useMonet,
        flowLight: flowLight ?? this.flowLight,
        showHiResBadge: showHiResBadge ?? this.showHiResBadge,
        lyricOverride: lyricOverride ?? this.lyricOverride,
        launchCount: launchCount ?? this.launchCount,
        firstLaunchDate: firstLaunchDate ?? this.firstLaunchDate,
        supportDismissed: supportDismissed ?? this.supportDismissed,
      );
}

/// 设置只写入一个完整快照，旧偏好键只在首次迁移时读取。
class ThemeSettingsStore {
  static const settingsKey = 'theme_settings_v3';

  Future<ThemeSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(settingsKey);
    if (stored != null) {
      try {
        final data = jsonDecode(stored);
        if (data is Map<String, dynamic>) return ThemeSettings.fromJson(data);
      } catch (_) {}
    }
    final existing = prefs
            .getKeys()
            .any((key) => key.startsWith('theme_') && key != settingsKey) ||
        (prefs.getStringList('imported_themes_v2')?.isNotEmpty ?? false);
    Object? lyrics;
    try {
      final raw = prefs.getString('theme_lyric_settings');
      if (raw != null) lyrics = jsonDecode(raw);
    } catch (_) {}
    return ThemeSettings.fromJson({
      'mode': prefs.getInt('theme_mode'),
      'pack': prefs.getString('theme_selected_pack') ?? 'ngs_nagisa',
      'accent': prefs.getString('theme_accent'),
      'color': prefs.getInt('theme_custom_color'),
      'monet': prefs.getBool('theme_use_monet'),
      'flowLight': prefs.getBool('theme_flow_light'),
      'hiResBadge': prefs.getBool('theme_show_hi_res') ?? existing,
      'lyrics': lyrics,
      'launchCount': prefs.getInt('theme_launch_count'),
      'firstLaunchDate': prefs.getInt('theme_first_launch_date'),
      'supportDismissed': prefs.getBool('theme_support_dismissed'),
    });
  }

  Future<void> save(ThemeSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(settingsKey, jsonEncode(settings.toJson()));
  }
}
