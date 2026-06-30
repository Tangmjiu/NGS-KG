import 'package:flutter/material.dart';

/// 歌词显示设置
///
/// 控制歌词视图的字体大小、对齐方式、字重和模糊效果。
/// 可从主题包 JSON 加载默认值。
@immutable
class LyricSettings {
  /// 歌词字体大小（逻辑像素）
  final double fontSize;

  /// 是否居中对齐
  final bool centerAlign;

  /// 歌词字重 (100–900)
  final double fontWeight;

  /// 歌词视图模糊效果
  final bool blurEffect;

  const LyricSettings({
    this.fontSize = 16,
    this.centerAlign = false,
    this.fontWeight = 400,
    this.blurEffect = false,
  });

  static const LyricSettings defaults = LyricSettings();

  /// 当前行的字号（active = fontSize × 1.5）
  double get activeFontSize => fontSize * 1.5;

  /// 翻译/罗马音的字号（translation = fontSize × 0.85）
  double get translationFontSize => fontSize * 0.85;

  /// 解析后的 FontWeight
  FontWeight get resolvedWeight => FontWeight.values.firstWhere(
        (w) => w.index == (fontWeight / 100).round().clamp(1, 9),
        orElse: () => FontWeight.w400,
      );

  LyricSettings copyWith({
    double? fontSize,
    bool? centerAlign,
    double? fontWeight,
    bool? blurEffect,
  }) {
    return LyricSettings(
      fontSize: fontSize ?? this.fontSize,
      centerAlign: centerAlign ?? this.centerAlign,
      fontWeight: fontWeight ?? this.fontWeight,
      blurEffect: blurEffect ?? this.blurEffect,
    );
  }

  // ── 序列化 ──

  Map<String, dynamic> toJson() => {
        'fontSize': fontSize,
        'centerAlign': centerAlign,
        'fontWeight': fontWeight,
        'blurEffect': blurEffect,
      };

  static LyricSettings fromJson(Map<String, dynamic> json) => LyricSettings(
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16,
        centerAlign: json['centerAlign'] as bool? ?? false,
        fontWeight: (json['fontWeight'] as num?)?.toDouble() ?? 400,
        blurEffect: json['blurEffect'] as bool? ?? false,
      );
}
