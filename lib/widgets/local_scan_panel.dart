// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/local_music_provider.dart';
import '../utils/theme.dart';

/// 本地音乐扫描进度面板（M3 卡片风格）。
///
/// 消费 [LocalMusicProvider] 的扫描进度状态：
/// - 扫描中：线性进度条 + 已扫描/总数 + 已发现首数 + 当前文件路径 + 取消按钮
/// - 扫描完成且 [showSummary]：显示概要（歌曲数 / 目录数）
class LocalScanPanel extends StatelessWidget {
  /// 扫描完成后是否显示概要卡片。
  final bool showSummary;

  const LocalScanPanel({super.key, this.showSummary = false});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalMusicProvider>(
      builder: (context, prov, _) {
        if (!prov.isScanning) {
          if (!showSummary || prov.songs.isEmpty)
            return const SizedBox.shrink();
          return _SummaryCard(
            songCount: prov.songs.length,
            isCancelled: prov.cancelRequested,
          );
        }

        return _ScanningCard(
          progress: prov.scanProgress,
          scanned: prov.scanScanned,
          total: prov.scanTotal,
          found: prov.scanFound,
          currentPath: prov.scanCurrentPath,
          onCancel: prov.cancelScan,
        );
      },
    );
  }
}

/// 扫描进行中的卡片。
class _ScanningCard extends StatelessWidget {
  final double progress;
  final int scanned;
  final int total;
  final int found;
  final String? currentPath;
  final VoidCallback onCancel;

  const _ScanningCard({
    required this.progress,
    required this.scanned,
    required this.total,
    required this.found,
    required this.currentPath,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final ratio = progress < 0 ? null : progress;
    final detail = total > 0
        ? '已扫描 $scanned / $total'
        : (scanned > 0 ? '已收集 $scanned 个文件' : '正在收集文件...');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppShape.md,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (ratio != null)
                  CircularProgressIndicator(
                    value: ratio,
                    strokeWidth: 3,
                    backgroundColor: cs.surfaceContainerHighest,
                    color: cs.primary,
                  )
                else
                  const CircularProgressIndicator(strokeWidth: 3),
                Text(
                  ratio != null && total > 0 ? '${(ratio * 100).round()}%' : '',
                  style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '正在扫描本地音乐',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '已发现 $found 首',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                if (currentPath != null && currentPath!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    currentPath!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onCancel,
            tooltip: '取消扫描',
            icon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 扫描完成后的概要卡片。
class _SummaryCard extends StatelessWidget {
  final int songCount;
  final bool isCancelled;

  const _SummaryCard({required this.songCount, required this.isCancelled});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppShape.md,
      ),
      child: Row(
        children: [
          Icon(isCancelled ? Icons.info_outline : Icons.check_circle_outline,
              size: 18, color: isCancelled ? cs.primary : cs.tertiary),
          const SizedBox(width: 8),
          Text(
            isCancelled ? '扫描已取消，当前共 $songCount 首歌曲' : '本地音乐共 $songCount 首歌曲',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const Spacer(),
          if (!Platform.isAndroid)
            Text(
              _dirHint,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
        ],
      ),
    );
  }

  static const _dirHint = '可添加多个音乐文件夹';
}
