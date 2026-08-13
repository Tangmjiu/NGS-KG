// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 手表播放队列 — 当前播放高亮，打开时自动定位到当前曲目

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/player_provider.dart';
import '../widgets/watch_scroll_list.dart';
import '../widgets/watch_song_tile.dart';
import '../widgets/watch_scaffold.dart';

/// 播放队列页面：正在播放的歌曲高亮，点击切换播放，支持表冠滚动。
class WatchQueueScreen extends StatelessWidget {
  const WatchQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final playlist = player.playlist;
        final currentIdx = player.currentIndex;

        if (playlist.isEmpty) {
          return WatchScaffold(
            body: Center(
              child: Text(
                '播放队列为空',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
              ),
            ),
          );
        }

        return WatchScaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: Row(
                  children: [
                    Text(
                      '播放队列',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      '${playlist.length} 首',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: WatchScrollList(
                  itemCount: playlist.length,
                  itemExtent: 52,
                  autoScrollTo: currentIdx >= 0 ? currentIdx : null,
                  autoScrollAlignment: 0.3,
                  bottomPadding: 24,
                  itemBuilder: (context, index) {
                    final song = playlist[index];
                    return WatchSongTile.fromSong(
                      song: song,
                      isPlaying: index == currentIdx,
                      onTap: () =>
                          context.read<PlayerProvider>().playIndex(index),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
