// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:io' show ProcessInfo;

import 'package:flutter/foundation.dart';

/// 内存监控（debug/profile 专用，单例）
///
/// 通过 `ProcessInfo.currentRss` 读取当前进程常驻内存，
/// 页面打开时 [start] 每秒采样一次，关闭时 [stop]。
// 新增功能：内存监控
class MemoryMonitor {
  MemoryMonitor._();

  static final MemoryMonitor instance = MemoryMonitor._();

  final ValueNotifier<int> rssBytes = ValueNotifier(0);

  Timer? _timer;

  void start() {
    if (_timer != null) return;
    rssBytes.value = ProcessInfo.currentRss;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      rssBytes.value = ProcessInfo.currentRss;
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
