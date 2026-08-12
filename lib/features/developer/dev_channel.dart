// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/services.dart';

/// Android 开发者工具原生通道（debug/profile 专用）
///
/// 对应 MainActivity.kt 中的 `com.mjiutang.ngskg/devtools` MethodChannel。
// 新增功能：系统交互与设备信息查询
class DevChannel {
  DevChannel._();

  static const MethodChannel _channel =
      MethodChannel('com.mjiutang.ngskg/devtools');

  /// 跳转系统"开发者选项"页面
  static Future<void> openSystemDeveloperSettings() async {
    try {
      await _channel.invokeMethod('openDevSettings');
    } catch (_) {
      // 非 Android 或通道不可用时静默失败
    }
  }

  /// 跳转本应用系统设置页面
  static Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod('openAppSettings');
    } catch (_) {}
  }

  /// 查询可用存储信息（字节）
  ///
  /// 返回 `{total, available}`；不可用时为 null。
  static Future<Map<String, dynamic>?> getStorageInfo() async {
    try {
      final data = await _channel.invokeMethod('getStorageInfo');
      return data is Map ? Map<String, dynamic>.from(data) : null;
    } catch (_) {
      return null;
    }
  }

  /// 查询内存信息（字节）
  ///
  /// 返回 `{totalMem, availMem, lowMemory}`；不可用时为 null。
  static Future<Map<String, dynamic>?> getMemoryInfo() async {
    try {
      final data = await _channel.invokeMethod('getMemoryInfo');
      return data is Map ? Map<String, dynamic>.from(data) : null;
    } catch (_) {
      return null;
    }
  }

  /// 检测设备是否 Root
  static Future<bool> isRooted() async {
    try {
      final result = await _channel.invokeMethod('isRooted');
      return result is bool && result;
    } catch (_) {
      return false;
    }
  }

  /// 触发低内存警告（onTrimMemory(TRIM_MEMORY_RUNNING_LOW)）
  static Future<void> triggerLowMemory() async {
    try {
      await _channel.invokeMethod('triggerLowMemory');
    } catch (_) {}
  }
}
