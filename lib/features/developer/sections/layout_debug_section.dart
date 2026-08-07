// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../debug_prefs_provider.dart';
import 'section_card.dart';

/// 显示与布局调试分组
///
/// - 手机/平板模式切换（SegmentedButton，强制覆盖响应式判断）
/// - 屏幕方向锁定（自动/竖屏/横屏）
/// - 布局边界显示 / 重绘彩虹 / 性能叠加层（SwitchListTile）
// 新增功能：显示与布局调试
class LayoutDebugSection extends StatelessWidget {
  const LayoutDebugSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DebugPrefsProvider>(
      builder: (context, prefs, _) {
        return DeveloperSectionCard(
          icon: Icons.tablet_android_outlined,
          title: '显示与布局调试',
          subtitle: '强制布局模式、方向锁定、渲染调试',
          initiallyExpanded: false,
          children: [
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('UI 布局模式',
                  style: Theme.of(context).textTheme.labelMedium),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SegmentedButton<DebugLayoutOverride>(
                segments: const [
                  ButtonSegment(
                    value: DebugLayoutOverride.auto,
                    label: Text('自动'),
                    icon: Icon(Icons.smartphone_outlined),
                  ),
                  ButtonSegment(
                    value: DebugLayoutOverride.mobile,
                    label: Text('手机'),
                    icon: Icon(Icons.phone_android),
                  ),
                  ButtonSegment(
                    value: DebugLayoutOverride.tablet,
                    label: Text('平板'),
                    icon: Icon(Icons.tablet_mac),
                  ),
                ],
                selected: {prefs.layoutOverride},
                onSelectionChanged: (s) => prefs.layoutOverride = s.first,
                showSelectedIcon: false,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child:
                  Text('屏幕方向', style: Theme.of(context).textTheme.labelMedium),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SegmentedButton<DebugOrientationLock>(
                segments: const [
                  ButtonSegment(
                    value: DebugOrientationLock.auto,
                    label: Text('自动旋转'),
                    icon: Icon(Icons.screen_rotation),
                  ),
                  ButtonSegment(
                    value: DebugOrientationLock.portrait,
                    label: Text('竖屏'),
                    icon: Icon(Icons.phone_iphone),
                  ),
                  ButtonSegment(
                    value: DebugOrientationLock.landscape,
                    label: Text('横屏'),
                    icon: Icon(Icons.phone_android),
                  ),
                ],
                selected: {prefs.orientationLock},
                onSelectionChanged: (s) => prefs.orientationLock = s.first,
                showSelectedIcon: false,
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              secondary: const Icon(Icons.border_all),
              title: const Text('布局边界显示'),
              subtitle: const Text('debugPaintSizeEnabled'),
              value: prefs.paintBorders,
              onChanged: (v) => prefs.paintBorders = v,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.gradient),
              title: const Text('重绘彩虹'),
              subtitle: const Text('debugRepaintTextRainbowEnabled'),
              value: prefs.repaintRainbow,
              onChanged: (v) => prefs.repaintRainbow = v,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.monitor_heart_outlined),
              title: const Text('性能叠加层'),
              subtitle: const Text('PerformanceOverlay'),
              value: prefs.showPerformanceOverlay,
              onChanged: (v) => prefs.showPerformanceOverlay = v,
            ),
          ],
        );
      },
    );
  }
}
