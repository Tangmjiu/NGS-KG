// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'package:flutter/material.dart';

import '../services/audio_route_service.dart';
import '../widgets/round_list_tile.dart';
import 'login_screen.dart';

class WatchAudioOutputScreen extends StatefulWidget {
  const WatchAudioOutputScreen({super.key});
  @override
  State<WatchAudioOutputScreen> createState() => _WatchAudioOutputScreenState();
}

class _WatchAudioOutputScreenState extends State<WatchAudioOutputScreen>
    with WidgetsBindingObserver {
  final _routes = AudioRouteService.instance;
  List<AudioOutputDevice> _devices = const [];
  bool _loading = true;
  bool _switching = false;
  int _revision = 0;
  late final StreamSubscription<void> _changes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _changes = _routes.devicesChanged.listen((_) => _refresh());
    _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _changes.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final revision = ++_revision;
    final devices = await _routes.getDevices();
    if (!mounted || revision != _revision) return;
    setState(() {
      _devices = [
        for (final device in devices)
          if (device.isActive) device,
        for (final device in devices)
          if (!device.isActive) device,
      ];
      _loading = false;
    });
  }

  Future<void> _select([AudioOutputDevice? device]) async {
    if (_switching || ModalRoute.of(context)?.isCurrent != true) return;
    setState(() => _switching = true);
    try {
      final accepted = device != null && await _routes.setDevice(device.id);
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      if (!accepted) await _routes.openSystemSwitcher();
      if (mounted) await _refresh();
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  Widget build(BuildContext context) => WatchFlowPage(
    title: '音频输出',
    children: [
      if (_loading)
        const Center(child: CircularProgressIndicator(semanticsLabel: '正在查找设备'))
      else ...[
        if (_devices.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('没有找到输出设备', textAlign: TextAlign.center),
          ),
        for (final device in _devices)
          Semantics(
            selected: device.isActive,
            child: RoundListTile(
              key: ValueKey(device.id),
              title: device.name,
              selected: device.isActive,
              subtitle: device.isActive ? '当前输出' : null,
              leading: Icon(switch (device.type) {
                'speaker' => Icons.watch_outlined,
                'bluetooth' => Icons.bluetooth_audio_rounded,
                'wired' => Icons.headphones_rounded,
                _ => Icons.speaker_outlined,
              }),
              trailing:
                  device.batteryLevel != null &&
                      device.batteryLevel! >= 0 &&
                      device.batteryLevel! <= 100
                  ? Text(
                      '${device.batteryLevel}%',
                      semanticsLabel: '电量 ${device.batteryLevel}%',
                    )
                  : null,
              onTap: _switching || device.isActive
                  ? null
                  : () => _select(device),
            ),
          ),
        const SizedBox(height: 6),
        OutlinedButton(
          onPressed: _switching ? null : () => _select(),
          child: const Text('系统输出设置'),
        ),
      ],
    ],
  );
}
