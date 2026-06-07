import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/liked_songs_provider.dart';

/// A table-style song list with column headers, hover effects,
/// double-click playback, and one-click like toggling.
class DesktopSongTable extends StatelessWidget {
  final List<Song> songs;
  final int? currentSongId;
  final bool isLoading;
  final String? emptyMessage;

  const DesktopSongTable({
    super.key,
    required this.songs,
    this.currentSongId,
    this.isLoading = false,
    this.emptyMessage,
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
            Icon(
              Icons.music_note_outlined,
              size: 48,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 8),
            Text(
              emptyMessage ?? '暂无歌曲',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // ── Table header ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            border: Border(
              bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '#',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Text(
                  '标题',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  '专辑',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 40),
              SizedBox(
                width: 48,
                child: Text(
                  '时长',
                  textAlign: TextAlign.right,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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

  const _SongTableRow({
    super.key,
    required this.song,
    required this.index,
    required this.isCurrent,
    required this.songs,
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
        onDoubleTap: () => _playSong(context),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: _isHovered
                ? cs.surfaceContainerHigh
                : (widget.isCurrent
                    ? cs.primaryContainer.withValues(alpha: 0.15)
                    : Colors.transparent),
            border: Border(
              bottom: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // ── Index or play icon ──
              SizedBox(
                width: 32,
                child: _isHovered
                    ? Icon(Icons.play_arrow_rounded, size: 18, color: cs.primary)
                    : Text(
                        '${widget.index + 1}',
                        style: tt.bodySmall?.copyWith(
                          color: widget.isCurrent ? cs.primary : cs.onSurfaceVariant,
                          fontWeight:
                              widget.isCurrent ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
              ),

              // ── Cover + title & artist ──
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: widget.song.albumCoverUrl != null &&
                                widget.song.albumCoverUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.song.albumCoverUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => _coverPlaceholder(cs),
                              )
                            : _coverPlaceholder(cs),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.song.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodyMedium?.copyWith(
                              fontWeight:
                                  widget.isCurrent ? FontWeight.w600 : FontWeight.normal,
                              color: widget.isCurrent ? cs.primary : cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.song.artistDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),

              // ── Like button ──
              SizedBox(
                width: 40,
                child: IconButton(
                  icon: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    size: 18,
                    color: liked ? Colors.redAccent : cs.onSurfaceVariant,
                  ),
                  onPressed: () => likedProvider.toggle(SongInfo(
                    id: widget.song.id,
                    name: widget.song.name,
                    hash: widget.song.hash ?? '',
                    albumId: widget.song.albumId,
                    audioId: widget.song.id,
                  )),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: liked ? '取消收藏' : '收藏',
                ),
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

  Widget _coverPlaceholder(ColorScheme cs) {
    return Container(
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.music_note, size: 18, color: cs.onSurfaceVariant),
    );
  }
}
