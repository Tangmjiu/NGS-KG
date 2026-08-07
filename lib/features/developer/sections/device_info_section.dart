// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../services/device_service.dart';
import '../../../utils/logger.dart';
import '../dev_channel.dart';
import 'section_card.dart';

/// 开发者信息 — 设备信息分组
///
/// 优化项：分辨率（物理像素）、可用存储、可用内存、是否 Root。
/// 保留原"重新注册设备"功能。
// 优化功能：设备信息展示
class DeviceInfoSection extends StatefulWidget {
  const DeviceInfoSection({super.key});

  @override
  State<DeviceInfoSection> createState() => _DeviceInfoSectionState();
}

class _DeviceInfoSectionState extends State<DeviceInfoSection> {
  String _resolution = '—';
  String _storage = '—';
  String _memory = '—';
  String _root = '检测中…';
  String _dfid = '—';
  String _mid = '—';
  String _guid = '—';
  String _serverDev = '—';
  bool _loading = false;
  // 防止 didChangeDependencies 多次触发时重复加载
  bool _depsLoaded = false;

  @override
  void initState() {
    super.initState();
    // 注意：不在 initState 中读取 MediaQuery —— dependOnInheritedWidgetOfExactType
    // 在 initState 完成前调用会抛异常，初始化统一迁移到 didChangeDependencies。
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_depsLoaded) return;
    _depsLoaded = true;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // 分辨率（物理像素）
      final size = MediaQuery.of(context).size;
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final widthPx = (size.width * dpr).round();
      final heightPx = (size.height * dpr).round();

      // 设备指纹
      final device = await DeviceService.instance.getDeviceInfo();

      // 原生信息（存储/内存/Root）
      final storage = await DevChannel.getStorageInfo();
      final memory = await DevChannel.getMemoryInfo();
      final rooted = await DevChannel.isRooted();

      if (!mounted) return;
      setState(() {
        _resolution =
            '${widthPx}x$heightPx px（${size.width.round()}x${size.height.round()} dp）';
        _storage = storage == null
            ? '不可用'
            : '可用 ${_fmtBytes(storage['available'])} / 共 ${_fmtBytes(storage['total'])}';
        _memory = memory == null
            ? '不可用'
            : '可用 ${_fmtBytes(memory['availMem'])} / 共 ${_fmtBytes(memory['totalMem'])}'
                '${memory['lowMemory'] == true ? '（内存不足）' : ''}';
        _root = rooted ? '是（已 Root）' : '否';
        _dfid = device?.dfid ?? '—';
        _mid = device?.mid ?? '—';
        _guid = device?.guid ?? '—';
        _serverDev = device?.serverDev ?? '—';
      });
    } catch (e) {
      Log.w('DEVTOOLS', '设备信息加载失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtBytes(Object? value) {
    final bytes = value is int ? value : (value is double ? value.round() : 0);
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var v = bytes.toDouble();
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
  }

  Future<void> _resetDfid() async {
    try {
      final device = await DeviceService.instance.registerDevice();
      if (!mounted) return;
      setState(() {
        _dfid = device.dfid;
        _mid = device.mid;
        _guid = device.guid;
        _serverDev = device.serverDev;
      });
      Log.i('DEVTOOLS', '设备已重新注册: ${device.dfid}');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('设备已重新注册'),
        duration: Duration(seconds: 2),
      ));
    } catch (e) {
      Log.e('DEVTOOLS', '设备重新注册失败', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DeveloperSectionCard(
      icon: Icons.smartphone_outlined,
      title: '设备信息',
      subtitle: '分辨率、存储、内存、Root',
      initiallyExpanded: false,
      children: [
        DevInfoRow(
          label: '分辨率',
          value: _resolution,
          icon: Icons.aspect_ratio,
        ),
        DevInfoRow(
          label: '可用存储',
          value: _storage,
          icon: Icons.storage_outlined,
        ),
        DevInfoRow(
          label: '可用内存',
          value: _memory,
          icon: Icons.memory,
        ),
        DevInfoRow(
          label: '是否 Root',
          value: _root,
          icon: Icons.security_outlined,
        ),
        const Divider(height: 16),
        DevInfoRow(label: 'dfid', value: _dfid, icon: Icons.tag),
        DevInfoRow(label: 'mid', value: _mid, icon: Icons.tag),
        DevInfoRow(label: 'guid', value: _guid, icon: Icons.tag),
        DevInfoRow(label: 'serverDev', value: _serverDev, icon: Icons.tag),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('刷新'),
            ),
            TextButton.icon(
              onPressed: () => _resetDfid(),
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('重新注册设备'),
            ),
          ],
        ),
      ],
    );
  }
}
