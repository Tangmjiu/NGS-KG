// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../../../models/album.dart';
import 'discover_media_rail.dart';

class DiscoverAlbumRow extends StatelessWidget {
  final List<Album> albums;

  const DiscoverAlbumRow({super.key, required this.albums});

  @override
  Widget build(BuildContext context) => DiscoverMediaRail(
        items: albums
            .map((album) => DiscoverMediaItem(
                  title: album.name,
                  subtitle: album.artistName,
                  imageUrl: album.coverUrl,
                  icon: Icons.album_rounded,
                  onTap: () => Navigator.pushNamed(context, '/album/detail',
                      arguments: {'id': album.id, 'name': album.name}),
                ))
            .toList(growable: false),
      );
}
