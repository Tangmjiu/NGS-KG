import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/music_service.dart';

/// 弹出桌面端播放列表 Side Sheet（右侧覆盖层，400px 宽）
///
/// 同步 Android 端功能：拖拽排序、滑动删除、收藏到歌单、存为歌单、跳转到当前播放。
/// 桌面优化：悬停高亮、tooltip、拖拽手柄可点可拖。
void showPlaylistSideSheet(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭播放列表',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, _, __) {
      return const _PlaylistSideSheet();
    },
    transitionBuilder: (context, animation, _, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        )),
        child: child,
      );
    },
  );
}

class _PlaylistSideSheet extends StatelessWidget {
  const _PlaylistSideSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 400,
          height: double.infinity,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(-4, 0),
              ),
            ],
          ),
          child: Consumer<PlayerProvider>(
            builder: (_, player, __) {
              return Column(
                children: [
                  _header(context, player),
                  _nowPlayingCard(context, player),
                  const Divider(height: 1),
                  Expanded(child: _queueList(context, player)),
                  _bottomActions(context, player),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, PlayerProvider player) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Text('播放队列',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text('${player.playlist.length} 首',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: '关闭',
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _nowPlayingCard(BuildContext context, PlayerProvider player) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final currentSong = player.currentSong;
    if (currentSong == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 48, height: 48,
              child: currentSong.albumCoverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: currentSong.albumCoverUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                          color: cs.surfaceContainerHighest,
                          child: const Icon(Icons.music_note, size: 24)),
                    )
                  : Container(
                      color: cs.surfaceContainerHighest,
                      child: const Icon(Icons.music_note, size: 24)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('正在播放',
                    style: tt.labelSmall?.copyWith(color: cs.primary, fontSize: 11)),
                const SizedBox(height: 2),
                Text(currentSong.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  Queue list — ReorderableListView + Dismissible
  // ────────────────────────────────────────────────────────────────

  Widget _queueList(BuildContext context, PlayerProvider player) {
    if (player.playlist.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_music_outlined, size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text('列表为空',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: player.playlist.length,
      onReorder: (from, to) => player.moveInQueue(from, to),
      proxyDecorator: (child, index, animation) => Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        shadowColor: Colors.black38,
        child: child,
      ),
      itemBuilder: (_, i) {
        final s = player.playlist[i];
        final isCurrent = i == player.currentIndex;
        return Dismissible(
          key: ValueKey('queue_${s.id}'),
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
          onDismissed: (_) => player.removeFromQueue(i),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            color: Theme.of(context).colorScheme.error,
            child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
          ),
          child: _QueueTile(
            key: ValueKey('tile_${s.id}'),
            song: s,
            index: i,
            isCurrent: isCurrent,
            player: player,
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  Bottom action bar
  // ────────────────────────────────────────────────────────────────

  Widget _bottomActions(BuildContext context, PlayerProvider player) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: cs.outlineVariant, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: 收藏到歌单 / 存为歌单 / 跳转到当前
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: Icons.playlist_add,
                    label: '收藏到歌单',
                    onTap: () {
                      Navigator.pop(context);
                      _addCurrentToPlaylist(context, player);
                    },
                  ),
                ),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.save_alt,
                    label: '存为歌单',
                    onTap: () {
                      Navigator.pop(context);
                      _saveQueueAsPlaylist(context, player);
                    },
                  ),
                ),
              ],
            ),
          ),
          // Row 2: 跳转到当前 / 清空
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: Icons.my_location,
                    label: '跳转到当前',
                    color: cs.primary,
                    onTap: () {
                      // Scroll to current song — close sheet first, user reopens to see
                      player.playIndex(player.currentIndex);
                      Navigator.pop(context);
                    },
                  ),
                ),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.delete_sweep,
                    label: '清空列表',
                    color: cs.error,
                    onTap: () {
                      Navigator.pop(context);
                      _confirmClear(context, player);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  Helper dialogs (ported from Android's playback_controls.dart)
  // ────────────────────────────────────────────────────────────────

  static void _addCurrentToPlaylist(BuildContext context, PlayerProvider player) {
    final song = player.currentSong;
    if (song == null) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Consumer<PlaylistProvider>(
          builder: (_, pp, __) {
            final playlists = pp.userPlaylists;
            if (playlists.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.playlist_add, size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    const Text('暂无歌单，请先创建'),
                  ],
                ),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('收藏到歌单',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
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

  static Future<void> _addSongToPlaylist(BuildContext context, int playlistId, Song song) async {
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

  static void _confirmClear(BuildContext context, PlayerProvider player) {
    showDialog(
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
              player.setPlaylist([]);
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  static void _saveQueueAsPlaylist(BuildContext context, PlayerProvider player) {
    final songs = player.playlist;
    if (songs.isEmpty) return;
    final nameCtrl = TextEditingController();
    showDialog(
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
                    await MusicService().addTracksToPlaylist(playlistId, trackData);
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已保存 ${songs.length} 首到歌单「$name」')),
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
}

// ────────────────────────────────────────────────────────────────
//  Queue tile — draggable, hover-highlight, album art thumbnail
// ────────────────────────────────────────────────────────────────

class _QueueTile extends StatefulWidget {
  final Song song;
  final int index;
  final bool isCurrent;
  final PlayerProvider player;

  const _QueueTile({
    super.key,
    required this.song,
    required this.index,
    required this.isCurrent,
    required this.player,
  });

  @override
  State<_QueueTile> createState() => _QueueTileState();
}

class _QueueTileState extends State<_QueueTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: widget.isCurrent
            ? cs.primaryContainer.withValues(alpha: 0.15)
            : (_isHovered ? cs.surfaceContainerHigh : Colors.transparent),
        child: ListTile(
          dense: true,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle — also clickable for keyboard accessibility
              ReorderableDragStartListener(
                index: widget.index,
                child: _isHovered
                    ? Icon(Icons.drag_indicator, size: 20, color: cs.onSurfaceVariant)
                    : const SizedBox(width: 20),
              ),
              const SizedBox(width: 4),
              // Album art thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 36, height: 36,
                  child: widget.song.albumCoverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: widget.song.albumCoverUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _indexBadge(cs),
                        )
                      : _indexBadge(cs),
                ),
              ),
            ],
          ),
          title: Text(
            widget.song.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: widget.isCurrent ? FontWeight.w600 : FontWeight.normal,
              color: widget.isCurrent ? cs.primary : null,
            ),
          ),
          subtitle: Text(
            widget.song.artistDisplay,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
          trailing: widget.isCurrent
              ? Icon(Icons.play_arrow_rounded, size: 16, color: cs.primary)
              : IconButton(
                  icon: Icon(Icons.play_arrow, size: 16, color: cs.onSurfaceVariant),
                  tooltip: '播放',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () {
                    widget.player.playIndex(widget.index);
                    Navigator.pop(context);
                  },
                ),
          onTap: () {
            if (!widget.isCurrent) {
              widget.player.playIndex(widget.index);
              Navigator.pop(context);
            }
          },
        ),
      ),
    );
  }

  Widget _indexBadge(ColorScheme cs) {
    return Container(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: widget.isCurrent
            ? Icon(Icons.play_arrow_rounded, size: 18, color: cs.primary)
            : Text('${widget.index + 1}',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
//  Small action tile for the bottom bar
// ────────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = color ?? cs.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(fontSize: 10, color: fg),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
