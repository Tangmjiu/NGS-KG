// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/music_service.dart';
import '../theme/theme_assets.dart';
import '../utils/theme.dart';

/// 播放队列面板 —— 移动端底部弹窗与桌面端常驻侧栏共用。
///
/// 参数：
/// - [player]：播放器状态
/// - [dismissOnSelect]：点击歌曲后是否关闭面板自身（移动端 BottomSheet 用）
/// - [onClose]：非空时在顶栏显示关闭按钮（桌面常驻面板用）
/// - [scrollController]：外部滚动控制器（移动端 DraggableScrollableSheet 提供；
///   桌面端传 null 时面板内部自建）
class PlaylistQueuePanel extends StatefulWidget {
  final PlayerProvider player;
  final bool dismissOnSelect;
  final VoidCallback? onClose;
  final ScrollController? scrollController;

  const PlaylistQueuePanel({
    super.key,
    required this.player,
    this.dismissOnSelect = false,
    this.onClose,
    this.scrollController,
  });

  @override
  State<PlaylistQueuePanel> createState() => _PlaylistQueuePanelState();
}

class _PlaylistQueuePanelState extends State<PlaylistQueuePanel> {
  ScrollController? _internalCtrl;

  ScrollController get _scrollCtrl => widget.scrollController ?? _internalCtrl!;

  @override
  void initState() {
    super.initState();
    if (widget.scrollController == null) {
      _internalCtrl = ScrollController();
    }
  }

  @override
  void dispose() {
    _internalCtrl?.dispose();
    super.dispose();
  }

