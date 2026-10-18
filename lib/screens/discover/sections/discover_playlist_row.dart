// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../../../models/playlist.dart';
import 'discover_media_rail.dart';

class DiscoverPlaylistRow extends StatelessWidget {
  final List<Playlist> playlists;

  const DiscoverPlaylistRow({super.key, required this.playlists});

  @override
  Widget build(BuildContext context) => DiscoverMediaRail(
        items: playlists
            .map((playlist) => DiscoverMediaItem(
                  title: playlist.name,
                  subtitle: playlist.trackCount > 0
                      ? '${playlist.trackCount} 首歌曲'
                      : '精选歌单',
                  imageUrl: playlist.coverUrl,
                  icon: Icons.queue_music_rounded,
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/playlist/detail',
                    arguments: {
                      'gcId': playlist.globalCollectionId ??
                          'collection_3_${playlist.createUserId}_${playlist.id}_0',
                      'name': playlist.name,
                    },
                  ),
                ))
            .toList(growable: false),
      );
}
