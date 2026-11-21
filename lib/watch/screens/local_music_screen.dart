// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/local_music_provider.dart';
import '../../providers/player_provider.dart';
import '../widgets/watch_scaffold.dart';
import '../widgets/watch_scroll_list.dart';
import '../widgets/watch_song_tile.dart';

class WatchLocalMusicScreen extends StatefulWidget {
  const WatchLocalMusicScreen({super.key});
  @override
  State<WatchLocalMusicScreen> createState() => _WatchLocalMusicScreenState();
}

class _WatchLocalMusicScreenState extends State<WatchLocalMusicScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final local = context.read<LocalMusicProvider>();
      if (!local.scanned) local.scanMusic();
    });
  }

  @override
  Widget build(BuildContext context) {
    final local = context.watch<LocalMusicProvider>();
    final currentPath = context.select(
      (PlayerProvider p) => p.currentSong?.filePath,
    );
    final songs = local.songs;
    final caption = local.isScanning
        ? '正在扫描'
        : local.error ?? '${songs.length} 首';
    final scan = FilledButton.tonalIcon(
      onPressed: local.scanMusic,
      icon: const Icon(Icons.refresh_rounded, size: 16),
      label: const Text('重新扫描'),
    );
    return WatchScaffold(
      body: Column(
        children: [
          WatchCatalogTitle('本地音乐', caption: songs.isEmpty ? null : caption),
          Expanded(
            child: RefreshIndicator(
              onRefresh: local.scanMusic,
              child: songs.isEmpty
                  ? WatchCatalogNotice(
                      local.isScanning ? '正在扫描手表' : local.error ?? '手表里还没有音乐',
                      busy: local.isScanning,
                      icon: Icons.music_note_outlined,
                      action: local.isScanning ? null : scan,
                    )
                  : WatchScrollList(
                      itemCount: songs.length + 1,
                      itemExtent: 52,
                      itemBuilder: (context, i) {
                        if (i == songs.length) {
                          return Center(
                            child: local.isScanning
                                ? const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : scan,
                          );
                        }
                        final localSong = songs[i];
                        final song = LocalMusicProvider.localSongToSong(
                          localSong,
                        );
                        return WatchSongTile(
                          title: localSong.displayName,
                          artist: localSong.artist,
                          subtitle: localSong.album,
                          art: localSong.albumCoverPath?.isNotEmpty == true
                              ? song.coverImageProvider
                              : null,
                          isPlaying: currentPath == localSong.filePath,
                          onTap: () => context.read<PlayerProvider>().playSong(
                            song,
                            playlist: local.toSongList(),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
