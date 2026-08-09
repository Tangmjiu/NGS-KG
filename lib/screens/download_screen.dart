// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/song.dart';
import '../providers/download_provider.dart';
import '../providers/player_provider.dart';
import '../services/download_service.dart';
import '../utils/theme.dart';

/// 下载管理页：进行中任务 + 已下载列表 + 缓存管理
class DownloadScreen extends StatelessWidget {
  const DownloadScreen({super.key});

  /// Android：应用私有目录不可达，提示路径；桌面端：在文件管理器中打开
  static Future<void> openInFileManager(
      BuildContext context, String dirPath) async {
    if (Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Android 为应用私有目录，仅可在 App 内访问：\n$dirPath')),
      );
      return;
    }
    try {
      final ok = await launchUrl(
        Uri.file(dirPath),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) throw Exception('launch failed');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开文件夹失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('下载管理'),
      ),
      body: Consumer<DownloadProvider>(
        builder: (context, provider, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _buildDirectorySection(context),
            const Divider(),
            const _SectionHeader('进行中'),
            _buildActiveSection(context, provider),
            const Divider(),
            const _SectionHeader('已下载'),
            _buildDownloadsSection(context, provider),
            const Divider(),
            _buildCacheSection(context, provider),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectorySection(BuildContext context) {
    final service = DownloadService.instance;
    return FutureBuilder<Directory>(
      future: service.getMusicDir(),
      builder: (context, snapshot) {
        final dirPath = snapshot.data?.path ?? '…';
        return ListTile(
          leading: const Icon(Icons.folder_open_outlined),
          title: const Text('下载目录'),
          subtitle: Text(dirPath, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            icon: const Icon(Icons.open_in_new, size: 18),
            tooltip: '打开文件夹',
            onPressed: () => openInFileManager(context, dirPath),
          ),
        );
      },
    );
  }

  Widget _buildActiveSection(BuildContext context, DownloadProvider provider) {
    final active = provider.activeTasks;
    if (active.isEmpty) {
      return const _EmptyHint('暂无下载任务，在歌曲列表点击下载按钮即可');
    }
    return Column(
      children: active.map((t) => _ActiveTaskTile(task: t)).toList(),
    );
  }

  Widget _buildDownloadsSection(
      BuildContext context, DownloadProvider provider) {
    final downloads = provider.downloads;
    if (downloads.isEmpty) {
      return const _EmptyHint('下载的歌曲（含歌词与封面）会出现在这里');
    }
    final player = context.read<PlayerProvider>();
    return Column(
      children: downloads.map((t) {
        final song = _localSongFromTask(t);
        return ListTile(
          leading: const Icon(Icons.music_note_rounded),
          title:
              Text(t.song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(t.song.artistDisplay,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (t.filePath != null)
                IconButton(
                  icon: const Icon(Icons.folder_open_outlined, size: 18),
                  tooltip: '打开所在文件夹',
                  onPressed: () =>
                      openInFileManager(context, p.dirname(t.filePath!)),
                ),
              Text(
                '${Song.qualityLabelMap[t.quality] ?? t.quality} · ${_formatSize(t.totalBytes ?? 0)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              IconButton(
                icon: const Icon(Icons.play_arrow_rounded),
                tooltip: '播放',
                onPressed: () => player.playSong(song,
                    playlist:
                        downloads.map((e) => _localSongFromTask(e)).toList()),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: '删除下载',
                onPressed: () async {
                  final ok = await showM3Dialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('删除下载'),
                      content: Text('删除「${t.song.name}」的本地文件？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) await provider.removeDownload(t.song);
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCacheSection(BuildContext context, DownloadProvider provider) {
    return FutureBuilder<int>(
      future: provider.cacheTotalBytes(),
      builder: (context, snapshot) {
        final size = snapshot.data ?? 0;
        return Column(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.download_for_offline_outlined),
              title: const Text('播放缓存'),
              subtitle: const Text('播放过的歌曲自动缓存，下次播放不消耗流量'),
              value: provider.cacheEnabled,
              onChanged: (v) => provider.setCacheEnabled(v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.wifi),
              title: const Text('仅 WiFi 下缓存'),
              subtitle: const Text('蜂窝网络下不自动缓存'),
              value: provider.cacheOnlyWifi,
              onChanged: (v) => provider.setCacheOnlyWifi(v),
            ),
            ListTile(
              leading: const Icon(Icons.sd_storage_outlined),
              title: const Text('缓存占用'),
              subtitle: Text(_formatSize(size)),
              trailing: size > 0
                  ? TextButton(
                      onPressed: () async {
                        await provider.clearCache();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('缓存已清理')),
                          );
                        }
                      },
                      child: const Text('清空'),
                    )
                  : null,
            ),
            FutureBuilder<Directory>(
              future: DownloadService.instance.getCacheDir(),
              builder: (context, snapshot) {
                final dirPath = snapshot.data?.path ?? '';
                return ListTile(
                  leading: const Icon(Icons.cached),
                  title: const Text('缓存目录'),
                  subtitle: Text(dirPath,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: dirPath.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.open_in_new, size: 18),
                          tooltip: '打开文件夹',
                          onPressed: () => openInFileManager(context, dirPath),
                        ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  static Song _localSongFromTask(DownloadTask t) {
    return Song(
      id: t.song.id,
      name: t.song.name,
      artists: t.song.artists,
      albumName: t.song.albumName,
      albumCoverUrl: t.song.albumCoverUrl,
      hash: t.song.hash,
      filePath: t.filePath,
      duration: t.song.duration,
    );
  }

  static String _formatSize(int bytes) {
    if (bytes <= 0) return '--';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _ActiveTaskTile extends StatelessWidget {
  final DownloadTask task;
  const _ActiveTaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final isCache = task.isCache;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(
              isCache
                  ? Icons.download_for_offline_outlined
                  : Icons.download_rounded,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        task.song.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    if (isCache) ...[
                      const SizedBox(width: 6),
                      Text('缓存',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                if (task.status == DownloadStatus.downloading ||
                    task.status == DownloadStatus.queued)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: task.status == DownloadStatus.queued
                          ? 0
                          : task.progress.clamp(0.0, 1.0),
                      minHeight: 4,
                    ),
                  )
                else
                  Text(
                    task.error ?? _statusLabel(task.status),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: task.status == DownloadStatus.failed
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (task.status == DownloadStatus.downloading ||
              task.status == DownloadStatus.queued)
            Text(
              task.totalBytes != null
                  ? '${(task.progress * 100).toStringAsFixed(0)}%'
                  : '排队中',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: '取消',
            onPressed: () => context.read<DownloadProvider>().cancel(task.key),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(DownloadStatus s) {
    switch (s) {
      case DownloadStatus.done:
        return '已完成';
      case DownloadStatus.failed:
        return '下载失败';
      case DownloadStatus.cancelled:
        return '已取消';
      default:
        return '';
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
