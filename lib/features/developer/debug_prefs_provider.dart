// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart'
    show debugPaintSizeEnabled, debugRepaintTextRainbowEnabled;
import 'package:flutter/services.dart' show DeviceOrientation, SystemChrome;

import '../../utils/responsive.dart';
import 'network/dev_network_monitor.dart';

/// 布局模式强制覆盖（测试响应式适配用）
///
/// [DebugLayoutOverride.auto] 表示跟随屏幕宽度自动判断（默认行为）。
// 新增功能
enum DebugLayoutOverride { auto, mobile, tablet }

/// 屏幕方向锁定
///
/// [DebugOrientationLock.auto] 表示跟随系统自动旋转（默认行为）。
// 新增功能
enum DebugOrientationLock { auto, portrait, landscape }

/// 开发者工具全局调试状态（仅 Debug/Profile 构建注册，Release 自动隐藏）
///
/// 硬性约束：
/// - 本类只在 `!kReleaseMode` 时注册进 Provider 树（见 main.dart），
///   Release 构建中整个使用链被 tree-shake，入口与功能均不可见。
/// - 所有 setter 均立即产生全局副作用（debug flag / 方向 / 离线开关）。
class DebugPrefsProvider extends ChangeNotifier {
  DebugLayoutOverride _layoutOverride = DebugLayoutOverride.auto;
  DebugOrientationLock _orientationLock = DebugOrientationLock.auto;
  bool _paintBorders = false;
  bool _repaintRainbow = false;
  bool _showPerformanceOverlay = false;
  bool _offlineMode = false;

  DebugLayoutOverride get layoutOverride => _layoutOverride;
  DebugOrientationLock get orientationLock => _orientationLock;
  bool get paintBorders => _paintBorders;
  bool get repaintRainbow => _repaintRainbow;
  bool get showPerformanceOverlay => _showPerformanceOverlay;
  bool get offlineMode => _offlineMode;

  /// 强制切换 UI 布局模式（测试响应式适配）
  // 新增功能：手机/平板模式切换
  set layoutOverride(DebugLayoutOverride value) {
    if (_layoutOverride == value) return;
    _layoutOverride = value;
    switch (value) {
      case DebugLayoutOverride.auto:
        Responsive.forcedType = null;
        break;
      case DebugLayoutOverride.mobile:
        Responsive.forcedType = ScreenType.mobile;
        break;
      case DebugLayoutOverride.tablet:
        Responsive.forcedType = ScreenType.tablet;
        break;
    }
    notifyListeners();
  }

  /// 屏幕方向锁定（全局 SystemChrome 生效）
  // 新增功能：屏幕方向锁定
  set orientationLock(DebugOrientationLock value) {
    if (_orientationLock == value) return;
    _orientationLock = value;
    switch (value) {
      case DebugOrientationLock.auto:
        SystemChrome.setPreferredOrientations([]);
        break;
      case DebugOrientationLock.portrait:
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        break;
      case DebugOrientationLock.landscape:
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        break;
    }
    notifyListeners();
  }

  /// 布局边界显示（debugPaintSizeEnabled）
  // 新增功能：布局边界显示
  set paintBorders(bool value) {
    if (_paintBorders == value) return;
    _paintBorders = value;
    debugPaintSizeEnabled = value;
    notifyListeners();
  }

  /// 重绘彩虹（debugRepaintTextRainbowEnabled）
  // 新增功能：重绘彩虹
  set repaintRainbow(bool value) {
    if (_repaintRainbow == value) return;
    _repaintRainbow = value;
    debugRepaintTextRainbowEnabled = value;
    notifyListeners();
  }

  /// 性能叠加层（PerformanceOverlay，由 main.dart 全局包裹）
  // 新增功能：性能叠加层
  set showPerformanceOverlay(bool value) {
    if (_showPerformanceOverlay == value) return;
    _showPerformanceOverlay = value;
    notifyListeners();
  }

  /// 模拟网络断开（Dio 拦截层立即拒绝所有请求，可恢复）
  // 新增功能：模拟网络断开
  set offlineMode(bool value) {
    if (_offlineMode == value) return;
    _offlineMode = value;
    DevNetworkMonitor.instance.setOffline(value);
    notifyListeners();
  }

  /// 一键恢复所有调试状态为默认（开发者页"恢复默认"按钮）
  ///
  /// 布局覆盖、方向锁定、渲染调试开关、性能叠加层、离线模拟全部复位。
  void resetAll() {
    _layoutOverride = DebugLayoutOverride.auto;
    Responsive.forcedType = null;
    _orientationLock = DebugOrientationLock.auto;
    SystemChrome.setPreferredOrientations([]);
    _paintBorders = false;
    debugPaintSizeEnabled = false;
    _repaintRainbow = false;
    debugRepaintTextRainbowEnabled = false;
    _showPerformanceOverlay = false;
    _offlineMode = false;
    DevNetworkMonitor.instance.setOffline(false);
    notifyListeners();
  }
}
