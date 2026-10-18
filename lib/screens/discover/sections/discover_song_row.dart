// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/song.dart';
import '../../../providers/player_provider.dart';
import '../../player_screen.dart';
import 'discover_media_rail.dart';

class DiscoverSongRow extends StatelessWidget {
  final List<Song> songs;

  const DiscoverSongRow({super.key, required this.songs});

  @override
  Widget build(BuildContext context) => DiscoverMediaRail(
        items: List.generate(songs.length, (index) {
          final song = songs[index];
          return DiscoverMediaItem(
            title: song.name,
            subtitle: song.artistDisplay,
            imageUrl: song.thumbnailCoverUrl,
            onTap: () {
              context
                  .read<PlayerProvider>()
                  .playSong(song, playlist: songs.sublist(index));
              PlayerScreen.open();
            },
          );
        }),
      );
}
