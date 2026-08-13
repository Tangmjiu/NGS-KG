// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 音频输出设备页 — 列出可用输出，实时跟随蓝牙连接变化

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/audio_route_service.dart';
import '../utils/watch_layout.dart';
import '../utils/watch_motion.dart';
import '../widgets/round_list_tile.dart';
import '../widgets/watch_scaffold.dart';

/// 音频输出设备列表。
///
/// - 启动时枚举一次，随后跟随原生路由变化事件自动刷新
/// - 点击设备请求切换；系统不允许程序化切换时自动打开系统面板
/// - 蓝牙设备电量可用时显示，不可用则隐藏（不臆造数值）
class WatchAudioOutputScreen extends StatefulWidget {
  const WatchAudioOutputScreen({super.key});

  @override
  State<WatchAudioOutputScreen> createState() => _WatchAudioOutputScreenState();
}

class _WatchAudioOutputScreenState extends State<WatchAudioOutputScreen> {
  List<AudioOutputDevice> _devices = const [];
  bool _loading = true;
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _refresh();
    _sub = AudioRouteService.instance.devicesChanged.listen((_) => _refresh());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final devices = await AudioRouteService.instance.getDevices();
    if (!mounted) return;
    setState(() {
      _devices = devices;
      _loading = false;
    });
  }

  Future<void> _select(AudioOutputDevice device) async {
    WatchMotion.tap();
    final ok = await AudioRouteService.instance.setDevice(device.id);
    if (!ok) {
      // 系统不允许程序化切换 → 打开系统媒体输出面板
      await AudioRouteService.instance.openSystemSwitcher();
    }
    // 无论结果如何都刷新：由系统状态作为唯一事实来源
    await _refresh();
  }

  IconData _iconFor(AudioOutputDevice d) => switch (d.type) {
        'speaker' => Icons.watch_rounded,
        'bluetooth' => Icons.bluetooth_rounded,
        'wired' => Icons.headphones_rounded,
        _ => Icons.speaker_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final layout = WatchLayout.of(context);
    final cs = Theme.of(context).colorScheme;

    return WatchScaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              padding: EdgeInsets.fromLTRB(
                layout.listHorizontal,
                4,
                layout.listHorizontal,
                layout.bottomInset + 16,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Center(
                    child: Text(
                      '音频输出',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                if (_devices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        '未检测到输出设备',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                else
                  for (final d in _devices)
                    RoundListTile(
                      title: d.name,
                      subtitle: d.isActive ? '当前输出' : null,
                      selected: d.isActive,
                      leading: Icon(_iconFor(d)),
                      trailing: d.batteryLevel != null
                          ? Text(
                              '${d.batteryLevel}%',
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.6),
                              ),
                            )
                          : (d.isActive
                              ? Icon(Icons.check_rounded,
                                  size: 16, color: cs.primary)
                              : null),
                      onTap: d.isActive ? null : () => _select(d),
                    ),
              ],
            ),
    );
  }
}
