// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

/// Material Symbols 可变权重图标封装（M3 Expressive 图标体系）
///
/// 对标 Rhythm 的 Material Symbols 可变字体四轴：
///   - [weight]：字重 100–700（400=常规，500=medium，700=bold）
///   - [fill]：填充 0/1（1 = 实心变体，如心形点赞后）
///   - [grade]：字面灰度 -25–200（正数更粗重，用于强调）
///   - [opticalSize]：光学尺寸 20–48（随图标尺寸缩放，小图标更清晰）
///
/// 全局统一使用 Rounded 风格（与现有 Icons.*_rounded 视觉一致），
/// 选中/激活态推荐 weight 700 + fill 1，普通态 weight 400。
class AppIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;
  final double weight;
  final double grade;
  final double opticalSize;
  final double fill;
  final List<Shadow>? shadows;
  final String? semanticLabel;

  const AppIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.weight = 400,
    this.grade = 0,
    this.opticalSize = 24,
    this.fill = 0,
    this.shadows,
    this.semanticLabel,
  });

  /// 选中/激活态图标（weight 700 + fill 1）
  const AppIcon.selected(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.grade = 10,
    this.opticalSize = 24,
    this.fill = 1,
    this.shadows,
    this.semanticLabel,
  }) : weight = 700;

  /// 次要/装饰态图标（weight 300，更轻盈）
  const AppIcon.light(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.grade = 0,
    this.opticalSize = 24,
    this.fill = 0,
    this.shadows,
    this.semanticLabel,
  }) : weight = 300;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size,
      color: color,
      weight: weight,
      grade: grade,
      opticalSize: opticalSize,
      fill: fill,
      shadows: shadows,
      semanticLabel: semanticLabel,
    );
  }
}

/// Material Symbols 图标速查（本应用常用，统一从 Rounded 风格取）
///
/// 直接使用 [MaterialSymbolsRounded] 亦可；此处提供语义化别名，
/// 避免各处魔法图标名。
abstract final class AppIcons {
  AppIcons._();

  // ── 播放控制 ──
  static const IconData play = Symbols.play_arrow_rounded;
  static const IconData pause = Symbols.pause_rounded;
  static const IconData skipPrevious = Symbols.skip_previous_rounded;
  static const IconData skipNext = Symbols.skip_next_rounded;
  static const IconData repeat = Symbols.repeat_rounded;
  static const IconData repeatOne = Symbols.repeat_one_rounded;
  static const IconData shuffle = Symbols.shuffle_rounded;
  static const IconData radio = Symbols.radio_rounded;

  // ── 收藏 ──
  static const IconData favorite = Symbols.favorite_rounded;
  static const IconData favoriteBorder = Symbols.favorite_border_rounded;

  // ── 媒体/列表 ──
  static const IconData queueMusic = Symbols.queue_music_rounded;
  static const IconData playlistPlay = Symbols.playlist_play_rounded;
  static const IconData musicNote = Symbols.music_note_rounded;
  static const IconData lyrics = Symbols.lyrics_rounded;
  static const IconData tune = Symbols.tune_rounded;
  static const IconData moreHoriz = Symbols.more_horiz_rounded;

  // ── 导航/通用 ──
  static const IconData home = Symbols.home_rounded;
  static const IconData explore = Symbols.explore_rounded;
  static const IconData person = Symbols.person_rounded;
  static const IconData settings = Symbols.settings_rounded;
  static const IconData search = Symbols.search_rounded;
  static const IconData chevronRight = Symbols.chevron_right_rounded;
  static const IconData close = Symbols.close_rounded;
  static const IconData arrowBack = Symbols.arrow_back_rounded;
}
