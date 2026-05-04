import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/playlist.dart';
import '../services/music_service.dart';

class PlaylistCard extends StatelessWidget {
  final Playlist playlist;

  const PlaylistCard({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
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
                    leading: Icon(Icons.delete, color: Colors.red[400]),
                    title: Text('删除歌单', style: TextStyle(color: Colors.red[400])),
                    onTap: () {
                      Navigator.pop(context);
                      MusicService().deletePlaylist(playlist.id);
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
                            color: Colors.grey[800],
                            width: 64,
                            height: 64),
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.playlist_play, size: 40),
                      )
                    : Container(
                        color: Colors.grey[800],
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
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('${playlist.trackCount} 首',
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
