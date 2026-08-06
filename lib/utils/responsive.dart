// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

/// 屏幕类型（断点：<600dp 手机，600-1024dp 平板，≥1024dp 桌面）
///
/// 注意：本项目仅适配 Android（手机 + 平板）。
/// [ScreenType.desktop] 仅保留枚举定义，不写任何桌面端代码；
/// Android 大屏（≥1024dp，如 14 英寸平板横屏）一律按平板布局处理。
enum ScreenType { mobile, tablet, desktop }

class Responsive {
  /// 断点：手机 < 600dp，平板 600-1024dp，桌面 ≥ 1024dp
  static const double tabletBreakpoint = 600;
  static const double desktopBreakpoint = 1024;

  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= desktopBreakpoint) return ScreenType.desktop;
    if (width >= tabletBreakpoint) return ScreenType.tablet;
    return ScreenType.mobile;
  }

  static bool isMobile(BuildContext context) =>
      getScreenType(context) == ScreenType.mobile;

  /// 平板及以上（Android 上 ≥1024dp 的大屏平板也归入平板布局）
  static bool isTablet(BuildContext context) =>
      getScreenType(context) != ScreenType.mobile;

  static bool isDesktop(BuildContext context) =>
      getScreenType(context) == ScreenType.desktop;
}

/// BuildContext 扩展方法，调用更简洁
extension ScreenTypeExtension on BuildContext {
  ScreenType get screenType => Responsive.getScreenType(this);

  bool get isMobile => Responsive.isMobile(this);

  bool get isTablet => Responsive.isTablet(this);

  bool get isDesktop => Responsive.isDesktop(this);

  /// 横屏平板（宽 ≥ 600dp 且宽 > 高）—— 播放页双栏布局的触发条件
  bool get isLandscapeTablet {
    if (!isTablet) return false;
    final size = MediaQuery.of(this).size;
    return size.width > size.height;
  }
}
