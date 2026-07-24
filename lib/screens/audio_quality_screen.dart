// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/audio_settings_provider.dart';

/// 音质设置子页面
class AudioQualityScreen extends StatelessWidget {
  const AudioQualityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('音质设置')),
      body: Consumer<AudioSettingsProvider>(
        builder: (_, settings, __) => ListView(
          children: [
            const _SectionHeader('网络音质'),
            _QualityTile(
              icon: Icons.wifi,
              label: 'WiFi 网络',
              value: settings.wifiQuality,
              onSelected: (key) => settings.setWifiQuality(key),
            ),
            _QualityTile(
              icon: Icons.signal_cellular_alt,
              label: '蜂窝网络',
              value: settings.cellularQuality,
              onSelected: (key) => settings.setCellularQuality(key),
            ),
            _QualityTile(
              icon: Icons.download,
              label: '下载音质',
              value: settings.downloadQuality,
              onSelected: (key) => settings.setDownloadQuality(key),
            ),
            const Divider(),
            const _SectionHeader('智能控制'),
            SwitchListTile(
              secondary: const Icon(Icons.auto_awesome),
              title: const Text('智能模式'),
              subtitle: const Text('WiFi 自动最高音质，蜂窝按设定'),
              value: settings.smartMode,
              onChanged: (v) => settings.setSmartMode(v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.history),
              title: const Text('提交听歌历史'),
              subtitle: const Text('关闭后不会向服务器上报播放记录'),
              value: settings.uploadHistory,
              onChanged: (v) => settings.setUploadHistory(v),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              )),
    );
  }
}

class _QualityTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ValueChanged<String> onSelected;

  const _QualityTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final display = Song.qualityLabelMap[value] ?? value;
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(display,
          style: TextStyle(color: Theme.of(context).colorScheme.primary)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('选择 $label 音质',
                      style: Theme.of(ctx).textTheme.titleSmall),
                ),
                ...Song.qualityKeys.map((key) {
                  final label = Song.qualityLabelMap[key] ?? key;
                  return RadioListTile<String>(
                    title: Text(label),
                    subtitle: Text(_qualityDesc(key)),
                    value: key,
                    groupValue: value,
                    onChanged: (v) {
                      if (v != null) onSelected(v);
                      Navigator.pop(ctx);
                    },
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _qualityDesc(String key) {
    switch (key) {
      case '128':
        return '约 1 MB/min，最省流量';
      case '320':
        return '约 2.4 MB/min，音质与流量均衡';
      case 'flac':
        return '无损 FLAC，适合 WiFi 环境';
      case 'high':
        return 'Hi-Res 高解析，适合 WiFi 环境';
      default:
        return '';
    }
  }
}
