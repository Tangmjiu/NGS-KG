// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/quality.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/download_provider.dart';
import '../providers/audio_settings_provider.dart';
import '../utils/theme.dart';

/// 桌面端"播放扩展"共享面板：倍速 / 音质 / 音效 / 定时关闭。
///
/// 供桌面底部播放栏 [DesktopPlayerBar] 与全屏播放器
/// [DesktopFullscreenPlayer] 的"更多"入口复用，避免两份重复实现。
/// 全部使用 ColorScheme token + AppShape，符合 MD3 规范。
class PlayerExtrasPanel extends StatelessWidget {
  const PlayerExtrasPanel({super.key});

  static const List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  static const List<Duration> _timerOptions = [
    Duration(minutes: 10),
    Duration(minutes: 20),
    Duration(minutes: 30),
    Duration(minutes: 45),
    Duration(minutes: 60),
  ];

  /// 以 M3 对话框形式打开面板
  static Future<void> show(BuildContext context) {
    return showM3Dialog(
      context: context,
      // root Navigator：桌面端自建 Shell Navigator 的弹窗层不可靠
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('播放选项'),
        content: const SizedBox(width: 420, child: PlayerExtrasPanel()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, p, _) {
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDownloadSection(context, p),
              if (p.currentSong != null) const SizedBox(height: 20),
              _buildSpeedSection(context, p),
              const SizedBox(height: 20),
              _buildTimerSection(context, p),
              const SizedBox(height: 20),
              _buildQualitySection(context, p),
              const SizedBox(height: 20),
              _buildEffectSection(context, p),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(BuildContext context, IconData icon, String title,
      {String? trailing}) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            title,
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (trailing != null) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: AppShape.xs,
              ),
              child: Text(
                trailing,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 下载当前歌曲 ──

  Widget _buildDownloadSection(BuildContext context, PlayerProvider p) {
    final song = p.currentSong;
    if (song == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final dlProvider = context.watch<DownloadProvider>();
    final settings = context.watch<AudioSettingsProvider>();
    final downloaded = dlProvider.isDownloaded(song);
    final quality = settings.downloadQuality;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, Icons.download_rounded, '下载'),
        InkWell(
          borderRadius: AppShape.md,
          onTap: downloaded
              ? () => dlProvider.removeDownload(song)
              : () => dlProvider.download(song, quality: quality),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Icon(
                  downloaded
                      ? Icons.check_circle_outline
                      : Icons.download_for_offline_outlined,
                  size: 20,
                  color: downloaded ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Text(
                  downloaded ? '已下载（点击删除）' : '下载当前歌曲',
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: downloaded ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (!downloaded)
                  Text(
                    '音质：${Song.qualityLabelMap[quality] ?? quality}',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── 倍速 ──

  Widget _buildSpeedSection(BuildContext context, PlayerProvider p) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          context,
          Icons.fast_forward_rounded,
          '播放倍速',
          trailing: '${p.currentSpeed.toStringAsFixed(2)}x',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in _speeds)
              _SelectChip(
                label: '${s}x',
                selected: s == p.currentSpeed,
                onTap: () => p.setSpeed(s),
                cs: cs,
              ),
          ],
        ),
      ],
    );
  }

  // ── 定时关闭 ──

  String _fmtRemaining(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildTimerSection(BuildContext context, PlayerProvider p) {
    final cs = Theme.of(context).colorScheme;
    final remaining = p.sleepTimerRemaining;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          context,
          Icons.timer_outlined,
          '定时关闭',
          trailing: remaining != null ? _fmtRemaining(remaining) : null,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in _timerOptions)
              _SelectChip(
                label: '${d.inMinutes} 分钟',
                selected: remaining != null &&
                    (remaining.inMinutes - d.inMinutes).abs() < 1,
                onTap: () => p.setSleepTimer(d),
                cs: cs,
              ),
            if (remaining != null)
              _SelectChip(
                label: '关闭定时',
                selected: false,
                onTap: p.cancelSleepTimer,
                cs: cs,
              ),
          ],
        ),
      ],
    );
  }

  // ── 音质 ──

  /// 与 Android 分支 player_screen._qualitySubtitle 保持一致
  String _qualitySubtitle(String key) {
    switch (key) {
      case '128':
        return '128kbps';
      case '320':
        return '320kbps';
      case 'high':
      case 'flac':
        return 'FLAC';
      default:
        return '';
    }
  }

  Widget _buildQualitySection(BuildContext context, PlayerProvider p) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final selectedKey = Quality.levels[p.qualityLevel % Quality.levels.length];
    // 在线数据：当前歌曲 privilege 实际可用的音质列表（无数据时回退全部 levels）
    final availableQualities = p.getAvailableQualities();
    final disabledColor = cs.onSurfaceVariant.withValues(alpha: 0.35);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, Icons.high_quality_outlined, '编码音质',
            trailing: p.currentQualityLabel),
        for (final key in Quality.levels)
          _RadioTile(
            label: Quality.label(key),
            subtitle: _qualitySubtitle(key),
            // 可用但不在当前歌曲真实支持列表中 → 降级可用（自动回退到低音质）
            badge:
                p.isQualityAvailable(key) && !availableQualities.contains(key)
                    ? '降级可用'
                    : null,
            selected: key == selectedKey,
            enabled: p.isQualityAvailable(key),
            disabledHint: '当前歌曲不支持',
            onTap: () => p.setQuality(key),
            cs: cs,
            tt: tt,
            disabledColor: disabledColor,
          ),
        if (availableQualities.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(
              '当前歌曲最高支持: ${Quality.label(availableQualities.last)}',
              style: tt.labelSmall?.copyWith(color: disabledColor),
            ),
          ),
      ],
    );
  }

  // ── 音效 ──

  Widget _buildEffectSection(BuildContext context, PlayerProvider p) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final currentEffect = p.effectKey;
    final disabledColor = cs.onSurfaceVariant.withValues(alpha: 0.35);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, Icons.spatial_audio_rounded, '音效',
            trailing: p.effectLabel),
        _RadioTile(
          label: '关闭',
          selected: currentEffect == 'none',
          enabled: true,
          onTap: () => p.setEffect('none'),
          cs: cs,
          tt: tt,
          disabledColor: disabledColor,
        ),
        for (final key in Quality.effects)
          _RadioTile(
            label: Quality.effectLabel(key),
            selected: key == currentEffect,
            enabled: p.isEffectAvailable(key),
            disabledHint: '当前歌曲不支持',
            onTap: () => p.setEffect(key),
            cs: cs,
            tt: tt,
            disabledColor: disabledColor,
          ),
      ],
    );
  }
}

