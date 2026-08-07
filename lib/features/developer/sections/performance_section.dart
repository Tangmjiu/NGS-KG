// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../monitors/fps_monitor.dart';
import 'section_card.dart';

/// 性能监控分组（卡顿事件记录）
///
/// FPS / 内存实时指标显示在页面顶部实时指标区（developer_screen）；
/// 本节展示卡顿检测结果（阈值 [FpsMonitor.jankThresholdMs]ms/帧），
/// 检测本身由 main.dart 在 debug/profile 构建中全局启动。
// 新增功能：卡顿检测
class PerformanceSection extends StatelessWidget {
  const PerformanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DeveloperSectionCard(
      icon: Icons.speed,
      title: '性能监控',
      subtitle: 'UI 线程卡顿检测与事件记录',
      initiallyExpanded: false,
      children: [
        ValueListenableBuilder<int>(
          valueListenable: FpsMonitor.instance.jankCount,
          builder: (_, count, __) {
            final janks = FpsMonitor.instance.janks;
            return Column(
              children: [
                if (janks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('暂无卡顿事件（阈值 ${FpsMonitor.jankThresholdMs}ms/帧）',
                        style: textTheme.bodySmall),
                  )
                else ...[
                  ...janks.reversed.take(5).map(
                        (j) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.warning_amber,
                              size: 20, color: Colors.orange),
                          title: Text(
                              '帧间隔 ${j.frameIntervalMs}ms · ${j.fps.toStringAsFixed(1)}fps',
                              style: textTheme.bodySmall),
                          trailing: Text(
                            '${j.time.hour.toString().padLeft(2, '0')}:${j.time.minute.toString().padLeft(2, '0')}:${j.time.second.toString().padLeft(2, '0')}',
                            style: textTheme.labelSmall,
                          ),
                        ),
                      ),
                  if (janks.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('共 $count 次，仅显示最近 5 次',
                          style: textTheme.labelSmall),
                    ),
                ],
              ],
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => FpsMonitor.instance.clearJanks(),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('清空卡顿记录'),
            ),
          ),
        ),
      ],
    );
  }
}
