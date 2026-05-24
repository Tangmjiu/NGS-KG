import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/playlist.dart';

/// 推荐歌单 — 横向滚动卡片列表
class DiscoverPlaylistRow extends StatelessWidget {
  final List<Playlist> playlists;

  const DiscoverPlaylistRow({super.key, required this.playlists});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: playlists.length,
        itemBuilder: (_, i) {
          final pl = playlists[i];
          return GestureDetector(
            onTap: () {
              if (pl.globalCollectionId != null) {
                Navigator.pushNamed(context, '/playlist/detail', arguments: {
                  'gcId': pl.globalCollectionId,
                  'name': pl.name,
                });
              } else {
                Navigator.pushNamed(context, '/playlist/detail', arguments: {
                  'gcId': pl.id.toString(),
                  'name': pl.name,
                });
              }
            },
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: pl.coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: pl.coverUrl!,
                            width: 140,
                            height: 140,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 140,
                            height: 140,
                            color: cs.surfaceContainerHighest,
                            child: Icon(Icons.playlist_play,
                                color: cs.onSurfaceVariant),
                          ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pl.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
