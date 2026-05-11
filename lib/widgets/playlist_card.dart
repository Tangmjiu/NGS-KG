import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/playlist.dart';
import '../services/music_service.dart';

class PlaylistCard extends StatelessWidget {
  final Playlist playlist;

  const PlaylistCard({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final args = playlist.globalCollectionId != null
              ? {'gcId': playlist.globalCollectionId, 'name': playlist.name}
              : {'id': playlist.id, 'name': playlist.name};
          Navigator.pushNamed(context, '/playlist/detail', arguments: args);
        },
        onLongPress: () {
          showModalBottomSheet(
            context: context,
            builder: (_) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.delete, color: cs.error),
                    title: Text('删除歌单', style: TextStyle(color: cs.error)),
                    onTap: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('确认删除'),
                          content: Text('确定要删除歌单"${playlist.name}"吗？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                MusicService().deletePlaylist(playlist.id);
                              },
                              child: Text('删除', style: TextStyle(color: cs.error)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: playlist.coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: playlist.coverUrl!,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                            color: cs.surfaceContainerHighest,
                            width: 64,
                            height: 64),
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.playlist_play, size: 40),
                      )
                    : Container(
                        color: cs.surfaceContainerHighest,
                        width: 64,
                        height: 64,
                        child: const Icon(Icons.playlist_play, size: 40),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('${playlist.trackCount} 首',
                        style: tt.bodySmall?.copyWith(color: cs.outline)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
