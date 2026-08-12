// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'debug_prefs_provider.dart';
import 'monitors/fps_monitor.dart';
import 'monitors/memory_monitor.dart';
import 'sections/api_info_section.dart';
import 'sections/data_section.dart';
import 'sections/debug_logs_section.dart';
import 'sections/device_info_section.dart';
import 'sections/layout_debug_section.dart';
import 'sections/performance_section.dart';
import 'sections/section_card.dart';
import 'sections/system_section.dart';
import '../../utils/theme.dart';

/// 开发者工具页（仅 Debug/Profile 构建可达，Release 入口隐藏）
///
/// MD3E 布局：
/// - 顶部实时指标区：FPS / 内存 / 卡顿次数（始终可见）
/// - 分组卡片（ExpansionTile 折叠）：显示与布局调试 / 调试与日志 /
///   性能监控 / 系统交互与触发 / 数据与存储 / 开发者信息（API + 设备）
// 新增功能：开发者工具页 UI 重构
class DeveloperScreen extends StatelessWidget {
  const DeveloperScreen({super.key});

  Future<void> _resetAll(BuildContext context) async {
    final confirmed = await showM3Dialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复默认'),
        content: const Text('将复位布局模式、方向锁定、渲染调试开关、性能叠加层与离线模拟，确定继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    context.read<DebugPrefsProvider>().resetAll();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('已恢复默认调试状态'),
      duration: Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('开发者'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: '恢复默认调试状态',
            onPressed: () => _resetAll(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: const [
          // ── 顶部实时指标区 ──
          _TopMetricsBar(),
          SizedBox(height: 4),
          // ── 功能分组 ──
          LayoutDebugSection(),
          DebugLogsSection(),
          PerformanceSection(),
          SystemSection(),
          DataSection(),
          ApiInfoSection(),
          DeviceInfoSection(),
        ],
      ),
    );
  }
}

/// 顶部实时指标区（FPS / 内存 / 卡顿）
///
/// FPS 与卡顿数据来自全局 FpsMonitor（debug 构建常开）；
/// 内存采样在本页展示期间启动，离开自动停止。
class _TopMetricsBar extends StatefulWidget {
  const _TopMetricsBar();

  @override
  State<_TopMetricsBar> createState() => _TopMetricsBarState();
}

class _TopMetricsBarState extends State<_TopMetricsBar> {
  @override
  void initState() {
    super.initState();
    MemoryMonitor.instance.start();
  }

  @override
  void dispose() {
    MemoryMonitor.instance.stop();
    super.dispose();
  }

  Color _fpsColor(double fps) {
    if (fps >= 55) return Colors.green;
    if (fps >= 30) return Colors.orange;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('实时指标',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ValueListenableBuilder<double>(
                    valueListenable: FpsMonitor.instance.fps,
                    builder: (_, fps, __) => DevMetricCard(
                      label: 'FPS',
                      value: fps <= 0 ? '--' : fps.toStringAsFixed(0),
                      color: fps <= 0 ? null : _fpsColor(fps),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ValueListenableBuilder<int>(
                    valueListenable: MemoryMonitor.instance.rssBytes,
                    builder: (_, bytes, __) => DevMetricCard(
                      label: '内存',
                      value: '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ValueListenableBuilder<int>(
                    valueListenable: FpsMonitor.instance.jankCount,
                    builder: (_, count, __) => DevMetricCard(
                      label: '卡顿',
                      value: '$count 次',
                      color: count == 0 ? null : Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
