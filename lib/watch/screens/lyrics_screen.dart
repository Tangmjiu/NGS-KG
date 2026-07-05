// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// Wear OS 圆屏歌词显示 — 随播放进度同步滚动

import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_model.dart' show LyricLine;
import 'package:provider/provider.dart';

import '../../../providers/player_provider.dart';
import '../widgets/watch_scroll_list.dart';
import '../widgets/round_safe_area.dart';

/// 手表端歌词屏幕。
///
/// 使用 PlayerProvider.lyricController 获取当前歌词行和进度，
/// 自动滚动到当前行，当前行高亮显示（带主题色强调）。
/// 无歌词时显示 "暂无歌词" 占位。
class WatchLyricsScreen extends StatefulWidget {
  const WatchLyricsScreen({super.key});

  @override
  State<WatchLyricsScreen> createState() => _WatchLyricsScreenState();
}

class _WatchLyricsScreenState extends State<WatchLyricsScreen> {
  @override
  Widget build(BuildContext context) {
    return RoundSafeArea(
      child: Consumer<PlayerProvider>(
        builder: (context, player, _) {
          final model = player.lyricController.lyricNotifier.value;
          final lines = model?.lines ?? <LyricLine>[];
          final activeIdx =
              player.lyricController.activeIndexNotifiter.value;

          if (lines.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lyrics_rounded,
                    size: 32,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '暂无歌词',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                  ),
                ],
              ),
            );
          }

          return _buildLyricList(context, lines, activeIdx);
        },
      ),
    );
  }

  Widget _buildLyricList(
      BuildContext context, List<LyricLine> lines, int activeIdx) {
    final theme = Theme.of(context);

    return WatchScrollList(
      itemCount: lines.length,
      bottomPadding: 24,
      autoScrollTo: activeIdx,
      autoScrollAlignment: 0.35,
      itemBuilder: (context, index) {
        final line = lines[index];
        final isActive = index == activeIdx;
        final text = line.text;
        final translation = line.translation;

        return AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.55),
            fontSize: isActive ? 15.0 : 13.0,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            height: 1.6,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (translation != null && translation.isNotEmpty && isActive)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      translation,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.45),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
