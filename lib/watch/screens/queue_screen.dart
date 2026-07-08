// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// Wear OS 圆屏播放队列 — 查看和切换播放队列中的歌曲

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/player_provider.dart';
import '../widgets/watch_scroll_list.dart';
import '../widgets/watch_song_tile.dart';
import '../widgets/round_safe_area.dart';

/// 手表端播放队列页面。
///
/// 显示 PlayerProvider 的当前播放列表：
/// - 正在播放的歌曲高亮显示
/// - 点击可切换播放
/// - 使用 WatchScrollList（支持表冠滚动）
class WatchQueueScreen extends StatelessWidget {
  const WatchQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: RoundSafeArea(
        child: Consumer<PlayerProvider>(
        builder: (context, player, _) {
          final playlist = player.playlist;
          final currentIdx = player.currentIndex;

          if (playlist.isEmpty) {
            return Center(
              child: Text(
                '播放队列为空',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 标题栏 ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.queue_music_rounded,
                      size: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '播放队列',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${playlist.length}首',
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

              const Divider(height: 1),

              // ── 歌曲列表 ──
              Expanded(
                child: WatchScrollList(
                  itemCount: playlist.length,
                  bottomPadding: 16,
                  itemBuilder: (context, index) {
                    final song = playlist[index];
                    final isPlaying = index == currentIdx;
                    return WatchSongTile.fromSong(
                      song: song,
                      isPlaying: isPlaying,
                      onTap: () {
                        context.read<PlayerProvider>().playIndex(index);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }
}