/// 紧凑型选择 chip（倍速/定时选项）
class _SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: AppShape.sm,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.dShort3,
        curve: AppMotion.emphasized,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? cs.secondaryContainer
              : cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: AppShape.sm,
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: 0.5)
                : cs.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: tt.bodyMedium?.copyWith(
            color: selected ? cs.onSecondaryContainer : cs.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// 紧凑型单选行（音质/音效选项）
class _RadioTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final String? badge;
  final bool selected;
  final bool enabled;
  final String? disabledHint;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;
  final Color disabledColor;

  const _RadioTile({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.cs,
    required this.tt,
    required this.disabledColor,
    this.subtitle = '',
    this.badge,
    this.disabledHint,
  });

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? disabledColor
        : (selected ? cs.primary : cs.onSurfaceVariant);
    return InkWell(
      borderRadius: AppShape.sm,
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: tt.bodyMedium?.copyWith(
                color: !enabled
                    ? disabledColor
                    : (selected ? cs.onSurface : cs.onSurfaceVariant),
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                subtitle,
                style: tt.bodySmall?.copyWith(
                  color: enabled ? cs.onSurfaceVariant : disabledColor,
                ),
              ),
            ],
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.08),
                  borderRadius: AppShape.xs,
                ),
                child: Text(
                  badge!,
                  style: tt.labelSmall?.copyWith(color: disabledColor),
                ),
              ),
            ],
            if (!enabled && disabledHint != null) ...[
              const SizedBox(width: 8),
              Text(
                disabledHint!,
                style: tt.labelSmall?.copyWith(color: disabledColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
