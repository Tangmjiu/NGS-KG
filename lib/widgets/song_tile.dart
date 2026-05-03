import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final void Function(Song song)? onTap;

  const SongTile({super.key, required this.song, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: song.albumCoverUrl != null
            ? CachedNetworkImage(
                imageUrl: song.albumCoverUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: Colors.grey[800], width: 48, height: 48),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.music_note, size: 32),
              )
            : Container(
                color: Colors.grey[800],
                width: 48,
                height: 48,
                child: const Icon(Icons.music_note, size: 32),
              ),
      ),
      title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(song.artistDisplay,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey[400], fontSize: 12)),
      trailing: IconButton(
        icon: const Icon(Icons.play_circle_outline, size: 20),
        onPressed: () => onTap?.call(song),
      ),
      onTap: () => onTap?.call(song),
    );
  }
}
