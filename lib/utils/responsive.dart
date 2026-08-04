import 'package:flutter/material.dart';

/// 响应式断点与桌面布局辅助工具。
///
/// 桌面/移动分界线与 [AppShell] / [DesktopShell] 保持一致：600。
/// 所有 screen 应统一使用 [isDesktopLayout] 判断，避免 600~880 区间出现半桌面状态。
class Responsive {
  /// 桌面端最小宽度阈值，与 Shell 统一。
  static const double desktopBreakpoint = 600;

  /// 内容最大宽度建议值。
  static const double maxWidthSettings = 800;
  static const double maxWidthList = 1000;
  static const double maxWidthContent = 1200;

  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static bool isDesktopLayout(BuildContext context) =>
      width(context) >= desktopBreakpoint;

  static bool isMobileLayout(BuildContext context) => !isDesktopLayout(context);

  /// 在桌面端给子内容增加左右内边距，并限制最大宽度。
  static Widget constrainedContent(
    BuildContext context, {
    required Widget child,
    double maxWidth = maxWidthContent,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= desktopBreakpoint;
        return Align(
          alignment: isDesktop ? Alignment.topCenter : Alignment.topLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: isDesktop ? maxWidth : double.infinity),
            child: child,
          ),
        );
      },
    );
  }
}
