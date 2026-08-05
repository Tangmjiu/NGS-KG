import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../providers/liked_songs_provider.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/download_provider.dart';
import '../services/music_service.dart';
import '../theme/theme_assets.dart';
import '../utils/theme.dart';
import '../utils/responsive.dart';
import '../routes/app_routes.dart';
import 'playing_indicator.dart';

class SongTile extends StatefulWidget {
  final Song song;
  final void Function(Song song)? onTap;
  final bool showIndex;
  final int? index;
  final VoidCallback? onDelete;
  final String? deleteLabel;

  const SongTile(
      {super.key,
      required this.song,
      this.onTap,
      this.showIndex = false,
      this.index,
      this.onDelete,
      this.deleteLabel});

  @override
  State<SongTile> createState() => _SongTileState();
}

class _SongTileState extends State<SongTile> {
  bool _isHovered = false;

  /// 封面组件：本地文件（file:// 或裸路径）用 Image.file，其余走网络缓存。
  Widget _buildCover(Song song, ColorScheme cs) {
    final url = song.thumbnailCoverUrl!;
    final isLocal = url.startsWith('file:') ||
        url.startsWith('/') ||
        RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(url);
    if (isLocal) {
      final path =
          url.startsWith('file:') ? Uri.parse(url).toFilePath() : url;
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(file,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(cs));
      }
      return _placeholder(cs);
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: 48,
      height: 48,
      fit: BoxFit.cover,
      memCacheWidth: 112,
      memCacheHeight: 112,
      placeholder: (_, __) => _placeholder(cs),
      errorWidget: (_, __, ___) => _placeholder(cs),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '--:--';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDesktop = Responsive.isDesktopLayout(context);
    // 精确选择：只订阅当前歌曲 ID 和播放状态，避免进度变化导致整行 rebuild
    final playbackState =
        context.select<PlayerProvider, ({bool isCurrent, bool isPlaying})>(
      (p) => (
        isCurrent: p.currentSong?.id == widget.song.id,
        isPlaying: p.currentSong?.id == widget.song.id && p.isPlaying,
      ),
    );
    final isCurrent = playbackState.isCurrent;
    final isPlaying = playbackState.isPlaying;

    Color bgColor = Colors.transparent;
    if (isCurrent) {
      bgColor = cs.primaryContainer;
    } else if (_isHovered) {
      bgColor = cs.surfaceContainerHighest.withValues(alpha: 0.5);
    }

    return Semantics(
      button: true,
      child: M3PressScale(
        scaleDown: 0.96,
        child: AnimatedContainer(
          duration: AppMotion.dShort4,
          curve: AppMotion.emphasized,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: AppShape.md,
          ),
          child: InkWell(
            borderRadius: AppShape.md,
            onTap: () => widget.onTap?.call(widget.song),
            onLongPress: () => _showContextMenu(context),
            onSecondaryTap: () => _showContextMenu(context),
            onHover: (val) {
              if (_isHovered != val) {
                setState(() => _isHovered = val);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                height: 64,
                child: Row(
                  children: [
                    if (widget.showIndex && widget.index != null)
                      SizedBox(
                        width: 32,
                        child: Center(
                          child: Text(
                            '${widget.index}',
                            style: tt.bodyMedium?.copyWith(
                              color:
                                  isCurrent ? cs.primary : cs.onSurfaceVariant,
                              fontWeight: isCurrent
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    // Album Art
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: AppShape.sm,
                          child: widget.song.thumbnailCoverUrl != null
                              ? _buildCover(widget.song, cs)
                              : _placeholder(cs),
                        ),
                        // Playing Indicator Overlay
                        if (isCurrent)
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: AppShape.sm,
                            ),
                            child: Center(
                              child: isPlaying
                                  ? const PlayingIndicator(
                                      size: 24, color: Colors.white)
                                  : const Icon(Icons.pause_rounded,
                                      color: Colors.white, size: 24),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Texts
                    if (isDesktop) ...[
                      Expanded(
                        flex: 3,
                        child: Text(
                          widget.song.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyLarge?.copyWith(
                            fontWeight:
                                isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isCurrent
                                ? cs.onPrimaryContainer
                                : cs.onSurface,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          widget.song.artistDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium?.copyWith(
                            color: isCurrent
                                ? cs.onPrimaryContainer.withValues(alpha: 0.8)
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          widget.song.albumName ?? '未知专辑',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium?.copyWith(
                            color: isCurrent
                                ? cs.onPrimaryContainer.withValues(alpha: 0.8)
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: Text(
                          _formatDuration(widget.song.duration),
                          textAlign: TextAlign.right,
                          style: tt.bodyMedium?.copyWith(
                            color: isCurrent
                                ? cs.onPrimaryContainer.withValues(alpha: 0.8)
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      // hover 时浮现的操作按钮
                      SizedBox(
                        width: 96,
                        child: AnimatedSlide(
                          offset:
                              Offset(0, (_isHovered || isCurrent) ? 0 : 0.5),
                          duration: AppMotion.dShort4,
                          curve: AppMotion.emphasized,
                          child: AnimatedOpacity(
                            opacity: (_isHovered || isCurrent) ? 1 : 0,
                            duration: AppMotion.dShort4,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _DownloadButton(song: widget.song),
                                Consumer<LikedSongsProvider>(
                                  builder: (_, lp, __) {
                                    final liked =
                                        lp.likedIds.contains(widget.song.id);
                                    return M3BounceFeedback(
                                      trigger: liked,
                                      child: IconButton(
                                        icon: Icon(
                                          liked
                                              ? Icons.favorite_rounded
                                              : Icons.favorite_border_rounded,
                                          size: 20,
                                        ),
                                        color: liked
                                            ? cs.error
                                            : (isCurrent
                                                ? cs.onPrimaryContainer
                                                : cs.onSurfaceVariant),
                                        tooltip: liked ? '取消喜欢' : '喜欢',
                                        onPressed: () async {
                                          final info = SongInfo(
                                            id: widget.song.id,
                                            name: widget.song.name,
                                            hash: widget.song.hash ?? '',
                                            albumId: widget.song.albumId,
                                            audioId: widget.song.id,
                                          );
                                          await lp.toggle(info);
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ] else
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.song.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodyLarge?.copyWith(
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isCurrent
                                    ? cs.onPrimaryContainer
                                    : cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.song.artistDisplay,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodyMedium?.copyWith(
                                color: isCurrent
                                    ? cs.onPrimaryContainer
                                        .withValues(alpha: 0.8)
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Mobile trailing actions
                    if (!isDesktop)
                      if (_isHovered || isCurrent)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _DownloadButton(song: widget.song),
                            Consumer<LikedSongsProvider>(
                              builder: (_, lp, __) {
                                final liked =
                                    lp.likedIds.contains(widget.song.id);
                                return M3BounceFeedback(
                                  trigger: liked,
                                  child: IconButton(
                                    icon: Icon(
                                      liked
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      size: 24,
                                    ),
                                    color: liked
                                        ? cs.error
                                        : (isCurrent
                                            ? cs.onPrimaryContainer
                                            : cs.onSurfaceVariant),
                                    tooltip: liked ? '取消喜欢' : '喜欢',
                                    onPressed: () async {
                                      final info = SongInfo(
                                        id: widget.song.id,
                                        name: widget.song.name,
                                        hash: widget.song.hash ?? '',
                                        albumId: widget.song.albumId,
                                        audioId: widget.song.id,
                                      );
                                      await lp.toggle(info);
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) {
    return Container(
      color: cs.surfaceContainerHighest,
      width: 48,
      height: 48,
      child: albumPlaceholderWidget(size: 32),
    );
  }

  void _showContextMenu(BuildContext context) {
    final isDesktop = Responsive.isDesktopLayout(context);
    final dlProvider = context.read<DownloadProvider>();
    final downloaded = dlProvider.isDownloaded(widget.song);
    final items = [
      _menuItem(
        context,
        icon: downloaded ? Icons.delete_outline : Icons.download,
        label: downloaded ? '删除下载' : '下载',
        onTap: () {
          Navigator.pop(context);
          if (downloaded) {
            dlProvider.removeDownload(widget.song);
          } else {
            dlProvider.download(widget.song);
          }
        },
      ),
      _menuItem(
        context,
        icon: Icons.skip_next,
        label: '下一首播放',
        onTap: () {
          Navigator.pop(context);
          context.read<PlayerProvider>().playNextSong(widget.song);
        },
      ),
      _menuItem(
        context,
        icon: Icons.playlist_add,
        label: '添加到歌单',
        onTap: () {
          Navigator.pop(context);
          _addToPlaylist(context);
        },
      ),
      _menuItem(
        context,
        icon: Icons.queue_music,
        label: '加入队列',
        onTap: () {
          Navigator.pop(context);
          context.read<PlayerProvider>().addToQueue(widget.song);
        },
      ),
      if (widget.song.albumId > 0)
        _menuItem(
          context,
          icon: Icons.album,
          label: '查看专辑',
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, AppRoutes.albumDetail, arguments: {
              'id': widget.song.albumId,
              'name': widget.song.albumName,
            });
          },
        ),
      if (widget.song.artistId != null && widget.song.artistId! > 0)
        _menuItem(
          context,
          icon: Icons.person,
          label: '查看歌手',
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, AppRoutes.artistDetail, arguments: {
              'id': widget.song.artistId,
              'name': widget.song.artists.isNotEmpty
                  ? widget.song.artists.first
                  : '',
            });
          },
        ),
      if (widget.onDelete != null)
        _menuItem(
          context,
          icon: Icons.delete_outline,
          label: widget.deleteLabel ?? '删除',
          onTap: () {
            Navigator.pop(context);
            widget.onDelete!();
          },
        ),
    ];

    if (isDesktop) {
      showM3Dialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(widget.song.name),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: items),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } else {
      showM3ModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: items),
        ),
      );
    }
  }

  Widget _menuItem(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return M3PressScale(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        onTap: onTap,
      ),
    );
  }

  void _addToPlaylist(BuildContext context) {
    final playlists = context.read<PlaylistProvider>().userPlaylists;
    if (playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无歌单，请先创建')),
      );
      return;
    }
    showM3ModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child:
                  Text('添加到歌单', style: Theme.of(context).textTheme.titleSmall),
            ),
            Divider(
                height: 1, color: Theme.of(context).colorScheme.outlineVariant),
            SizedBox(
              height: (playlists.length * 56.0).clamp(80.0, 320.0),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: playlists.length,
                itemBuilder: (_, i) {
                  final pl = playlists[i];
                  return M3StaggeredFadeIn(
                    index: i,
                    child: M3PressScale(
                      child: ListTile(
                        leading: const Icon(Icons.playlist_play),
                        title: Text(pl.name),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final data = (widget.song.hash?.isNotEmpty ?? false)
                              ? '${widget.song.name}|${widget.song.hash}|${widget.song.albumId}|${widget.song.id}'
                              : widget.song.name;
                          try {
                            await MusicService()
                                .addTracksToPlaylist(pl.id, data);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('已添加到歌单')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('添加失败: $e')),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 歌曲下载按钮：未下载 → 加入队列；已下载 → 显示完成状态
class _DownloadButton extends StatelessWidget {
  final Song song;
  const _DownloadButton({required this.song});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Consumer<DownloadProvider>(
      builder: (_, dp, __) {
        final downloaded = dp.isDownloaded(song);
        if (downloaded) {
          return IconButton(
            icon: const Icon(Icons.check_circle_outline, size: 20),
            color: cs.primary,
            tooltip: '已下载',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('这首歌已下载')),
            ),
          );
        }
        return IconButton(
          icon: const Icon(Icons.download_outlined, size: 20),
          color: cs.onSurfaceVariant,
          tooltip: '下载',
          onPressed: song.isLocal || song.hash == null
              ? null
              : () => dp.download(song),
        );
      },
    );
  }
}
