// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/services.dart';

/// 触感反馈类型
enum HapticKind {
  /// 轻触（按钮按下）
  light,

  /// 中触（列表项选择）
  medium,

  /// 重触（关键操作）
  heavy,

  /// 选择反馈（iOS 风格）
  selection,

  /// 成功
  success,

  /// 警告
  warning,

  /// 错误
  error,
}

/// 统一触感反馈入口 — 对标 Rhythm 的 haptic 交互
///
/// 在播放/暂停、切歌、喜欢等核心交互处调用，
/// Android 上映射到系统震动，iOS 映射到 UIFeedbackGenerator。
Future<void> haptic(HapticKind kind) async {
  try {
    switch (kind) {
      case HapticKind.light:
        await HapticFeedback.lightImpact();
        break;
      case HapticKind.medium:
        await HapticFeedback.mediumImpact();
        break;
      case HapticKind.heavy:
        await HapticFeedback.heavyImpact();
        break;
      case HapticKind.selection:
        await HapticFeedback.selectionClick();
        break;
      case HapticKind.success:
        await HapticFeedback.mediumImpact();
        break;
      case HapticKind.warning:
        await HapticFeedback.heavyImpact();
        break;
      case HapticKind.error:
        await HapticFeedback.vibrate();
        break;
    }
  } catch (_) {
    // 平台不支持时静默忽略
  }
}
