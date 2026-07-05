// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// Wear OS 圆屏 MiniPlayer — 显示当前播放曲目，点击跳转全屏播放器

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/player_provider.dart';

/// 手表 MiniPlayer：圆角卡片式，显示歌名和歌手
class WatchMiniPlayer extends StatelessWidget {
  const WatchMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;
        if (song == null) return const SizedBox.shrink();

        final isPlaying = player.isPlaying;
        final title = song.name;
        final artist = song.artistDisplay;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              // 封面缩略图
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 28,
                  height: 28,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.music_note,
                    size: 16,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 歌名 + 歌手
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      artist,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // 播放状态
              Icon(
                isPlaying ? Icons.play_arrow : Icons.pause,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        );
      },
    );
  }
}
