import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/liked_songs_provider.dart';
import '../services/music_service.dart';
import 'local_cover_art.dart';

/// A table-style song list with column headers, hover effects,
/// double-click playback, one-click like toggling, and multi-select.
class DesktopSongTable extends StatelessWidget {
  final List<Song> songs;
  final int? currentSongId;
  final bool isLoading;
  final String? emptyMessage;

  // ── Multi-select support ──
  final bool isSelecting;
  final Set<int> selectedIndices;
  final ValueChanged<int>? onToggleSelection;
  final VoidCallback? onSelectAll;
  final int totalCount;

  const DesktopSongTable({
    super.key,
    required this.songs,
    this.currentSongId,
    this.isLoading = false,
    this.emptyMessage,
    this.isSelecting = false,
    this.selectedIndices = const {},
    this.onToggleSelection,
    this.onSelectAll,
    this.totalCount = 0,
  });

  String _formatDuration(int ms) {
    if (ms <= 0) return '0:00';
    final totalSec = (ms / 1000).round().clamp(0, 359999);
    final m = totalSec ~/ 60;
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_note_outlined, size: 48,
                color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text(emptyMessage ?? '暂无歌曲',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // ── Table header ──
        Container(
          padding: EdgeInsets.only(
            left: isSelecting ? 8 : 20,
            right: 20,
            top: 8,
            bottom: 8,
          ),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            border: Border(
              bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              if (isSelecting)
                Checkbox(
                  value: selectedIndices.length == songs.length && songs.isNotEmpty,
                  tristate: selectedIndices.length > 0 && selectedIndices.length < songs.length,
                  onChanged: (_) => onSelectAll?.call(),
                ),
              if (!isSelecting)
                SizedBox(
                  width: 32,
                  child: Text('#', style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                ),
              Expanded(
                flex: 5,
                child: Text('标题', style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
              ),
              Expanded(
                flex: 3,
                child: Text('专辑', style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 40),
              SizedBox(
                width: 48,
                child: Text('时长', textAlign: TextAlign.right,
                    style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        // ── Song rows ──
        Expanded(
          child: ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              final isCurrent = song.id == currentSongId;
              return _SongTableRow(
                key: ValueKey('song_${song.id}_$index'),
                song: song,
                index: index,
                isCurrent: isCurrent,
                songs: songs,
                isSelecting: isSelecting,
                isSelected: selectedIndices.contains(index),
                onToggleSelection: onToggleSelection,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Individual song row with hover, selection, and action states.
class _SongTableRow extends StatefulWidget {
  final Song song;
  final int index;
  final bool isCurrent;
  final List<Song> songs;
  final bool isSelecting;
  final bool isSelected;
  final ValueChanged<int>? onToggleSelection;

  const _SongTableRow({
    super.key,
    required this.song,
    required this.index,
    required this.isCurrent,
    required this.songs,
    this.isSelecting = false,
    this.isSelected = false,
    this.onToggleSelection,
  });

  @override
  State<_SongTableRow> createState() => _SongTableRowState();
}

class _SongTableRowState extends State<_SongTableRow> {
  bool _isHovered = false;

  void _playSong(BuildContext context) {
    context.read<PlayerProvider>().playSong(
          widget.song,
          playlist: widget.songs,
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
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('添加到歌单',
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
                      Navigator.pop(ctx);
                      final song = widget.song;
                      final data = (song.hash?.isNotEmpty ?? false)
                          ? '${song.name}|${song.hash}|${song.albumId}|${song.mixSongId ?? song.id}'
                          : song.name;
                      try {
                        await MusicService().addTracksToPlaylist(pl.id, data);
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int ms) {
    if (ms <= 0) return '0:00';
    final totalSec = (ms / 1000).round().clamp(0, 359999);
    final m = totalSec ~/ 60;
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final player = context.watch<PlayerProvider>();
    final likedProvider = context.watch<LikedSongsProvider>();
    final liked = likedProvider.likedIds.contains(widget.song.id);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onDoubleTap: widget.isSelecting ? null : () => _playSong(context),
        child: Container(
          height: 56,
          padding: EdgeInsets.only(
            left: widget.isSelecting ? 8 : 20,
            right: 20,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? cs.primaryContainer.withValues(alpha: 0.2)
                : (_isHovered
                    ? cs.surfaceContainerHigh
                    : (widget.isCurrent
                        ? cs.primaryContainer.withValues(alpha: 0.15)
                        : Colors.transparent)),
            border: Border(
              bottom: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // ── Checkbox (selecting) or Index (normal) ──
              if (widget.isSelecting)
                Checkbox(
                  value: widget.isSelected,
                  onChanged: (_) => widget.onToggleSelection?.call(widget.index),
                ),
              if (!widget.isSelecting)
                SizedBox(
                  width: 32,
                  child: _isHovered
                      ? Icon(Icons.play_arrow_rounded, size: 18, color: cs.primary)
                      : Text(
                          '${widget.index + 1}',
                          style: tt.bodySmall?.copyWith(
                            color: widget.isCurrent ? cs.primary : cs.onSurfaceVariant,
                            fontWeight: widget.isCurrent ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                ),

              // ── Cover + title & artist ──
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    LocalCoverArt(
                      url: widget.song.albumCoverUrl,
                      size: 40,
                      coverData: widget.song.coverData,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.song.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: tt.bodyMedium?.copyWith(
                                fontWeight: widget.isCurrent ? FontWeight.w600 : FontWeight.normal,
                                color: widget.isCurrent ? cs.primary : cs.onSurface,
                              )),
                          const SizedBox(height: 2),
                          Text(widget.song.artistDisplay,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Album name ──
              Expanded(
                flex: 3,
                child: Text(
                  widget.song.albumName ?? '-',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),

              // ── Like button & more ──
              if (!widget.isSelecting)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 36,
                      child: IconButton(
                        icon: Icon(liked ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: liked ? Colors.redAccent : cs.onSurfaceVariant),
                        onPressed: () => likedProvider.toggle(SongInfo(
                          id: widget.song.id, name: widget.song.name,
                          hash: widget.song.hash ?? '', albumId: widget.song.albumId,
                          audioId: widget.song.id,
                        )),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        tooltip: liked ? '取消收藏' : '收藏',
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz, size: 18, color: cs.onSurfaceVariant),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onSelected: (value) {
                        if (value == 'queue') {
                          context.read<PlayerProvider>().addToQueue(widget.song);
                        } else if (value == 'next') {
                          context.read<PlayerProvider>().playNextSong(widget.song);
                        } else if (value == 'playlist') {
                          _addToPlaylist(context);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'next',
                          child: Text('下一首播放', style: TextStyle(fontSize: 13)),
                        ),
                        const PopupMenuItem(
                          value: 'queue',
                          child: Text('添加到队列', style: TextStyle(fontSize: 13)),
                        ),
                        const PopupMenuItem(
                          value: 'playlist',
                          child: Text('添加到歌单', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),

              // ── Duration ──
              SizedBox(
                width: 48,
                child: Text(
                  _formatDuration(widget.song.duration),
                  textAlign: TextAlign.right,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
