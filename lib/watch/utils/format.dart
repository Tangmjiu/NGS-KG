// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 手表端共享格式化工具

/// 将 [d] 格式化为 `mm:ss`（负值归零）。
String formatWatchDuration(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}
