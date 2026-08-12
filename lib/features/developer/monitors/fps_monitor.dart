// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../../utils/logger.dart';

/// 卡顿事件（单帧耗时超过阈值）
// 新增功能：卡顿检测
class JankEvent {
  final DateTime time;
  final int frameIntervalMs;
  final double fps;

  const JankEvent({
    required this.time,
    required this.frameIntervalMs,
    required this.fps,
  });
}

/// 帧率（FPS）与卡顿检测（debug/profile 专用，单例）
///
/// 通过 [SchedulerBinding.addTimingsCallback] 获取每帧耗时：
/// - 滑动窗口（最近 30 帧）平均间隔换算为实时 FPS，暴露为 [fps]
/// - 单帧间隔 > [jankThresholdMs] 记为卡顿事件（Log.w + 内存缓冲）
///
/// 由 main.dart 在非 Release 构建中全局启动，卡顿检测全程生效。
// 新增功能：帧率显示 + 卡顿检测
class FpsMonitor {
  FpsMonitor._();

  static final FpsMonitor instance = FpsMonitor._();

  /// 卡顿阈值：单帧超过 100ms（约 10fps 以下）记为一次卡顿
  static const int jankThresholdMs = 100;

  /// FPS 滑动窗口帧数
  static const int _windowSize = 30;

  static const int _maxJanks = 50;

  final ValueNotifier<double> fps = ValueNotifier(0);

  final ValueNotifier<int> jankCount = ValueNotifier(0);

  final List<JankEvent> _janks = [];

  final List<int> _recentSpans = [];

  bool _running = false;

  bool get running => _running;

  List<JankEvent> get janks => List.unmodifiable(_janks);

  void start() {
    if (_running) return;
    _running = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void stop() {
    if (!_running) return;
    _running = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  void clearJanks() {
    _janks.clear();
    jankCount.value = 0;
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      final spanMs = timing.totalSpan.inMilliseconds;
      _recentSpans.add(spanMs);
      if (_recentSpans.length > _windowSize) {
        _recentSpans.removeAt(0);
      }

      var sum = 0;
      for (final s in _recentSpans) {
        sum += s;
      }
      final avg = sum / _recentSpans.length;
      final currentFps = avg <= 0 ? 0.0 : 1000.0 / avg;
      fps.value = currentFps;

      if (spanMs > jankThresholdMs) {
        _janks.add(JankEvent(
          time: DateTime.now(),
          frameIntervalMs: spanMs,
          fps: currentFps,
        ));
        if (_janks.length > _maxJanks) {
          _janks.removeAt(0);
        }
        jankCount.value = _janks.length;
        Log.w('FPS',
            '卡顿检测: 帧间隔 ${spanMs}ms (当前 ${currentFps.toStringAsFixed(1)}fps)');
      }
    }
  }
}