  void _onSongTap(int index) {
    if (widget.dismissOnSelect && mounted) {
      Navigator.of(context).pop();
    }
    widget.player.playIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: widget.player,
      builder: (context, _) {
        final player = widget.player;
        return Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // ── 顶栏 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  // 左侧标题和状态
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '播放队列',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          player.playlist.isEmpty
                              ? '暂无播放'
                              : '已播 ${player.currentIndex + 1} / 共 ${player.playlist.length} 首',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),

                  // 1. 定位当前
                  IconButton(
                    icon: const Icon(Icons.my_location_rounded, size: 20),
                    tooltip: '定位到当前播放',
                    onPressed: () {
                      final idx = player.currentIndex;
                      if (idx >= 0 && _scrollCtrl.hasClients) {
                        final offset = (idx * 58.0) - 100;
                        _scrollCtrl.animateTo(
                          offset.clamp(0, _scrollCtrl.position.maxScrollExtent),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                        );
                      }
                    },
                  ),

                  // 2. 载入队列
                  IconButton(
                    icon: const Icon(Icons.folder_open_rounded, size: 20),
                    tooltip: '载入保存队列',
                    onPressed: () => _showLoadQueueDialog(context),
                  ),

                  // 3. 更多操作 (PopupMenu)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    tooltip: '更多操作',
                    color: cs.surfaceContainerHigh,
                    onSelected: (val) {
                      if (val == 'save') {
                        _showSaveQueueDialog(context);
                      } else if (val == 'save_as_playlist') {
                        _saveQueueAsPlaylist(context);
                      } else if (val == 'add_to_playlist') {
                        _showAddToPlaylist(context);
                      } else if (val == 'clear') {
                        _confirmClear(context);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'save',
                        child: Row(
                          children: [
                            Icon(Icons.save_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('保存当前队列'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'save_as_playlist',
                        child: Row(
                          children: [
                            Icon(Icons.playlist_add_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('将队列存为歌单'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'add_to_playlist',
                        child: Row(
                          children: [
                            Icon(Icons.favorite_border_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('收藏当前歌曲到歌单'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'clear',
                        child: Row(
                          children: [
                            Icon(Icons.delete_sweep_rounded,
                                size: 18, color: cs.error),
                            const SizedBox(width: 8),
                            Text('清空播放队列', style: TextStyle(color: cs.error)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // 4. 关闭（桌面常驻面板）
                  if (widget.onClose != null)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      tooltip: '关闭播放队列',
                      onPressed: widget.onClose,
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),

            // ── 播放列表核心区域 ──
            Expanded(
              child: player.playlist.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.queue_music_rounded,
                              size: 56,
                              color:
                                  cs.onSurfaceVariant.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text(
                            '暂无播放',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    )
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      scrollController: _scrollCtrl,
                      itemCount: player.playlist.length,
                      onReorder: (from, to) {
                        player.moveInQueue(from, to);
                      },
                      itemBuilder: (_, i) {
                        final s = player.playlist[i];
                        final isCurrent = i == player.currentIndex;
                        return Dismissible(
                          key: ValueKey('queue_${s.id}_$i'),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) async {
                            return await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('移除'),
                                content: Text('从播放列表移除「${s.name}」？'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('移除'),
                                  ),
                                ],
                              ),
                            );
                          },
                          onDismissed: (_) {
                            player.removeFromQueue(i);
                            setState(() {});
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            decoration: BoxDecoration(
                              color: cs.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.delete_rounded,
                                color: cs.onErrorContainer),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 2),
                            child: Material(
                              key: ValueKey('tile_container_$i'),
                              color: isCurrent
                                  ? cs.primaryContainer.withValues(alpha: 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: ListTile(
                                key: ValueKey('tile_$i'),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 2),
                                leading: SizedBox(
                                  width: 32,
                                  child: Center(
                                    child: isCurrent
                                        ? _MusicVisualizer(
                                            isPlaying: player.isPlaying,
                                            color: cs.primary,
                                          )
                                        : Text(
                                            '${i + 1}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: cs.onSurfaceVariant
                                                      .withValues(alpha: 0.7),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                  ),
                                ),
                                title: Text(
                                  s.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontWeight: isCurrent
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: isCurrent
                                            ? cs.primary
                                            : cs.onSurface,
                                      ),
                                ),
                                subtitle: Text(
                                  s.artistDisplay,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: isCurrent
                                            ? cs.primary.withValues(alpha: 0.7)
                                            : cs.onSurfaceVariant,
                                      ),
                                ),
                                trailing: ReorderableDragStartListener(
                                  index: i,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.drag_handle_rounded,
                                      size: 20,
                                      color: isCurrent
                                          ? cs.primary.withValues(alpha: 0.6)
                                          : cs.onSurfaceVariant
                                              .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                                onTap: () => _onSongTap(i),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  // ── 更多操作 ──

  void _confirmClear(BuildContext context) {
    showM3Dialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空播放列表吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.player.clearPlaylist();
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  void _showSaveQueueDialog(BuildContext context) {
    final player = widget.player;
    final nameCtrl = TextEditingController();
    showM3Dialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('保存队列'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '队列名称',
            hintText: '我的精选',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () {
                nameCtrl.dispose();
                Navigator.pop(ctx);
              },
              child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              nameCtrl.dispose();
              Navigator.pop(ctx);
              player.saveQueueAs(name);
              setState(() {});
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _saveQueueAsPlaylist(BuildContext context) {
    final player = widget.player;
    final songs = player.playlist;
    if (songs.isEmpty) return;
    final nameCtrl = TextEditingController();
    showM3Dialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('将队列存为歌单'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '歌单名称',
            hintText: '我的播放列表',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () {
                nameCtrl.dispose();
                Navigator.pop(ctx);
              },
              child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              nameCtrl.dispose();
              Navigator.pop(ctx);
              try {
                final response = await MusicService().createPlaylist(name);
                int? playlistId;
                final data = response['data'];
                if (data is Map) {
                  playlistId = data['listid'] ?? data['id'] as int?;
                } else if (data is int) {
                  playlistId = data;
                }
                if (playlistId != null && context.mounted) {
                  for (final s in songs) {
                    final trackData = (s.hash?.isNotEmpty ?? false)
                        ? '${s.name}|${s.hash}|${s.albumId}|${s.id}'
                        : s.name;
                    await MusicService()
                        .addTracksToPlaylist(playlistId, trackData);
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('已保存 ${songs.length} 首到歌单「$name」')),
                    );
                  }
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('歌单「$name」已创建')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('保存失败: $e')));
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showLoadQueueDialog(BuildContext context) {
    final player = widget.player;
    final cs = Theme.of(context).colorScheme;
    if (player.savedQueueNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('暂无已保存的播放队列'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('载入播放队列'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: player.savedQueueNames.length,
            itemBuilder: (_, i) {
              final name = player.savedQueueNames[i];
              final count = player.playlistOfSavedQueue(name)?.length ?? 0;
              return ListTile(
                leading: const Icon(Icons.queue_music_rounded),
                title: Text(name),
                subtitle: Text('共 $count 首歌曲'),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: cs.error),
                  onPressed: () {
                    player.deleteQueue(name);
                    Navigator.pop(ctx);
                    setState(() {});
                    _showLoadQueueDialog(context);
                  },
                ),
                onTap: () {
                  player.loadQueue(name);
                  Navigator.pop(ctx);
                  if (widget.dismissOnSelect && mounted) {
                    Navigator.of(context).pop();
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylist(BuildContext context) {
    final player = widget.player;
    final song = player.currentSong;
    if (song == null) return;
    showM3ModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Consumer<PlaylistProvider>(
          builder: (_, pp, __) {
            final playlists = pp.userPlaylists;
            if (playlists.isEmpty) {
              return emptyStateWidget(
                  ThemeAssets.emptyPlaylist, Icons.playlist_add, '暂无歌单');
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('收藏到歌单',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                Divider(
                    height: 1,
                    color: Theme.of(context).colorScheme.outlineVariant),
                SizedBox(
                  height: (playlists.length * 56.0).clamp(80.0, 320.0),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (_, i) {
                      final pl = playlists[i];
                      return ListTile(
                        leading: const Icon(Icons.playlist_play),
                        title: Text(pl.name),
                        onTap: () async {
                          Navigator.pop(context);
                          await _addSongToPlaylist(context, pl.id, song);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _addSongToPlaylist(
      BuildContext context, int playlistId, Song song) async {
    try {
      final data = (song.hash?.isNotEmpty ?? false)
          ? '${song.name}|${song.hash}|${song.albumId}|${song.id}'
          : song.name;
      await MusicService().addTracksToPlaylist(playlistId, data);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已收藏到歌单')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('收藏失败: $e')));
      }
    }
  }
}

/// 当前播放行的均衡器动效（播放时跳动，暂停时静止）
class _MusicVisualizer extends StatefulWidget {
  final bool isPlaying;
  final Color color;

  const _MusicVisualizer({required this.isPlaying, required this.color});

  @override
  State<_MusicVisualizer> createState() => _MusicVisualizerState();
}

class _MusicVisualizerState extends State<_MusicVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _MusicVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: 14,
          height: 14,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(3, (index) {
              double value = 0.35;
              if (widget.isPlaying) {
                final animValue = _controller.value;
                value = (index == 0
                        ? (animValue * 0.75 + 0.1)
                        : index == 1
                            ? (0.85 - animValue * 0.6)
                            : (animValue * 0.5 + 0.35))
                    .clamp(0.2, 1.0);
              }
              return Container(
                width: 2.5,
                height: 14 * value,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
