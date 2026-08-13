// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 手表布局适配中心 — 圆屏/方屏统一度量入口

import 'package:flutter/material.dart';
import 'package:wear_plus/wear_plus.dart';

/// 圆屏/方屏布局度量。
///
/// 所有屏幕/组件通过 [WatchLayout.of] 获取度量，不再各自散落调用
/// `WatchShape.of(context)`（该调用在没有 [WatchShape] 祖先时会抛异常）。
///
/// - Wear OS：`wear_plus` 原生通道返回真实屏幕形状。
/// - 普通 Android 手表/设备：通道失败时 `wear_plus` 默认 round；
///   这里额外用屏幕宽高比兜底（极端长方形设备不可能是圆屏）。
class WatchLayout {
  /// 是否为圆形屏幕
  final bool isRound;

  /// 屏幕尺寸（圆屏为外接正方形边长）
  final Size screenSize;

  /// 系统 insets（状态栏/chin）
  final EdgeInsets systemPadding;

  const WatchLayout._({
    required this.isRound,
    required this.screenSize,
    required this.systemPadding,
  });

  /// 安全获取布局度量（不应抛出）。
  static WatchLayout of(BuildContext context) {
    final mq = MediaQuery.of(context);
    var round = false;
    try {
      round = WatchShape.of(context) == WearShape.round;
    } catch (_) {
      round = false;
    }
    // 宽高比兜底：明显非正方形的屏幕不可能是圆屏
    if (mq.size.aspectRatio < 0.8 || mq.size.aspectRatio > 1.25) {
      round = false;
    }
    return WatchLayout._(
      isRound: round,
      screenSize: mq.size,
      systemPadding: mq.padding,
    );
  }

  /// 屏幕短边（圆屏即直径）
  double get diameter => screenSize.shortestSide;

  // ─── 尺寸断点（192–225dp 圆屏自适应）───

  /// 紧凑：192–203dp（最小圆屏基准）
  bool get isCompact => diameter <= 203;

  /// 标准：204–224dp
  bool get isStandard => diameter > 203 && diameter < 225;

  /// 扩展：225dp 及以上（显示更多内容/更大控件）
  bool get isExpanded => diameter >= 225;

  /// 全局缩放系数：以 210dp 为基准 1.0，限制在 0.92–1.12，
  /// 用于控件/字号按屏幕尺寸等比微调，禁止直接使用固定像素。
  double get scale => (diameter / 210.0).clamp(0.92, 1.12);

  /// 按断点取值（紧凑/标准/扩展）。
  T pick<T>(T compact, [T? standard, T? expanded]) {
    if (isExpanded) return expanded ?? standard ?? compact;
    if (isStandard) return standard ?? compact;
    return compact;
  }

  /// 触控目标尺寸：不小于 48dp，随屏幕放大。
  double get touchTarget => (48.0 * scale).clamp(48.0, 56.0);

  /// 环形进度/按钮贴边时距屏幕边缘的距离。
  double get edgeGap => diameter * 0.045;

  // ─── 列表/内容的安全边距 ───

  /// 内容水平边距。圆屏按内接正方形收窄（短边 × 0.146），方屏固定 8。
  double get contentHorizontal => isRound ? diameter * 0.146 : 8.0;

  /// 列表项水平边距（比内容窄一档，列表项自身还有内边距）。
  double get listHorizontal => isRound ? diameter * 0.08 : 4.0;

  /// 顶部避让：圆屏额外留时间文本高度，方屏仅系统 insets。
  double get topInset => isRound
      ? (systemPadding.top + 20).clamp(20.0, 44.0)
      : systemPadding.top + 4;

  /// 底部避让：圆屏避让 chin 弧度，方屏仅系统 insets。
  double get bottomInset => isRound
      ? (systemPadding.bottom + 20).clamp(20.0, 44.0)
      : systemPadding.bottom + 4;

  // ─── 播放器布局 ───

  /// 封面直径：圆屏小一些避免超边，方屏可以更舒展。
  double get coverDiameter => isRound ? diameter * 0.30 : diameter * 0.36;

  /// 全屏播放器水平边距。
  double get playerHorizontal => isRound ? diameter * 0.10 : 14.0;

  // ─── 曲面列表效果 ───

  /// 曲面列表边缘衰减强度（0 = 关闭）。仅圆屏生效。
  double get curveStrength => isRound ? 1.0 : 0.0;
}
