import 'package:flutter/material.dart';
import '../../../utils/theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../models/song.dart';
import '../../../providers/player_provider.dart';

/// 新歌速递 — 横向滚动歌曲卡片
class DiscoverSongRow extends StatelessWidget {
  final List<Song> songs;

  const DiscoverSongRow({super.key, required this.songs});

  void _playFrom(BuildContext context, int index) {
    final player = context.read<PlayerProvider>();
    player.playSong(songs[index], playlist: songs.sublist(index));
    player.setPlayerScreenVisible(true);
    Navigator.pushNamed(context, '/player').then((_) => player.setPlayerScreenVisible(false));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 170,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: songs.length,
        itemBuilder: (_, i) {
          final song = songs[i];
          return M3PressScale(
            child: GestureDetector(
            onTap: () => _playFrom(context, i),
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: AppShape.md,
                    child: song.thumbnailCoverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: song.thumbnailCoverUrl!,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            memCacheWidth: 240,
                            memCacheHeight: 240,
                            placeholder: (_, __) => Container(
                              width: 120,
                              height: 120,
                              color: cs.surfaceContainerHighest,
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 120,
                              height: 120,
                              color: cs.surfaceContainerHighest,
                              child: Icon(Icons.music_note,
                                  color: cs.onSurfaceVariant),
                            ),
                          )
                        : Container(
                            width: 120,
                            height: 120,
                            color: cs.surfaceContainerHighest,
                            child: Icon(Icons.music_note,
                                color: cs.onSurfaceVariant),
                          ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    song.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artistDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }
}
