import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/album.dart';

/// 新碟上架 — 横向滚动专辑卡片
class DiscoverAlbumRow extends StatelessWidget {
  final List<Album> albums;

  const DiscoverAlbumRow({super.key, required this.albums});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: albums.length,
        itemBuilder: (_, i) {
          final album = albums[i];
          return GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/album/detail',
                arguments: {'id': album.id, 'name': album.name}),
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: album.coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: album.coverUrl!,
                            width: 140,
                            height: 140,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 140,
                              height: 140,
                              color: cs.surfaceContainerHighest,
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 140,
                              height: 140,
                              color: cs.surfaceContainerHighest,
                              child: Icon(Icons.album,
                                  color: cs.onSurfaceVariant),
                            ),
                          )
                        : Container(
                            width: 140,
                            height: 140,
                            color: cs.surfaceContainerHighest,
                            child: Icon(Icons.album, color: cs.onSurfaceVariant),
                          ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    album.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  if (album.artistName != null)
                    Text(
                      album.artistName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
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
